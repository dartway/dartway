/// An enum whose values a newer build may add, and whose readers show what
/// they do not know neutrally instead of stopping.
///
/// **Every enum is strict unless marked.** A name this build does not know is
/// then a sign the app is out of date: the client switches to "update the
/// app" (`DwCoreRefusal.updateRequired`), because nothing it shows or does
/// with such data can be trusted to have handled every case — which is what
/// an enum is for.
///
/// Mark an enum open only when a value is **for display alone** and an
/// unknown one can be shown neutrally or left out without anyone acting on
/// it wrongly: the kind of an entry in an activity feed, the icon of a
/// notification. Never when behaviour depends on the value — a status that
/// decides what may happen next, a role, a permission, a kind of payment.
///
/// ```dart
/// enum IssueEventKind with DwOpenEnum { created, renamed, prioritized, unknown }
/// ```
///
/// An open enum declares a value named `unknown`: every reader — the app's
/// codecs, a row read on the server — turns a name it does not know into it.
/// **`unknown` is never stored**: writing it into a row throws, so a build
/// that did not know a value cannot overwrite it with this one. It does
/// travel on the wire as itself — a server that read a row it does not know
/// answers with `unknown` rather than failing the whole answer, and the
/// reader shows it as it shows any unknown value.
mixin DwOpenEnum on Enum {
  /// The name of the value unknown names are read as.
  static const String fallbackName = 'unknown';

  /// Whether this is the value a name this build does not know was read as.
  bool get isUnknown => name == fallbackName;
}

/// A name that no value of a strict enum has: this build is older than the
/// data it reads.
final class DwUnknownEnumValue extends FormatException {
  DwUnknownEnumValue(this.enumType, this.value)
    : super('"$value" is not a value of $enumType known to this build');

  final Type enumType;
  final String value;
}

/// An attempt to store the `unknown` of an open enum: it stands for a name
/// this build did not know, and writing it would replace that name.
///
/// A type of its own rather than a bare error, because a call can answer it.
/// The build sending `unknown` back is older than the data it is writing, so
/// on a call this is `DwCoreRefusal.updateRequired` — the caller cannot
/// correct its input, only become a build that knows the value. Left as a
/// failure anywhere else: a write with no caller has nobody to tell.
final class DwUnknownEnumWrite implements Exception {
  DwUnknownEnumWrite(this.enumType);

  final Type enumType;

  @override
  String toString() =>
      '$enumType.${DwOpenEnum.fallbackName} stands for a value this build '
      'does not know and cannot be written; update the app';
}
