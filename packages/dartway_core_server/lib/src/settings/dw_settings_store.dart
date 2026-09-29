import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

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
final class DwSettingsStore {
  @internal
  const DwSettingsStore(this._db, this._protocol);

  final DwDatabaseHandle _db;
  final DwWireProtocol _protocol;

  /// The stored value of [S], or its defaults when nothing is stored.
  ///
  /// Throws [StateError] when [S] is not a data object of this server's
  /// protocol — say, when the type argument was left to inference.
  Future<S> read<S extends DwDataObject>() async {
    final rows = await _db.query(
      'SELECT value FROM dw_setting WHERE area = @area',
      params: {'area': _areaOf(S)},
    );
    return _decode<S>(rows.isEmpty ? null : rows.single['value']);
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
      final current = _decode<S>(rows.single['value']);
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

  S _decode<S extends DwDataObject>(Object? stored) {
    final json = switch (stored) {
      null => const <String, Object?>{},
      String() => jsonDecode(stored),
      _ => stored,
    };
    try {
      return _protocol.decodeAs<S>(json);
    } on TypeError catch (error) {
      // An absent field without a default reads as `null` where the type does
      // not allow one: the defaults are what a settings object is.
      throw StateError(
        'settings of $S cannot be read from $json: every field of a settings '
        'object needs a default ($error)',
      );
    }
  }

  String _encode(DwDataObject value) => jsonEncode(value.toJson());
}
