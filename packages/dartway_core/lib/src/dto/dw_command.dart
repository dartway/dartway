import '../protocol/dw_protocol.dart';
import 'dw_dto.dart';

/// A change. Its fields are its input; [R] is what the server answers with.
///
/// The client sends every command with an idempotency key it generates once
/// per intent; the server stores the outcome per key and answers a repeat with
/// the stored outcome instead of executing again. A command therefore survives
/// a lost response without creating a second row (#105).
///
/// A command's result is a single value: a DTO, a JSON primitive or `null`
/// (`DwCommand<void>`). Collections are wrapped in a DTO.
///
/// An input never carries a field the server decides — the owner, timestamps,
/// status, storage keys. The handler derives those from its context.
abstract class DwCommand<R> extends DwDto {
  const DwCommand();

  /// Encodes a result of this command for the wire (server side).
  Object? encodeResult(R result, DwProtocol protocol) =>
      protocol.encodeValue(result);

  /// Decodes a result of this command from the wire (client side).
  R decodeResult(Object? json, DwProtocol protocol) =>
      protocol.decodeValue(json) as R;
}
