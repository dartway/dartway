import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/src/app/session/domain/dw_session_state_model.dart';
import 'package:dartway_serverpod_core_flutter/src/app/session/state/dw_user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userProfile', () {
    test('follows the session in and out', () {
      final providers = DwUserProfileProviders<_FakeProfile>(_session);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Nothing is watching yet, so the pair has to see the state the session
      // is already in — a profile loaded before the first widget builds.
      container.read(_session.notifier).signIn(_FakeProfile(1));

      expect(container.read(providers.userProfile)?.id, 1);
      expect(container.read(providers.requireUserProfile).id, 1);

      container.read(_session.notifier).signOut();

      expect(container.read(providers.userProfile), isNull);
    });

    test('is null when the app runs without an auth key manager', () {
      // sessionProvider is null in that case, and nobody is ever signed in.
      final providers = DwUserProfileProviders<_FakeProfile>(null);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(providers.userProfile), isNull);
    });
  });

  group('requireUserProfile', () {
    test('throws with a message pointing at the scope when signed out', () {
      final providers = DwUserProfileProviders<_FakeProfile>(_session);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod 3 rethrows what a provider threw wrapped in a
      // ProviderException, so the assertion is on the message reaching the
      // developer, not on the exception type.
      expect(
        () => container.read(providers.requireUserProfile),
        throwsA(
          isA<Object>().having(
            (error) => error.toString(),
            'toString',
            allOf(
              contains('DwUserAsyncScope'),
              contains('dw.userProfileProvider'),
            ),
          ),
        ),
      );
    });

    test('recovers once a user signs in', () {
      final providers = DwUserProfileProviders<_FakeProfile>(_session);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() => container.read(providers.requireUserProfile), throwsA(anything));

      container.read(_session.notifier).signIn(_FakeProfile(7));

      expect(container.read(providers.requireUserProfile).id, 7);
    });
  });
}

final _session =
    NotifierProvider<_SessionStub, DwSessionStateModel<_FakeProfile>>(
      _SessionStub.new,
    );

/// Stands in for `dw.sessionProvider`: the profile pair only ever listens to
/// the state it carries.
class _SessionStub extends Notifier<DwSessionStateModel<_FakeProfile>> {
  @override
  DwSessionStateModel<_FakeProfile> build() =>
      const DwSessionStateModel<_FakeProfile>();

  void signIn(_FakeProfile profile) => state = DwSessionStateModel(
    signedInUserProfile: profile,
    signedInUserId: profile.id,
  );

  void signOut() => state = const DwSessionStateModel<_FakeProfile>();
}

class _FakeProfile implements SerializableModel {
  _FakeProfile(this.id);

  final int id;

  @override
  Map<String, dynamic> toJson() => {'id': id};
}
