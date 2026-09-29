import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// The commands that add or change an identifier.
///
/// `DwRequestIdentifierCode` asks for the code; `DwConfirmIdentifier` confirms
/// it — with `replace` when the member already has one of this kind, so the
/// new value takes the old one's place instead of signing in beside it. The
/// profile is not read again: the server republishes it in the confirming
/// transaction, and the answer already carries it.
abstract final class IdentityCommands {
  /// Sends a code to [identifier], a [kind] the member typed.
  static Future<DwCallResult<DwCodeTicket>> requestCode(
    DwIdentifierKind kind,
    String identifier,
  ) => dw.command(
    DwRequestIdentifierCode(
      kind: kind,
      identifier: AuthIdentifier.normalize(kind, identifier) ?? identifier,
    ),
  );

  /// Confirms [ticket] with [code]; [replace] when the member already has an
  /// identifier of this kind.
  static Future<DwCallResult<DwIdentityInfo>> confirm(
    DwCodeTicket ticket,
    String code, {
    required bool replace,
  }) => dw.command(
    DwConfirmIdentifier(ticketId: ticket.id, code: code, replace: replace),
  );
}
