import '../protocol/studio_bridge_message.dart';
import '../protocol/studio_bridge_protocol.dart';

/// What a channel did with a window message it did not deliver, and at which
/// step it let it go.
///
/// Ignoring foreign traffic on `window` silently is correct — it is normal
/// traffic on a shared bus. The cost is that a rejection then looks exactly
/// like every other reason a message never arrived, so an embedder debugging a
/// connection is left guessing. These name the step instead.
enum StudioMessageDropReason {
  /// Not a `MessageEvent` at all. Effectively unreachable on a `message`
  /// listener; kept so the enum covers every early return the channel has.
  notAMessageEvent,

  /// The sender's origin is not the app's. Studio-side only: the app-side
  /// channel pins no origin (see the origin note on `studio_host_channel.dart`).
  foreignOrigin,

  /// The origin matched, but the sender is not the window of *this* channel's
  /// frame. Studio-side only, and the reason an embedder cannot reproduce the
  /// channel's filtering from outside: a page with two frames on one origin —
  /// a live preview and a probe, say — cannot tell them apart without this.
  foreignSource,

  /// The event carried something other than a string. Every bridge message is
  /// JSON encoded as a string.
  nonStringData,

  /// A string, but no bridge envelope in it: unparseable, or JSON that does not
  /// carry [StudioBridgeProtocol.envelopeKey]. Somebody else's message —
  /// nothing to repair.
  notAnEnvelope,

  /// Our envelope at another protocol version. The one case that looks like
  /// silence and is not: both sides are speaking the bridge protocol and
  /// neither will hear the other until one of them is rebuilt.
  versionMismatch,

  /// Our envelope, our version, a message type this build does not know.
  /// Expected and harmless in one direction — a type added inside a version is
  /// how the protocol grows without cutting off the field (see
  /// [StudioBridgeProtocol.version]) — so read it as "the other side is newer",
  /// not as a fault.
  unknownType;

  /// Why the string [data] off the wire would not become a message, or null
  /// when it decodes cleanly.
  ///
  /// The steps before this one — is it a message event, whose origin, whose
  /// window, is the data a string — belong to the transport that observed the
  /// event. This is the part an embedder watching `window` from outside cannot
  /// write without re-implementing the envelope, which is precisely the copy
  /// that drifts on the next protocol change.
  static StudioMessageDropReason? ofPayload(String data) {
    final version = StudioBridgeProtocol.envelopeVersionOf(data);
    if (version == null) return notAnEnvelope;
    if (version != StudioBridgeProtocol.version) return versionMismatch;
    return StudioBridgeMessage.tryDecode(data) == null ? unknownType : null;
  }
}

/// One window message a channel did not deliver.
class StudioMessageDrop {
  const StudioMessageDrop(this.reason, {this.origin, this.envelopeVersion});

  final StudioMessageDropReason reason;

  /// The sender's origin, when the event carried one.
  final String? origin;

  /// The version read out of the envelope — present for
  /// [StudioMessageDropReason.versionMismatch] and
  /// [StudioMessageDropReason.unknownType], null when there was no envelope to
  /// read it from.
  final int? envelopeVersion;

  @override
  String toString() {
    final details = [
      if (origin != null) 'origin: $origin',
      if (envelopeVersion != null) 'envelope: v$envelopeVersion',
    ];
    return 'StudioMessageDrop(${reason.name}'
        '${details.isEmpty ? '' : ', ${details.join(', ')}'})';
  }
}

/// Told about every window message a channel refused, and nothing else — the
/// delivered ones are the channel's `messages` stream.
///
/// The bridge still says nothing by default: an observer is installed by
/// whoever is debugging a connection, and installing one changes no behaviour.
typedef StudioMessageDropObserver = void Function(StudioMessageDrop drop);
