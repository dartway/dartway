/// The Compose files a deployment merges, and the one way of invoking Compose
/// with them.
///
/// The project's override is named explicitly on every call rather than copied
/// next to the rendered file under the name Compose loads on its own. The copy
/// was made once, by `setup`, and nothing refreshed it — so a committed change
/// to `deploy/compose.override.yml` had no effect on a deploy, while the run
/// printed the very commit that made it. Naming the file from the checkout
/// makes `git reset --hard` refresh it, which is what a reader already expects
/// the checkout to do.
///
/// Nobody has to remember the flag: every `docker compose` the CLI issues is
/// built here.
class DwComposeFiles {
  const DwComposeFiles._();

  /// Rendered by `dartway deploy setup` into the checkout root.
  static const String rendered = 'docker-compose.yml';

  /// The project's own override, as committed. Relative to the checkout root,
  /// which is where Compose runs.
  static const String projectOverride = 'deploy/compose.override.yml';

  /// The copy `setup` used to write next to [rendered]. Compose loads a file
  /// under this name automatically, so a leftover from an older CLI keeps
  /// being merged into every deploy — see [retireLegacyCopyIn].
  static const String legacyCopy = 'docker-compose.override.yml';

  /// Where [legacyCopy] is moved to. Any name Compose does not load on its own
  /// would do; this one says what happened.
  static const String retiredCopy = 'docker-compose.override.yml.retired';

  /// Shell variable holding the `-f` flags.
  static const String _variable = 'dw_compose_files';

  /// Sets [_variable]. Assumes the working directory is the checkout root.
  ///
  /// `if`/`fi` rather than `[ -f x ] && …`: the latter exits non-zero when the
  /// override is absent, which aborts any caller running under `set -e`.
  static const String selectFiles =
      "$_variable='-f $rendered'; "
      "if [ -f '$projectOverride' ]; then "
      '$_variable="\$$_variable -f $projectOverride"; '
      'fi';

  /// The invocation itself, once [selectFiles] has run. Unquoted on purpose:
  /// the variable holds several arguments and has to split into them.
  static const String invoke = 'docker compose \$$_variable';

  /// A complete command: enter [appDir], pick the files, run Compose.
  static String commandIn(String appDir, String arguments) =>
      "cd '$appDir' && $selectFiles && $invoke $arguments";

  /// Removes the automatically loaded copy an older CLI left in [appDir].
  ///
  /// Renamed rather than deleted: the file is normally a stale copy of a
  /// committed one and worth nothing, but a server may carry a hand edit made
  /// while debugging, and losing that silently would be its own bug. Idempotent
  /// — a server that never had the copy, or that has already been through this,
  /// finds nothing to move and says nothing.
  static String retireLegacyCopyIn(String appDir) =>
      "cd '$appDir' && "
      "if [ -f '$legacyCopy' ]; then "
      "mv -f '$legacyCopy' '$retiredCopy' && "
      "echo 'Retired $legacyCopy (now $retiredCopy): the deploy reads "
      "$projectOverride from the checkout instead.'; "
      'fi';
}
