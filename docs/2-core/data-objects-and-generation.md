# How is the contract between the server and the app declared?

Everything that travels between a DartWay server and its app is a Dart class in the project's
`<project>_shared` package: data objects, requests, commands, channel kinds, refusal codes, upload
purposes. The server package and the Flutter app both depend on it; there is no client package and
no second copy of a model anywhere. A field added to a class is a field both sides compile against.

`dartway_core_shared` is pure Dart — no `dart:io`, no Flutter — so the contract runs unchanged on
the VM, in the app and on the web. The shared package of the reference project is
`example/dartway_example_shared/lib/src/`.

## Three kinds, one base

`DwWireObject` is the base of everything on the wire, and a project never extends it directly
(`dartway generate` reports a class that does). A project class extends one of three kinds:

| Kind | Base | What it is |
|---|---|---|
| Data object | `DwDataObject` | What the server returns and publishes: the unit of client state |
| Request | a `DwDataRequest` kind — `DwSingleRequest`, `DwMaybeRequest`, `DwListRequest`, `DwPageRequest`, `DwTableRequest`, `DwWindowRequest` | A read; its fields are its parameters. See [requests-and-updates.md](requests-and-updates.md) |
| Command | `DwActionCommand<R>` | A change; its fields are its input, `R` its result. See [commands-and-idempotency.md](commands-and-idempotency.md) |

Requests and commands share the sealed base `DwServerCall`; a project never extends it either.

**Every data object has an `id` — an `int` or a `String`, never nullable.** Updates arriving on a
channel are merged into client state by it, so an object without an identity cannot be one. The id
is usually a field; a singleton view declares a fixed getter
(`example/dartway_example_shared/lib/src/admin.dart`):

```dart
final class AdminCounters extends DwDataObject with _$AdminCounters {
  const AdminCounters({
    required this.members,
    required this.upcomingSessions,
    required this.newsPosts,
  });

  /// A single object: its identity is fixed.
  @override
  String get id => 'admin-counters';

  final int members;
  final int upcomingSessions;
  final int newsPosts;
}
```

## Declaring a class

A library with generated classes names its part after itself and every class mixes in its
generated code (`example/dartway_example_shared/lib/src/news.dart`):

```dart
import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'news.dw.dart';

final class NewsPost extends DwDataObject with _$NewsPost {
  const NewsPost({
    required this.id,
    required this.title,
    required this.text,
    required this.author,
    required this.createdAt,
  });

  @override
  final int id;
  final String title;
  final String text;
  final PersonCard author;
  final DateTime createdAt;
}
```

The generator reports, file and line, every class that breaks one of these rules — and writes
nothing until all are fixed:

- the part is `part '<file>.dw.dart';` exactly, and the class declares `with _$<Name>`;
- the class **extends** its kind (implementing or mixing it in is refused), is public and has no
  type parameters;
- it has an unnamed generative constructor, and every serialised field is `final` and a **named**
  parameter of it. A field with an initializer, a getter, a `static` or a `late` field stays off
  the wire;
- fields declared in a project superclass travel too; an `abstract` class is not generated for, so
  it can serve as a shared base.

## Types that travel

| Dart type | On the wire |
|---|---|
| `int`, `double`, `String`, `bool` | themselves (a whole `double` may arrive as an integer; the decoder converts) |
| `DateTime` | UTC microseconds since the epoch (`DwJsonCodec.encodeDateTime`) |
| `Duration` | microseconds |
| `Uint8List` | base64 |
| an enum | the value's name |
| a DTO class | its own JSON, untagged |
| `List<T>`, `Map<String, T>` | a JSON array, a JSON object |
| `DwFieldPatch<T>` | absent, a value or `null` (below) |
| any of these with `?` | omitted when `null` |

A nested DTO must be a concrete, non-generic class. A list element or map value cannot itself be a
list, a map, a `Uint8List` or a patch — generated equality would compare the inner collection by
identity. Map keys are `String`: JSON has no other. Anything else (`num`, `Object`, `dynamic`, a
record, a row class) is refused with the list above.

**Nothing redundant travels (D-041).** A `null` optional field is omitted. A field whose constructor
parameter has a default is omitted when its value equals the default, and the decoder applies the
default when the key is absent — so a call written by hand (a tool, a test) may leave such a field
out. A nullable field with a non-null default writes an explicit `null`, because absent means the
default. The generator rebuilds the default from its value, so it must be a literal, an enum value,
a `Duration`, a const list or map, or a const DTO; anything else is reported.

## Clearing a field: `DwFieldPatch`

A command that edits a value which may be cleared cannot use a nullable field: `null` would mean
both "leave it" and "clear it". It declares `DwFieldPatch<T>` instead
(`example/dartway_example_shared/lib/src/people.dart`):

```dart
final class UpdateMyProfile extends DwActionCommand<UserProfile>
    with _$UpdateMyProfile
    implements DwSelfValidating {
  const UpdateMyProfile({
    this.firstName,
    this.lastName = const DwFieldPatch.keep(),
    this.gender = const DwFieldPatch.keep(),
    this.imageUrl = const DwFieldPatch.keep(),
  });

  /// `null` keeps the name; a name cannot be cleared.
  final String? firstName;
  final DwFieldPatch<String> lastName;
  final DwFieldPatch<UserGender> gender;
  final DwFieldPatch<String> imageUrl;
  // validate() omitted
}
```

On the wire a kept field is absent, `DwFieldPatch.set(value)` carries the value and
`DwFieldPatch.clear()` carries `null`; the handler reads it with `patch.apply(current)`. The patch
itself is never nullable and never patches a nullable type (`DwFieldPatch<String>`, not
`DwFieldPatch<String?>`) — clearing is already `clear()`.

The same problem exists in memory, so the generated `copyWith` of a data object takes a patch for
every nullable field and a plain nullable parameter for every other
(`packages/dartway_core_shared/test/fixtures/club_booking.dw.dart`):

```dart
ClubBooking copyWith({
  int? id,
  BookingStatus? status,
  DateTime? startsAt,
  DwFieldPatch<String> note = const DwFieldPatch.keep(),
  List<String>? tags,
  int? seats,
})
```

## What the generator writes

For each class, in `<file>.dw.dart`: the mixin `_$<Name>` (`dwTypeName`, `toJson`, `==`, `hashCode`
and — except for commands — `toString`), the decoder `$<Name>FromJson`, and for a data object the
`<Name>CopyWith` extension. Equality is by value: an equal request is the same client state. A
command gets no `toString`, because its input may carry a code or a password and a log interpolating
it would print them.

For the shared package, `lib/generated/dw_protocol.dart`: the registry of every class, composed with
the framework's own DTOs (`DwWireProtocol.core`). Its variable is the package name without `_shared`,
in camel case, plus `Protocol` — `dartway_example_shared` gives `dartwayExampleProtocol`. The server
and the app pass that one instance to `DwAppServer` and `DwFlutterCore`.

**A wire name is the class name, and it is unique** across the project and the framework's `Dw…`
DTOs: it is the call path of a request or command (`POST /dw/ListNews`) and the group name of a data
object in an update (`{"NewsPost": [...]}`). The generator reports a collision at both declarations, and `DwWireProtocol` throws at
construction if one gets through.

## Running it

```bash
dartway generate          # writes parts and registries, removes stale parts
dartway generate --check  # writes nothing; exits 1 when anything is out of date. For CI.
```

`dartway_generator` is a **dev dependency of the `<project>_server` package**, and `dartway
generate` runs the version the project resolved — the generator pins `analyzer` and must match the
`dartway_core_shared` the project builds against, so the CLI does not link one in. The same run
writes the server's row code (`lib/generated/dw_schema.dart`, see
[../4-server/database.md](../4-server/database.md)). A run is all or nothing: any problem is
reported and nothing is written, so a project is never half-generated.

**Never edit a generated file.** Each starts with `// GENERATED BY dartway generate. DO NOT EDIT.`;
the next run overwrites it, and `dartway check` fails with `generatedCodeStale` while it differs from
what the sources produce. The failure it guards against is silent: a field the part does not know
compiles, starts and travels without that field.

## Rows never leave the server

Row classes (`DwTableRow`) live in the server package, and the generator refuses one declared
anywhere else; a DTO field cannot be a row. A handler reads rows and maps them to data objects
(`example/dartway_example_server/lib/src/club_objects.dart`):

```dart
static PersonCard person(UserProfileRow row) => PersonCard(
  id: row.id!,
  firstName: row.firstName,
  lastName: row.lastName,
  imageUrl: row.imageUrl,
);
```

That mapping is the point, not overhead. A table has columns no client may see, one row feeds several
views (`PersonCard` for everyone, `UserProfile` for its owner), and a published object must be
readable by every subscriber of its channel ([channels-and-realtime.md](channels-and-realtime.md)).
A row sent as it is would leak the first and break the other two.

Changing how a class looks on the wire — renaming a field, changing its type — is a wire change:
see [wire-and-versions.md](wire-and-versions.md).
