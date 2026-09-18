// Not part of the public API: the rule the app's side of the bridge applies
// to every window message, and the one piece of that channel a VM test can
// reach — the channel itself needs a browser.
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:dartway_studio_bridge/src/transport/host/studio_host_peer.dart';
import 'package:flutter_test/flutter_test.dart';

/// An app in a frame hears every window message there is. This is how it
/// tells the Studio that embedded it from everything else.
void main() {
  late StudioHostPeer peer;
  setUp(() => peer = StudioHostPeer());

  test('answers nobody in particular until someone has spoken', () {
    expect(peer.origin, isNull);
  });

  test('a message from anything but the parent frame is refused, whatever '
      'its origin says', () {
    expect(
      peer.refuse(fromParent: false, origin: 'https://studio.dartway.dev'),
      StudioMessageDropReason.foreignSource,
      reason: 'an origin is a string anybody can have',
    );
    expect(peer.origin, isNull);
  });

  test('the parent is heard, and the first message it is believed on pins '
      'where the answers go', () {
    expect(
      peer.refuse(fromParent: true, origin: 'https://studio.dartway.dev'),
      isNull,
    );
    peer.accepted('https://studio.dartway.dev');
    expect(peer.origin, 'https://studio.dartway.dev');
  });

  test('once pinned, another origin is refused rather than followed — this '
      'is the manifest going to the wrong Studio', () {
    peer.accepted('https://studio.dartway.dev');
    expect(
      peer.refuse(fromParent: true, origin: 'https://evil.example'),
      StudioMessageDropReason.foreignOrigin,
    );
    expect(peer.origin, 'https://studio.dartway.dev');
  });

  test('a nested preview cannot take the address over: the grandchild is not '
      'the parent', () {
    peer.accepted('https://studio.dartway.dev');
    // The app embeds a preview of its own; that frame speaks from the same
    // origin as the real Studio and is still not the peer.
    expect(
      peer.refuse(fromParent: false, origin: 'https://studio.dartway.dev'),
      StudioMessageDropReason.foreignSource,
    );
  });

  test('the pin is the first accepted message, not the last', () {
    peer
      ..accepted('https://studio.dartway.dev')
      ..accepted('https://other.example');
    expect(peer.origin, 'https://studio.dartway.dev');
  });
}
