import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'results.dw.dart';

final class ListResult extends DwActionCommand<List<Note>> with _$ListResult {
  const ListResult();
}

final class MapResult extends DwActionCommand<Map<String, int>>
    with _$MapResult {
  const MapResult();
}

final class ObjectResult extends DwActionCommand<Object?> with _$ObjectResult {
  const ObjectResult();
}

final class NullableDtoResult extends DwActionCommand<Note?>
    with _$NullableDtoResult {
  const NullableDtoResult();
}

final class PrimitiveResult extends DwActionCommand<double?>
    with _$PrimitiveResult {
  const PrimitiveResult();
}

final class Note extends DwDataObject with _$Note {
  const Note({required this.id});

  @override
  final String id;
}

enum Mood with DwOpenEnum { calm, loud }

final class MoodNote extends DwDataObject with _$MoodNote {
  const MoodNote({required this.id, required this.mood});

  @override
  final String id;
  final Mood mood;
}
