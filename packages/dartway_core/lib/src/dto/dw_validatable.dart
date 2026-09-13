import '../result/dw_refusal.dart';

/// A DTO that checks its own input.
///
/// Declared here, in the shared contract, because both sides run the same
/// code: the client before sending — an invalid form costs no round trip —
/// and the server before the handler, since a client is never trusted to have
/// checked. The first refusal is the answer on both sides.
///
/// [validate] must depend on the DTO's fields only: a DTO is a value, and the
/// client relies on an equal DTO validating equally.
abstract interface class DwValidatable {
  /// Every problem with the input; empty when the input is acceptable.
  List<DwRefusal> validate();
}
