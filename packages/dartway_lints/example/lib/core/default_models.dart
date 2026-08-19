// The under-eager half of the fixture, and the reason the exemption exists: an
// app registers one skeleton default per model, every one of them built field
// by field with `id: dw.repo.mockModelId`. There is no row here to rebuild —
// the instance is invented from nothing to give the loading skeleton a shape —
// so not a single lint may fire in this file. custom_lint fails on an
// unexpected report exactly as it does on a missing one.
//
// The file is deliberately free of `// ignore_for_file:`. That is what the
// framework's own template used to carry, and a rule that has to be silenced
// wherever the framework's own API is used is a rule people learn to scroll
// past.

import '../src/protocol/club_session.dart';
import 'dw_core.dart';

class DefaultModels {
  static void initRepository() {
    dw.repo.setupRepository(
      defaultModel: ClubSession(
        id: dw.repo.mockModelId,
        title: 'Group workout',
        description: 'One hour group workout',
        isPublished: true,
      ),
    );

    // The sentinel travels with the value: the instance is built in a helper
    // and registered somewhere else entirely. An exemption keyed on the
    // `defaultModel:` argument position would report this one, which is why the
    // rule reads the id instead.
    dw.repo.setupRepository(defaultModel: _archivedSessionSkeleton());
  }

  static ClubSession _archivedSessionSkeleton() =>
      ClubSession(id: dw.repo.mockModelId, title: 'Archived session');
}
