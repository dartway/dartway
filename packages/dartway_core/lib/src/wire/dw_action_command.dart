part of 'dw_server_call.dart';

/// A change. Its fields are its input; [R] is what the server answers with.
///
/// The client sends every command with an idempotency key it generates once
/// per intent (`Dw-Idempotency-Key`); the server stores the outcome per key and
/// answers a repeat with the stored outcome instead of executing again. A
/// command therefore survives a lost response without creating a second row
/// (#105).
///
/// **The result is one value, untagged:** a DTO, a JSON primitive (`int`,
/// `double`, `num`, `String`, `bool`) or `null` — `DwActionCommand<void>`
/// answers nothing, and a nullable `R` may answer `null`. The type on the wire
/// is the command's `R`, so nothing names it: a DTO result is decoded by
/// looking `R` up in the protocol (a registered DTO class, or its nullable
/// form). Collections are wrapped in a DTO (D-006): a generic `List<T>` cannot
/// be decoded from an erased type argument.
///
/// An input never carries a field the server decides — the owner, timestamps,
/// status, storage keys. The handler derives those from its context.
abstract class DwActionCommand<R> extends DwServerCall<R> {
  const DwActionCommand();

  @override
  Object? encodeResult(R result, DwWireProtocol protocol) =>
      protocol.encodeValue(result);

  @override
  R decodeResult(Object? json, DwWireProtocol protocol) =>
      protocol.decodeValue<R>(json);
}
