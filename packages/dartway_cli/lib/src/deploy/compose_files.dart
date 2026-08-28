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
/// built here. What nobody controls is the command a person types by hand, and
/// that command is the reason [bridgeIn] exists.
class DwComposeFiles {
  const DwComposeFiles._();

  /// Rendered by `dartway deploy setup` into the checkout root.
  static const String rendered = 'docker-compose.yml';

  /// The project's own override, as committed. Relative to the checkout root,
  /// which is where Compose runs.
  static const String projectOverride = 'deploy/compose.override.yml';

  /// The name Compose loads on its own, with no `-f` at all.
  ///
  /// An older CLI wrote a full copy of the project override here, and nothing
  /// refreshed it. Today [bridgeIn] writes a two-line bridge instead: it names
  /// [projectOverride] rather than duplicating it, so it cannot go stale.
  static const String autoLoaded = 'docker-compose.override.yml';

  /// Where a file found under [autoLoaded] that is not ours is moved to. Any
  /// name Compose does not load on its own would do; this one says what
  /// happened.
  static const String retiredCopy = 'docker-compose.override.yml.retired';

  /// Marks [autoLoaded] as written by us, so a rerun can tell its own file
  /// from a stale copy or a hand edit and leave the latter alone.
  static const String bridgeMarker = 'dartway-bridge';

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

  /// Makes a bare `docker compose` in [appDir] mean the same stack the deploy
  /// applies, by writing [autoLoaded] as an `include` of [projectOverride].
  ///
  /// **Why a file has to be there at all.** Naming the override on every call
  /// is airtight inside the CLI and nowhere else. Every runbook, every habit
  /// and every agent that has ever opened a shell on the box types
  /// `docker compose up -d`, and in a directory holding only [rendered] that
  /// command applies a strictly smaller stack — Compose exits 0, because from
  /// its point of view nothing is missing. A staging stand lost its `minio`
  /// that way and stayed down for eleven hours.
  ///
  /// **Why a bridge and not a copy.** The copy an older CLI wrote was the
  /// original bug: it froze the override as it stood the day `setup` last ran.
  /// A file that only names the committed one holds no content to go stale,
  /// and `git reset --hard` refreshes what it points at.
  ///
  /// The CLI's own calls are unaffected: explicit `-f` flags replace the
  /// default file selection outright, so Compose never auto-loads this file
  /// while the deploy is running, and the two routes cannot merge twice.
  ///
  /// **Without [projectOverride] there is nothing to bridge to,** and this
  /// refuses rather than tidies: a file under [autoLoaded] that is not ours may
  /// be the only place those services are declared, and removing it would be
  /// pure subtraction. Our own bridge, left pointing at an override the project
  /// has since deleted, is removed — it holds nothing.
  ///
  /// Idempotent, and silent on a rerun that finds its own file already in place.
  static String bridgeIn(String appDir) =>
      "cd '$appDir' && "
      "if [ -f '$projectOverride' ]; then "
      "if [ ! -f '$autoLoaded' ] || ! grep -q '$bridgeMarker' '$autoLoaded'; then "
      "if [ -f '$autoLoaded' ]; then "
      "mv -f '$autoLoaded' '$retiredCopy' && "
      "echo 'Kept the previous $autoLoaded as $retiredCopy.'; "
      'fi && '
      "printf '%s\n' "
      "'# $bridgeMarker: written by dartway deploy. Do not edit.' "
      "'# Keeps a bare docker compose in this directory equal to the deploy.' "
      "'include:' '  - $projectOverride' > '$autoLoaded' && "
      "echo 'Bridged $autoLoaded to $projectOverride.'; "
      'fi; '
      "elif [ -f '$autoLoaded' ]; then "
      "if grep -q '$bridgeMarker' '$autoLoaded'; then "
      "rm -f '$autoLoaded' && "
      "echo 'Removed $autoLoaded: $projectOverride is no longer in the checkout.'; "
      'else '
      "echo 'ERROR: $autoLoaded is here and $projectOverride is not. That file "
      "may be the only place its services are declared, so this deploy will not "
      "touch it. Commit $projectOverride, or remove $autoLoaded deliberately.' >&2 && "
      'exit 1; '
      'fi; '
      'fi';
}
