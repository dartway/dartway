# Prints what Kamal itself derives from one service configuration: the names
# a deployment lives under on the server, its hosts and its environment.
# Usage: ruby inspect_config.rb <config.yml> <destination> <version>
require "kamal"
require "json"

config_file, destination, version = ARGV
config = Kamal::Configuration.create_from(
  config_file: Pathname.new(File.expand_path(config_file)),
  destination: destination,
  version: version
)
role = config.roles.first
host = role.hosts.first
env = role.env(host)
puts JSON.generate(
  service: config.service,
  image: config.absolute_image,
  app_directory: config.app_directory,
  container_prefix: role.container_prefix,
  labels: role.labels,
  hosts: role.hosts,
  ssh_user: config.ssh.user,
  proxy_hosts: role.proxy&.hosts,
  volumes: config.volume_args.each_slice(2).map(&:last),
  secrets_path: role.secrets_path,
  env_clear: env.clear,
  # Resolving the values proves every named secret exists for this
  # destination; only the names are printed.
  env_secrets: env.secret_keys.tap { env.secrets_io },
  accessories: config.accessories.to_h do |accessory|
    [accessory.name, {
      service: accessory.service_name,
      hosts: accessory.hosts,
      directories: accessory.directories,
      secrets_path: accessory.secrets_path,
      env_clear: accessory.env.clear,
      env_secrets: accessory.env.secret_keys.tap { accessory.env.secrets_io }
    }]
  end
)
