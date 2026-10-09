import 'ssh_runner.dart';

String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

/// A target-side stdin filter. Values are read only by awk on the target,
/// never interpolated into commands or returned to the deploying machine.
String dwSecretMaskFunction(String storeFile) =>
    '''
dw_mask_output() {
  dw_mask_store=${_quote(storeFile)}
  if [ ! -e "\$dw_mask_store" ]; then
    dw_mask_store=/dev/null
  elif [ ! -f "\$dw_mask_store" ] || [ ! -r "\$dw_mask_store" ]; then
    echo 'Cannot read the secret store to mask deploy output.' >&2
    return 1
  fi
  LC_ALL=C awk -v store="\$dw_mask_store" '
${_maskAwk}
  '
}
''';

// A one-record lookahead plus the sentinel supplied by the caller preserves
// the last newline (or its absence). LC_ALL=C makes encoding operate on bytes.
const _maskAwk = r'''
function add(value) {
  if (!(value in seen)) { seen[value] = 1; secrets[++count] = value }
}
function characters(value,    i,n,b) {
  n = 0
  for (i = 1; i <= length(value); i++) {
    b = bytes[substr(value, i, 1)]
    if (b < 128 || b >= 192) n++
  }
  return n
}
# Mode 0 is strict, 1 keeps the URI component set, 2 the RFC 3986 userinfo
# set (sub-delims and ":"), as Uri(userInfo:) in Dart leaves them literal.
function literal(c, mode) {
  if (c ~ /^[A-Za-z0-9_.~-]$/) return 1
  if (mode == 1) return c ~ /^[!*()]$/
  if (mode == 2) return c ~ /^[!$&\047()*+,;=:]$/
  return 0
}
function encoded(value, mode,    out,i,c) {
  out = ""
  for (i = 1; i <= length(value); i++) {
    c = substr(value, i, 1)
    if (literal(c, mode)) out = out c
    else out = out sprintf("%%%02X", bytes[c])
  }
  return out
}
function lowerHex(value,    out,i,c) {
  out = ""
  for (i = 1; i <= length(value); i++) {
    c = substr(value, i, 1)
    if (c == "%") { out = out tolower(substr(value, i, 3)); i += 2 }
    else out = out c
  }
  return out
}
function masked(line,    out,i,at,best,size,value) {
  out = ""
  while (length(line)) {
    best = 0; size = 0
    for (i = 1; i <= count; i++) {
      value = secrets[i]; at = index(line, value)
      if (at && (!best || at < best || (at == best && length(value) > size))) {
        best = at; size = length(value)
      }
    }
    if (!best) return out line
    out = out substr(line, 1, best - 1) "***"
    line = substr(line, best + size)
  }
  return out
}
BEGIN {
  for (i = 1; i < 256; i++) bytes[sprintf("%c", i)] = i
  while ((status = (getline entry < store)) > 0) {
    if (entry !~ /^[A-Z_][A-Z0-9_]*=\047[^\047]*\047$/) continue
    start = index(entry, "=") + 2
    value = substr(entry, start, length(entry) - start)
    if (characters(value) < 6) continue
    add(value)
    for (kind = 0; kind <= 2; kind++) {
      url = encoded(value, kind); add(url); add(lowerHex(url))
    }
  }
  close(store)
  if (status < 0) {
    print "Cannot read the secret store to mask deploy output." > "/dev/stderr"
    exit 1
  }
  # The caller appends one sentinel byte, so the final record has no newline.
  status = getline line
  while (status > 0) {
    status = getline following
    if (status > 0) printf "%s\n", masked(line)
    else printf "%s", masked(substr(line, 1, length(line) - 1))
    line = following
  }
  if (status < 0) exit 1
}''';

/// Feeds a file through the filter without changing its final newline.
String dwMaskOutputFile(String file) =>
    "{ cat $file && printf '\\001'; } | dw_mask_output";

/// Captures both streams on the target and masks them before SSH returns
/// them. The nested shell keeps the command's stdin, traps and exit semantics.
String _maskedCommand(String command, String filter, String maskScript) =>
    '''
umask 077
dw_output_dir=\$(mktemp -d) || exit 1
trap 'rm -rf "\$dw_output_dir"' EXIT HUP INT TERM
dw_output_filter=${_quote(maskScript)}
dw_output_code=0
sh -c ${_quote(command)} >"\$dw_output_dir/out" 2>"\$dw_output_dir/err" || dw_output_code=\$?
{ cat "\$dw_output_dir/out" && printf '\\001'; } | $filter || exit 1
{ cat "\$dw_output_dir/err" && printf '\\001'; } | $filter >&2 || exit 1
exit "\$dw_output_code"
''';

/// Deploy-only transport decorator; secret commands keep their own transport.
/// The filter runs as the deploy user even for root provisioning commands.
class DwMaskedSshRunner extends DwSshRunner {
  DwMaskedSshRunner(
    this.inner, {
    required this.deployUser,
    required this.storeFile,
  }) : super(
         host: inner.host,
         user: inner.user,
         identityFile: inner.identityFile,
         connectTimeoutSeconds: inner.connectTimeoutSeconds,
       );

  final DwSshRunner inner;
  final String deployUser;
  final String storeFile;

  String get _maskScript =>
      '${dwSecretMaskFunction(storeFile)}\ndw_mask_output';
  static const _directFilter = r'sh -c "$dw_output_filter"';

  @override
  Future<DwSshResult> run(String command) {
    // Before setup creates the deploy user there cannot be its store. If a
    // store does exist, refuse rather than releasing unmasked output.
    final filter =
        "sh -c ${_quote('''
if [ "\$(id -un)" = ${_quote(deployUser)} ]; then
  sh -c "\$1"
elif id -u ${_quote(deployUser)} >/dev/null 2>&1; then
  sudo -n -u ${_quote(deployUser)} -H sh -c "\$1"
elif [ ! -e ${_quote(storeFile)} ]; then
  sh -c "\$1"
else
  echo 'Cannot mask deploy output without the deployment user.' >&2
  exit 1
fi''')} sh \"\$dw_output_filter\"";
    return inner.run(_maskedCommand(command, filter, _maskScript));
  }

  @override
  Future<DwSshResult> runPrivileged(String command) =>
      run(DwSshRunner.privilegedCommand(command));

  @override
  Future<DwSshResult> runAs(String deployUser, String command) => inner.runAs(
    deployUser,
    _maskedCommand(command, _directFilter, _maskScript),
  );

  @override
  Future<DwSshResult> runAsWithInput(
    String deployUser,
    String command,
    String input,
  ) => inner.runAsWithInput(
    deployUser,
    _maskedCommand(command, _directFilter, _maskScript),
    input,
  );
}
