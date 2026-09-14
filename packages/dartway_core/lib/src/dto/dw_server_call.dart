import '../channels/dw_channel.dart';
import '../protocol/dw_protocol.dart';
import '../protocol/dw_read.dart';
import '../result/dw_refusal.dart';
import 'dw_dto.dart';
import 'dw_pages.dart';

// One library for the call kinds: `DwServerCall` and `DwRequest` are sealed, so
// the switch over them in the server and the client is exhaustive, and the
// update policy a named super constructor chooses stays private to the kinds.
part 'dw_command.dart';
part 'dw_request.dart';

/// A DTO a client sends to its server to get an [R] back:
/// `POST /dw/<wire name>` with the DTO's own JSON as the body.
///
/// Exactly two kinds exist — a read ([DwRequest]) and a change
/// ([DwCommand]) — and a project extends one of their subclasses, never this
/// class. Both sides encode and decode the result with the same class, so the
/// result travels untagged: its type is the call's.
sealed class DwServerCall<R> extends DwDto {
  const DwServerCall();

  /// Encodes a result of this call for the wire (server side).
  Object? encodeResult(R result, DwProtocol protocol);

  /// Decodes a result of this call from the wire (client side). Throws
  /// [FormatException] when [json] is not a result of this call.
  R decodeResult(Object? json, DwProtocol protocol);
}
