import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';

/// The app's settings: one value per settings object, read with its defaults
/// while nobody has saved it, saved in one statement.
///
/// A settings object is a data object of the shared package whose every
/// field has a default, and whose `id` is a getter with a fixed value:
///
/// ```dart
/// final class SignInSettings extends DwDataObject with _$SignInSettings {
///   const SignInSettings({this.fixedCode, this.smsEnabled = false});
///
///   @override
///   String get id => 'signIn';
///
///   final String? fixedCode;
///   final bool smsEnabled;
/// }
/// ```
///
/// It is stored in the framework's `dw_setting` table under its wire name,
/// as the JSON the wire carries — which holds only what differs from the
/// defaults, so a default changed in the code reaches every value nobody
/// changed, and a field added later reads as its default. A settings object
/// is published like any data object: `ctx.publish(channel, saved)`.
///
/// The project declares no table, no row and no lock for it: [save] is one
/// upsert, and [update] locks the one row it changes, so two first saves at
/// once both succeed and two edits of different fields both land.
///
/// **A stored value survives the object changing under it.** Reading is per
/// field: a stored field that no longer decodes — an enum value that was
/// removed, a field whose type changed — reads as that field's default, and
/// the server logs it once; a field no longer declared is ignored. A read
/// never fails over what is stored, and the next [update] or [save] writes the
/// value clean. Two consequences follow from storing only what differs from
/// the defaults: **renaming the class resets it to its defaults** (the area is
/// its wire name), and **changing a default changes every value that was
/// equal to the old default**, since nothing of it was stored.
final class DwSettingsStore {
  @internal
  const DwSettingsStore(this._db, this._protocol, this._log);

  final DwDatabaseHandle _db;
  final DwWireProtocol _protocol;
  final DwServerLogger _log;

  /// The stored fields already reported as unreadable, by area — reported
  /// once per process, not at every read.
  static final Set<String> _reported = {};

  /// The stored value of [S], or its defaults when nothing is stored.
  ///
  /// Throws [StateError] when [S] is not a data object of this server's
  /// protocol — say, when the type argument was left to inference.
  Future<S> read<S extends DwDataObject>() async {
    final rows = await _db.query(
      'SELECT value FROM dw_setting WHERE area = @area',
      params: {'area': _areaOf(S)},
    );
    return _decode<S>(_areaOf(S), rows.isEmpty ? null : rows.single['value']);
  }

  /// Stores [value] as the whole of its settings, in one statement, and
  /// returns it. For a form that sends every field; an edit of some fields
  /// is [update].
  Future<S> save<S extends DwDataObject>(S value) async {
    await _db.execute(
      'INSERT INTO dw_setting (area, value) VALUES (@area, @value::jsonb) '
      'ON CONFLICT (area) DO UPDATE '
      'SET value = EXCLUDED.value, updated_at = now()',
      params: {'area': _areaOf(value.runtimeType), 'value': _encode(value)},
    );
    return value;
  }

  /// Reads [S], applies [change] and stores the result, with the row locked
  /// in between: two changes of one settings object apply one after the
  /// other, and neither is lost. Returns the stored value; one that [change]
  /// left equal is not written.
  Future<S> update<S extends DwDataObject>(S Function(S current) change) {
    final area = _areaOf(S);
    return _db.transaction((tx) async {
      // The row exists before it is locked: `FOR UPDATE` locks nothing that
      // is not there, and two first changes would both read the defaults.
      await tx.execute(
        "INSERT INTO dw_setting (area, value) VALUES (@area, '{}') "
        'ON CONFLICT (area) DO NOTHING',
        params: {'area': area},
      );
      final rows = await tx.query(
        'SELECT value FROM dw_setting WHERE area = @area FOR UPDATE',
        params: {'area': area},
      );
      final current = _decode<S>(area, rows.single['value']);
      final next = change(current);
      if (next == current) return current;
      await tx.execute(
        'UPDATE dw_setting SET value = @value::jsonb, updated_at = now() '
        'WHERE area = @area',
        params: {'area': area, 'value': _encode(next)},
      );
      return next;
    });
  }

  String _areaOf(Type type) {
    if (!_protocol.knows(type)) {
      throw StateError(
        'settings of $type: not a data object of this server\'s protocol — '
        'name the settings object as the type argument',
      );
    }
    return _protocol.nameOf(type);
  }

  S _decode<S extends DwDataObject>(String area, Object? stored) {
    final S defaults;
    try {
      defaults = _protocol.decodeAs<S>(const <String, Object?>{});
    } on Object catch (error) {
      // An absent field without a default reads as `null` where the type does
      // not allow one: the defaults are what a settings object is.
      throw StateError(
        'settings of $S: every field of a settings object needs a default '
        '($error)',
      );
    }
    final Object? json;
    try {
      json = stored is String ? jsonDecode(stored) : stored;
    } on FormatException {
      _report(area, ['<the whole value>'], stored);
      return defaults;
    }
    if (json == null) return defaults;
    if (json is! Map<String, Object?>) {
      _report(area, ['<the whole value>'], json);
      return defaults;
    }
    try {
      return _protocol.decodeAs<S>(json);
    } on Object {
      // One field or more no longer reads: keep every field that does, each
      // tried on its own over the defaults of the rest.
    }
    final readable = <String, Object?>{};
    final unreadable = <String>[];
    for (final MapEntry(:key, :value) in json.entries) {
      try {
        _protocol.decodeAs<S>({key: value});
        readable[key] = value;
      } on Object {
        unreadable.add(key);
      }
    }
    _report(area, unreadable, json);
    try {
      return _protocol.decodeAs<S>(readable);
    } on Object {
      return defaults;
    }
  }

  void _report(String area, List<String> fields, Object? stored) {
    final fresh = [
      for (final field in fields)
        if (_reported.add('$area.$field')) field,
    ];
    if (fresh.isEmpty) return;
    _log.warning(
      'settings $area: stored ${fresh.join(', ')} no longer read as the '
      'settings object declares them, and read as the defaults instead '
      '(stored: $stored); the next save writes them clean',
    );
  }

  String _encode(DwDataObject value) => jsonEncode(value.toJson());
}

/// Values a project kept elsewhere — a key/value table, a single-row table of
/// its own — carried into a settings object by the migration that drops them.
///
/// A project never writes the framework's `dw_*` tables; this is the one
/// statement that does it for a settings object:
///
/// ```dart
/// await m.carrySettings('ClubSettings', fromSql: '''
///   SELECT jsonb_strip_nulls(jsonb_build_object(
///     'clubName', (SELECT value FROM app_setting WHERE key = 'clubName')))''');
/// await m.dropTable('app_setting');
/// ```
extension DwSettingsMigration on DwMigrationContext {
  /// Merges the JSON object [fromSql] answers — one row, one `jsonb` column,
  /// in the wire shape of the settings object named [area] (its wire name) —
  /// into what is stored for it: a field carried here replaces the stored
  /// one, the rest stay. Nothing is written when the query answers no row,
  /// `NULL` or an empty object.
  Future<void> carrySettings(String area, {required String fromSql}) => sql(
    'INSERT INTO dw_setting (area, value) '
    'SELECT @area, carried.value FROM ($fromSql) AS carried(value) '
    "WHERE carried.value IS NOT NULL AND carried.value <> '{}'::jsonb "
    'ON CONFLICT (area) DO UPDATE '
    'SET value = dw_setting.value || EXCLUDED.value, updated_at = now()',
    params: {'area': area},
  );
}
