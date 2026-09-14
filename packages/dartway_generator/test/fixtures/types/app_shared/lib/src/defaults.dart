import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'catalog.dart';
import 'units.dart' as units;

part 'defaults.dw.dart';

/// A top-level constant a default names.
const defaultTitle = 'Untitled';

/// Every field kind with a constructor default (D-041): an absent field
/// decodes to its default, and a value equal to it stays off the wire.
final class Settings extends DwDataObject with _$Settings {
  const Settings({
    required this.id,
    this.count = 3,
    this.offset = -1,
    this.enabled = true,
    this.title = defaultTitle,
    this.escaped = 'it\'s \$5\n\\',
    this.ratio = 1,
    this.color = Color.green,
    this.unit = units.Unit.kg,
    this.timeout = const Duration(seconds: 30),
    this.label = 'none',
    this.maybeColor = Color.red,
    this.note,
    required this.createdAt,
    this.startsAt,
    this.tags = const ['a', 'b'],
    this.empty = const [],
    this.limits = const {'max': 10, 'min': 1},
    this.noLimits = const {},
    this.maybeTags = const ['x'],
    this.dimensions = const units.Dimensions(id: 'default', width: 1),
    this.shelf = const [units.Dimensions(id: 'shelf', width: 2, height: 0.5)],
    this.ref = fallbackRef,
    this.loose = const Loose.fixed(),
  });

  @override
  final int id;
  final int count;
  final int offset;
  final bool enabled;
  final String title;
  final String escaped;
  final double ratio;
  final Color color;
  final units.Unit unit;
  final Duration timeout;
  final String? label;
  final Color? maybeColor;
  final String? note;

  /// A DateTime has no constant form, so it is required or nullable.
  final DateTime createdAt;
  final DateTime? startsAt;
  final List<String> tags;
  final List<int> empty;
  final Map<String, int> limits;
  final Map<String, bool> noLimits;
  final List<String>? maybeTags;
  final units.Dimensions dimensions;
  final List<units.Dimensions> shelf;

  /// Named by a static of the class, which the generated part cannot see
  /// unqualified: the default is rebuilt from its value.
  final Ref ref;

  /// A DTO without a const unnamed constructor, made by a named one.
  final Loose loose;

  static const fallbackRef = Ref(id: 'fallback');
}

final class Loose extends DwDataObject with _$Loose {
  Loose({required this.id});

  const Loose.fixed() : id = 'fixed';

  @override
  final String id;
}

/// A request's defaults: the usual shape of a search.
final class SearchItems extends DwListRequest<Item> with _$SearchItems {
  const SearchItems({
    this.query = '',
    this.limit = 20,
    this.colors = const [Color.red, Color.blue],
    this.since,
  });

  final String query;
  final int limit;
  final List<Color> colors;
  final DateTime? since;
}

/// A command's defaults next to a patch, whose absence stays `keep`.
final class UpdateSettings extends DwActionCommand<void> with _$UpdateSettings {
  const UpdateSettings({
    required this.settingsId,
    this.title = const DwFieldPatch.keep(),
    this.notify = true,
  });

  final int settingsId;
  final DwFieldPatch<String> title;
  final bool notify;
}
