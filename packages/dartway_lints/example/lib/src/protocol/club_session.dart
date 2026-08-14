// A hand-written stand-in for what `serverpod generate` writes into a client
// package: `id` is nullable, `description` is nullable, `isPublished` carries a
// `default=` — and all three therefore arrive as optional arguments, which is
// the whole mechanism `model_rebuild_by_constructor` exists for.
//
// It sits under `lib/src/protocol/` on purpose. That is where the generator puts
// it, and the rule leaves that path alone: `copyWith` below rebuilds the model
// field by field because rebuilding is precisely its job, and it must stay
// silent. A fixture proving the exemption is worth more than a comment claiming
// it — the same shape one folder up is a warning.

import 'package:serverpod_client/serverpod_client.dart';

class _Undefined {}

class ClubSession implements SerializableModel {
  ClubSession({
    this.id,
    required this.title,
    this.description,
    this.isPublished = false,
  });

  int? id;

  String title;

  String? description;

  bool isPublished;

  ClubSession copyWith({
    Object? id = _Undefined,
    String? title,
    Object? description = _Undefined,
    bool? isPublished,
  }) => ClubSession(
    id: id is int? ? id : this.id,
    title: title ?? this.title,
    description: description is String? ? description : this.description,
    isPublished: isPublished ?? this.isPublished,
  );

  @override
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    if (description != null) 'description': description,
    'isPublished': isPublished,
  };
}
