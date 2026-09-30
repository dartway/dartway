import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One identifier change of one kind, for as long as its sheet is open.
final identityChangeProvider = NotifierProvider.autoDispose
    .family<IdentityChangeController, IdentityChange, DwIdentifierKind>(
      IdentityChangeController.new,
    );

/// Adds or changes an identifier of [kind]: the new value, then the code sent
/// to it.
///
/// `DwRequestIdentifierCode` asks for the code; `DwConfirmIdentifier` confirms
/// it — with `replace` when the member already has one of this kind, so the
/// new value takes the old one's place instead of signing in beside it. The
/// profile is not read again: the server republishes it in the confirming
/// transaction, and the answer already carries it.
///
/// The results are returned for `dw.action` to show a refusal; the controller
/// reads them only to move the flow on.
class IdentityChangeController extends Notifier<IdentityChange> {
  IdentityChangeController(this.kind);

  final DwIdentifierKind kind;

  @override
  IdentityChange build() => const IdentityChange();

  void editDraft(String value) => state = IdentityChange(
    draft: value,
    code: state.code,
    ticket: state.ticket,
  );

  void editCode(String value) => state = IdentityChange(
    draft: state.draft,
    code: value,
    ticket: state.ticket,
  );

  /// Back to typing the value: the code sent belongs to the old one.
  void changeIdentifier() => state = IdentityChange(draft: state.draft);

  /// Sends a code to the typed value.
  Future<DwCallResult<DwCodeTicket>> requestCode() async {
    final draft = state.draft;
    final result = await dw.command(
      DwRequestIdentifierCode(
        kind: kind,
        identifier: AuthIdentifier.normalize(kind, draft) ?? draft,
      ),
    );
    if (!ref.mounted) return result;
    if (result case DwCallOk(:final value)) {
      state = IdentityChange(draft: draft, ticket: value);
    }
    return result;
  }

  /// Confirms the code sent; [replace] when the member already has an
  /// identifier of this kind.
  Future<DwCallResult<DwIdentityInfo>> confirm({required bool replace}) async {
    // The code step is only ever shown after a successful [requestCode].
    final ticket =
        state.ticket ?? (throw StateError('confirm ran before requestCode'));
    final result = await dw.command(
      DwConfirmIdentifier(
        ticketId: ticket.id,
        code: state.code,
        replace: replace,
      ),
    );
    if (!ref.mounted) return result;
    // Taken by another account: the ticket is used up, and the way on is
    // another value.
    if (result case DwCallRefused(
      :final refusal,
    ) when refusal.isCode(DwAuthRefusal.identifierTaken)) {
      changeIdentifier();
    }
    return result;
  }
}

/// Where one identifier change stands: the value typed, the code typed, and
/// the ticket of the code sent — `null` until one is.
final class IdentityChange {
  const IdentityChange({this.draft = '', this.code = '', this.ticket});

  final String draft;
  final String code;
  final DwCodeTicket? ticket;
}
