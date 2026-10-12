import 'stack.dart';

const kamalApiHooksDirectory = 'deploy/kamal/hooks/api';

/// The API hook is run by Kamal before each boot group, including rollback.
const kamalSecretFilesHookPath = '$kamalApiHooksDirectory/pre-app-boot';

/// Uses Kamal's resolved SSH configuration, including keys, agent and proxy,
/// rather than reconstructing an `ssh` command with different credentials.
/// Only names and metadata cross SSH; secret contents are never read.
String kamalSecretFilesHook(String generatedHeader) =>
    '#!/usr/bin/env ruby\n$generatedHeader${_hookBody.replaceAll('__SECRET_FILES_DIR__', DwStack.secretFilesDir)}';

const _hookBody = r'''
require "kamal"
require "shellwords"

begin
  destination = ENV.fetch("KAMAL_DESTINATION")
  unless %w[stage prod].include?(destination)
    abort "Secret file check requires a stage or prod destination."
  end
  config = Kamal::Configuration.create_from(
    config_file: Pathname.new(File.expand_path("../../api.yml", __dir__)),
    destination: destination
  )
  unless ENV.fetch("KAMAL_SERVICE") == config.service
    abort "Secret file check must run for the configured API service."
  end
  hosts = ENV.fetch("KAMAL_HOSTS").split(",")
  if hosts.empty? || (hosts - config.app_hosts).any?
    abort "Secret file check received hosts outside the API configuration."
  end

  mounts = Array(config.raw_config.volumes).filter_map do |volume|
    source, target, mode = volume.split(":", 3)
    next unless target&.start_with?("__SECRET_FILES_DIR__/")
    name = File.basename(target)
    unless mode == "ro" && source.start_with?("/") &&
        target == "__SECRET_FILES_DIR__/#{name}" &&
        name.match?(/\A[A-Za-z0-9._-]+\z/) &&
        !%w[. .. secrets.env].include?(name) && File.basename(source) == name
      abort "Invalid secret file mount: #{target}. Regenerate with dartway deploy kamal."
    end
    source
  end
  exit 0 if mounts.empty?

  # Ubuntu's stat is used on the target, never the deploy runner's platform.
  script = "set -eu\n"
  mounts.map { |source| File.dirname(source) }.uniq.each do |directory|
    quoted = Shellwords.escape(directory)
    script += <<~SH
      if [ -L #{quoted} ] || [ ! -d #{quoted} ] || [ "$((0$(stat -c %a #{quoted}) & 0777))" != 448 ]; then
        echo #{Shellwords.escape("Secret file directory #{directory} must be a real directory with mode 700.")} >&2
        exit 1
      fi
    SH
  end
  mounts.each do |source|
    quoted = Shellwords.escape(source)
    directory = Shellwords.escape(File.dirname(source))
    script += <<~SH
      if [ -L #{quoted} ] || [ ! -f #{quoted} ] || [ ! -s #{quoted} ]; then
        echo #{Shellwords.escape("Missing, empty or invalid secret file #{File.basename(source)}. Deliver it with dartway secret put-file --env #{destination == 'stage' ? 'staging' : 'production'}.")} >&2
        exit 1
      fi
      case "$(stat -c %a #{quoted})" in
        400|600) ;;
        *) echo 'Secret files must have mode 400 or 600.' >&2; exit 1 ;;
      esac
      if [ "$(stat -c %u #{quoted})" != "$(stat -c %u #{directory})" ]; then
        echo 'Secret file and directory must have the same owner.' >&2
        exit 1
      fi
    SH
  end
  command = "if [ \"$(id -u)\" = 0 ]; then sh -c #{Shellwords.escape(script)}; " \
    "else sudo -n sh -c #{Shellwords.escape(script)}; fi"
  hosts.each do |host|
    Net::SSH.start(host, config.ssh.user, **config.ssh.options.except(:user)) do |ssh|
      status = nil
      channel = ssh.open_channel do |remote|
        remote.exec(command) do |running, accepted|
          abort "Cannot run secret file check on #{host}." unless accepted
          running.on_data { |_channel, output| $stdout.write(output) }
          running.on_extended_data { |_channel, _type, output| $stderr.write(output) }
          running.on_request("exit-status") { |_channel, value| status = value.read_long }
        end
      end
      channel.wait
      abort "Secret file check failed on #{host}; API was not booted." unless status == 0
    end
  end
rescue StandardError => error
  warn "Secret file check could not complete (#{error.class}). Check API configuration and SSH access."
  exit 1
end
''';
