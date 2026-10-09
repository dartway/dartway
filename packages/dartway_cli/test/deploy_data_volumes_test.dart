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
    test('an old, differently named data volume present and the expected one '
        'missing — refused', () {
      final verdict = judgeDataVolumes(
        volumeListing: 'shop_postgres_data\nshop_minio_data\n',
        projectPrefix: 'shop',
        expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('shop_minio_data'));
      expect(verdict.detail, contains('shop_storage_data'));
    });

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
    test('postgres already deployed, storage never bundled before — turning it '
        'on for the first time is not a rename and must not be refused', () {
      final verdict = judgeDataVolumes(
        volumeListing: 'shop_postgres_data\n',
        projectPrefix: 'shop',
        expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
      );
      expect(verdict.ok, isTrue, reason: verdict.detail);
      expect(verdict.detail, contains('shop_storage_data'));
    });

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

    test('a certbot volume never counts as the stranger that turns a rename '
        'refusal on', () {
      // Only certbot beside the missing expected volume — no minio_data,
      // no anything else. Still nothing to protect: pass.
      final verdict = judgeDataVolumes(
        volumeListing: 'shop_certbot_data\n',
        projectPrefix: 'shop',
        expectedDataVolumes: {'shop_postgres_data', 'shop_storage_data'},
      );
      expect(verdict.ok, isTrue, reason: verdict.detail);
    });

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

  group('judgeStackIdentity', () {
    DwDataVolumeVerdict judge(
      String projectName, {
      String volumes = '',
      String configDirs = '',
    }) => judgeStackIdentity(
      projectName: projectName,
      environment: 'stage',
      volumeListing: volumes,
      configDirListing: configDirs,
    );

    test('its own data volume makes the stack ours', () {
      final verdict = judge(
        'molodey',
        volumes: 'molodey_postgres_data\nother_postgres_data\n',
      );
      expect(verdict.ok, isTrue);
    });

    // A project with an external database and no bundled storage has no data
    // volume at all: its secret store is all that names it.
    test('its own secret store alone makes the stack ours', () {
      final verdict = judge(
        'molodey',
        configDirs: '/home/dw_admin/.config/molodey/secrets.env\n',
      );
      expect(verdict.ok, isTrue);
    });

    test('an empty server is a fresh server', () {
      final verdict = judge('molodey');
      expect(verdict.ok, isTrue);
      expect(verdict.detail, contains('fresh server'));
    });

    test('the moved repository finds only the old name, and is told to pin '
        'it', () {
      final verdict = judge(
        'moloday',
        volumes: 'molodey_postgres_data\nmolodey_certbot_conf\n',
        configDirs: '/home/dw_admin/.config/molodey/secrets.env\n',
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('no "moloday" stack on this server'));
      expect(verdict.detail, contains('set "project: molodey" under stage'));
      expect(verdict.detail, contains('--env stage --new-stack'));
    });

    test('every foreign stack is named', () {
      final verdict = judge(
        'shop',
        volumes: 'blog_postgres_data\nfiles_storage_data\n',
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('blog, files exist'));
    });

    // Matched by whole suffix, not by prefix: another project whose name
    // starts with this one's is not this one.
    test('a longer name sharing the prefix is someone else', () {
      final verdict = judge('shop', volumes: 'shop_eu_postgres_data\n');
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('shop_eu exists'));
    });

    // The runner passes one combined answer as both listings.
    test('one combined answer reads the same as two listings', () {
      const answer =
          'molodey_postgres_data\n/home/dw_admin/.config/blog/secrets.env\n';
      final verdict = judgeStackIdentity(
        projectName: 'moloday',
        environment: 'stage',
        volumeListing: answer,
        configDirListing: answer,
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('blog, molodey exist'));
    });
  });
}
