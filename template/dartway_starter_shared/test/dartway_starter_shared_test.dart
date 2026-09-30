import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:test/test.dart';

UserProfile profile({
  int id = 7,
  int accountId = 42,
  UserRole role = UserRole.user,
  String firstName = 'Vera',
  String? phone = '79990000002',
  String? email,
}) => UserProfile(
  id: id,
  accountId: accountId,
  firstName: firstName,
  role: role,
  joinedAt: DateTime.utc(2026, 9, 14),
  phone: phone,
  email: email,
);

void main() {
  test('every data object, request and command travels and comes back '
      'equal', () {
    final objects = <DwWireObject>[
      const GetMyProfile(),
      const UpdateMyProfile(
        firstName: 'Vera',
        lastName: DwFieldPatch.clear(),
        gender: DwFieldPatch.set(UserGender.female),
        avatarFileId: DwFieldPatch.set(3),
      ),
      profile(email: 'vera@example.com'),
      profile(phone: null),
      const AdminCounters(members: 3, admins: 1, marketingOptIns: 2),
      const GetAdminCounters(),
      const ListUserProfiles(page: 2, pageSize: 20, search: 'ver'),
      const ListUserProfiles(role: UserRole.admin),
      UserCard(
        id: 7,
        profile: profile(),
        identifiers: [
          UserIdentifier(
            id: 1,
            kind: DwIdentifierKind.phone,
            value: '79990000002',
            addedAt: DateTime.utc(2026, 9, 14),
            verifiedAt: DateTime.utc(2026, 9, 14, 1),
          ),
          UserIdentifier(
            id: 2,
            kind: DwIdentifierKind.email,
            value: 'vera@example.com',
            addedAt: DateTime.utc(2026, 9, 15),
          ),
        ],
        termsAcceptedAt: DateTime.utc(2026, 9, 14),
      ),
      const GetUserCard(profileId: 7),
      const ChangeUserRole(profileId: 7, role: UserRole.admin),
      const AppSetting(id: AppSettingKeys.appName, value: 'Acme'),
      const ListAppSettings(),
      const SaveAppSetting(key: AppSettingKeys.signUpEnabled, value: 'false'),
    ];
    for (final object in objects) {
      expect(
        dartwayStarterProtocol.decodeNamed(object.dwTypeName, object.toJson()),
        object,
        reason: object.dwTypeName,
      );
    }
  });

  test('commands check the fields they carry, on either side', () {
    List<String> codes(DwSelfValidating dto) => [
      for (final refusal in dto.validate()) '${refusal.code}@${refusal.field}',
    ];
    expect(codes(const UpdateMyProfile(firstName: '  ')), [
      'firstNameRequired@firstName',
    ]);
    expect(codes(const UpdateMyProfile()), isEmpty);
    expect(codes(const SaveAppSetting(key: 'colour', value: 'red')), [
      'settingKeyUnknown@key',
    ]);
    for (final key in AppSettingKeys.all) {
      expect(codes(SaveAppSetting(key: key, value: 'x')), isEmpty);
    }
  });

  test("the member's own profile names no account: it lives on the caller's "
      'channel, resolved for whoever is signed in', () {
    expect(
      const GetMyProfile().channels.single.resolvedFor(42).wireName,
      'profile:42',
    );
  });

  test('the members table upserts matching profiles and removes one that '
      'leaves its filter; it searches name, phone and e-mail', () {
    const table = ListUserProfiles();
    expect(table.onUpdate(profile()), DwUpdateAction.upsert);

    const admins = ListUserProfiles(role: UserRole.admin, search: ' VER ');
    expect(
      admins.onUpdate(profile(role: UserRole.admin)),
      DwUpdateAction.upsert,
    );
    expect(admins.onUpdate(profile()), DwUpdateAction.remove);
    expect(
      const ListUserProfiles(search: '0002').onUpdate(profile()),
      DwUpdateAction.upsert,
      reason: 'by phone',
    );
    expect(
      const ListUserProfiles(
        search: 'EXAMPLE.com',
      ).onUpdate(profile(email: 'vera@example.com')),
      DwUpdateAction.upsert,
      reason: 'by e-mail',
    );
    expect(
      const ListUserProfiles(search: 'oleg').onUpdate(profile()),
      DwUpdateAction.remove,
    );
  });

  test('a profile names itself by its name, or by an identifier while it has '
      'none', () {
    expect(profile().displayName, 'Vera');
    expect(profile(firstName: '').displayName, '79990000002');
    expect(
      profile(firstName: '', phone: null, email: 'a@b.co').displayName,
      'a@b.co',
    );
  });

  group('AuthIdentifier', () {
    test('stores a phone as digits, a trunk 8 as the country code 7', () {
      const phone = DwIdentifierKind.phone;
      expect(
        AuthIdentifier.normalize(phone, '+7 (999) 000-00-01'),
        '79990000001',
      );
      expect(AuthIdentifier.normalize(phone, '8 999 000 00 01'), '79990000001');
      expect(
        AuthIdentifier.normalize(phone, '+44 20 7946 0958'),
        '442079460958',
      );
      expect(AuthIdentifier.normalize(phone, '12345'), isNull);
      expect(AuthIdentifier.normalize(phone, '1234567890123456'), isNull);
      expect(AuthIdentifier.normalize(phone, 'vera@example.com'), isNull);
    });

    test('stores an e-mail trimmed and lower-cased', () {
      const email = DwIdentifierKind.email;
      expect(
        AuthIdentifier.normalize(email, ' Vera@Example.COM '),
        'vera@example.com',
      );
      expect(AuthIdentifier.normalize(email, 'vera@'), isNull);
      expect(AuthIdentifier.normalize(email, 'vera@example'), isNull);
      expect(AuthIdentifier.normalize(email, '79990000001'), isNull);
    });

    test('is idempotent', () {
      for (final raw in ['+7 999 000-00-01', ' Ann@Example.com ']) {
        final kind = DwIdentifierKind.of(raw);
        final once = AuthIdentifier.normalize(kind, raw)!;
        expect(AuthIdentifier.normalize(kind, once), once);
      }
    });
  });
}
