import 'package:dartway_cli/src/deploy/data_volumes.dart';
import 'package:test/test.dart';

void main() {
  group('judgeDataVolumes', () {
    test('a first deploy — no data volume of this project yet — passes', () {
      final verdict = judgeDataVolumes(
        volumeListing: 'other_project_postgres_data\ncertbot_data\n',
        projectPrefix: 'shop',
        expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
      );
      expect(verdict.ok, isTrue);
      expect(verdict.detail, contains('first deploy'));
    });

    // The exact shape of #331: a server that has only ever run `storage:
    // minio` carries `shop_minio_data`, never `shop_storage_data`. Starting
    // the renamed stack on it must be refused, not silently create the new
    // volume empty.
    test(
      'an old, differently named data volume present and the expected one '
      'missing — refused',
      () {
        final verdict = judgeDataVolumes(
          volumeListing: 'shop_postgres_data\nshop_minio_data\n',
          projectPrefix: 'shop',
          expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
        );
        expect(verdict.ok, isFalse);
        expect(verdict.detail, contains('shop_minio_data'));
        expect(verdict.detail, contains('shop_storage_data'));
      },
    );

    test(
      'the expected volume already exists — passes even with an old one '
      'still beside it, which is the rollback copy, not a stranger to remove',
      () {
        final verdict = judgeDataVolumes(
          volumeListing:
              'shop_postgres_data\nshop_storage_data\nshop_minio_data\n',
          projectPrefix: 'shop',
          expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
        );
        expect(verdict.ok, isTrue);
        expect(verdict.detail, isNot(contains('remove')));
      },
    );

    // The regression this guards: a project that already has `postgres_data`
    // (every project does, from its very first deploy) turning `storage:
    // bundled` on for the first time — nothing renamed, nothing to protect —
    // must not be refused just because postgres has run before. What matters
    // is whether anything on the server *contradicts* the missing volume,
    // and nothing does: no old bucket volume under any other name exists.
    test(
      'postgres already deployed, storage never bundled before — turning it '
      'on for the first time is not a rename and must not be refused',
      () {
        final verdict = judgeDataVolumes(
          volumeListing: 'shop_postgres_data\n',
          projectPrefix: 'shop',
          expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
        );
        expect(verdict.ok, isTrue, reason: verdict.detail);
        expect(verdict.detail, contains('shop_storage_data'));
      },
    );

    // certbot's own volume is not "data" this guard protects — a lineage
    // reissues itself — so it must never be the reason a first `storage:
    // bundled` is refused, nor be reported as the missing volume's
    // contradiction.
    test(
      'a certbot volume beside a first-time storage enable changes nothing',
      () {
        final verdict = judgeDataVolumes(
          volumeListing: 'shop_postgres_data\nshop_certbot_data\n',
          projectPrefix: 'shop',
          expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
        );
        expect(verdict.ok, isTrue, reason: verdict.detail);
      },
    );

    test(
      'a certbot volume never counts as the stranger that turns a rename '
      'refusal on',
      () {
        // Only certbot beside the missing expected volume — no minio_data,
        // no anything else. Still nothing to protect: pass.
        final verdict = judgeDataVolumes(
          volumeListing: 'shop_certbot_data\n',
          projectPrefix: 'shop',
          expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
        );
        expect(verdict.ok, isTrue, reason: verdict.detail);
      },
    );

    test('a volume of another project with the same suffix is not confused '
        'for this project\'s', () {
      final verdict = judgeDataVolumes(
        volumeListing: 'shopfront_storage_data\n',
        projectPrefix: 'shop',
        expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
      );
      // No volume of "shop"'s own exists at all — a first deploy, not a
      // partial one — because "shopfront_storage_data" does not start with
      // "shop_".
      expect(verdict.ok, isTrue);
      expect(verdict.detail, contains('first deploy'));
    });

    test('the refusal never suggests removing anything before it passes', () {
      final verdict = judgeDataVolumes(
        volumeListing: 'shop_postgres_data\nshop_minio_data\n',
        projectPrefix: 'shop',
        expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, isNot(contains('docker volume rm')));
    });
  });
}
