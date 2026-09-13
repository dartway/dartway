// DTOs of the test application, written by hand in the shape `dartway
// generate` produces (tagging, omission of absent fields, value equality).
import 'package:dartway_server/dartway_server.dart';

enum TestChannel with DwChannelKind { notes, account, public, broken, nobody }

final class NoteView extends DwDataObject {
  const NoteView({required this.id, required this.text, this.ownerId});

  @override
  final int id;
  final String text;
  final int? ownerId;

  @override
  String get dwTypeName => 'NoteView';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    if (ownerId != null) 'ownerId': ownerId,
  };

  static NoteView fromJson(Map<String, Object?> json) => NoteView(
    id: json['id']! as int,
    text: json['text']! as String,
    ownerId: json['ownerId'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is NoteView &&
      other.id == id &&
      other.text == text &&
      other.ownerId == ownerId;

  @override
  int get hashCode => Object.hash(id, text, ownerId);

  @override
  String toString() => 'NoteView($id, $text, $ownerId)';
}

/// All notes, or the notes of [ownerId].
final class ListNotes extends DwListRequest<NoteView> {
  const ListNotes({this.ownerId});

  final int? ownerId;

  @override
  String get dwTypeName => 'ListNotes';

  @override
  Map<String, Object?> toJson() => {if (ownerId != null) 'ownerId': ownerId};

  static ListNotes fromJson(Map<String, Object?> json) =>
      ListNotes(ownerId: json['ownerId'] as int?);
}

/// Needs a signed-in account.
final class MyNotes extends DwListRequest<NoteView> {
  const MyNotes();

  @override
  String get dwTypeName => 'MyNotes';

  @override
  Map<String, Object?> toJson() => const {};

  static MyNotes fromJson(Map<String, Object?> json) => const MyNotes();
}

/// Access by check.
final class SecretNotes extends DwListRequest<NoteView> {
  const SecretNotes();

  @override
  String get dwTypeName => 'SecretNotes';

  @override
  Map<String, Object?> toJson() => const {};

  static SecretNotes fromJson(Map<String, Object?> json) => const SecretNotes();
}

final class GetNote extends DwSingleRequest<NoteView> {
  const GetNote(this.noteId);

  final int noteId;

  @override
  String get dwTypeName => 'GetNote';

  @override
  Map<String, Object?> toJson() => {'noteId': noteId};

  static GetNote fromJson(Map<String, Object?> json) =>
      GetNote(json['noteId']! as int);
}

final class FindNote extends DwMaybeRequest<NoteView> {
  const FindNote(this.noteId);

  final int noteId;

  @override
  String get dwTypeName => 'FindNote';

  @override
  Map<String, Object?> toJson() => {'noteId': noteId};

  static FindNote fromJson(Map<String, Object?> json) =>
      FindNote(json['noteId']! as int);
}

/// Offset pages of notes with [prefix], by id.
final class FeedNotes extends DwPageRequest<NoteView> {
  const FeedNotes(this.prefix);

  final String prefix;

  @override
  int get pageSize => 3;

  @override
  String get dwTypeName => 'FeedNotes';

  @override
  Map<String, Object?> toJson() => {'prefix': prefix};

  static FeedNotes fromJson(Map<String, Object?> json) =>
      FeedNotes(json['prefix']! as String);
}

/// Cursor pages of notes with [prefix], newest first.
final class NoteHistory extends DwCursorRequest<NoteView> {
  const NoteHistory(this.prefix);

  final String prefix;

  @override
  int get pageSize => 2;

  @override
  String get dwTypeName => 'NoteHistory';

  @override
  Map<String, Object?> toJson() => {'prefix': prefix};

  static NoteHistory fromJson(Map<String, Object?> json) =>
      NoteHistory(json['prefix']! as String);
}

/// A request whose handler throws with [secret] in the message.
final class ExplodingRequest extends DwListRequest<NoteView> {
  const ExplodingRequest(this.secret);

  final String secret;

  @override
  String get dwTypeName => 'ExplodingRequest';

  @override
  Map<String, Object?> toJson() => {'secret': secret};

  static ExplodingRequest fromJson(Map<String, Object?> json) =>
      ExplodingRequest(json['secret']! as String);
}

/// Waits [millis] and answers.
final class SlowRequest extends DwListRequest<NoteView> {
  const SlowRequest(this.millis);

  final int millis;

  @override
  String get dwTypeName => 'SlowRequest';

  @override
  Map<String, Object?> toJson() => {'millis': millis};

  static SlowRequest fromJson(Map<String, Object?> json) =>
      SlowRequest(json['millis']! as int);
}

/// Without a handler; registered only by the startup test's protocol.
final class OrphanRequest extends DwListRequest<NoteView> {
  const OrphanRequest();

  @override
  String get dwTypeName => 'OrphanRequest';

  @override
  Map<String, Object?> toJson() => const {};

  static OrphanRequest fromJson(Map<String, Object?> json) =>
      const OrphanRequest();
}

/// Without a handler, like [OrphanRequest].
final class OrphanCommand extends DwCommand<void> {
  const OrphanCommand();

  @override
  String get dwTypeName => 'OrphanCommand';

  @override
  Map<String, Object?> toJson() => const {};

  static OrphanCommand fromJson(Map<String, Object?> json) =>
      const OrphanCommand();
}

/// Revokes every session of [accountId] through `ctx.accounts`, then ends as
/// [ending]: `ok` or `refuse` (rolling the revocation back).
final class RevokeSessions extends DwCommand<void> {
  const RevokeSessions(this.accountId, {this.ending = 'ok'});

  final int accountId;
  final String ending;

  @override
  String get dwTypeName => 'RevokeSessions';

  @override
  Map<String, Object?> toJson() => {'accountId': accountId, 'ending': ending};

  static RevokeSessions fromJson(Map<String, Object?> json) => RevokeSessions(
    json['accountId']! as int,
    ending: json['ending']! as String,
  );
}

/// `ctx.accounts.ensure` for an e-mail, answering the account id.
final class EnsureAccount extends DwCommand<int> {
  const EnsureAccount(this.email);

  final String email;

  @override
  String get dwTypeName => 'EnsureAccount';

  @override
  Map<String, Object?> toJson() => {'email': email};

  static EnsureAccount fromJson(Map<String, Object?> json) =>
      EnsureAccount(json['email']! as String);
}

/// Not registered in the protocol at all.
final class UnregisteredRequest extends DwListRequest<NoteView> {
  const UnregisteredRequest();

  @override
  String get dwTypeName => 'UnregisteredRequest';

  @override
  Map<String, Object?> toJson() => const {};
}

/// Creates a note owned by the caller and publishes it to `notes`, and to
/// `account:<owner>`.
final class CreateNote extends DwCommand<NoteView> implements DwValidatable {
  const CreateNote(this.text, {this.extraPublishes = 0});

  final String text;

  /// Publishes the same note this many more times (collapse test).
  final int extraPublishes;

  @override
  List<DwRefusal> validate() => [
    if (text.isEmpty) DwRefusal(DwCoreRefusal.invalid, field: 'text'),
    if (text.length > 50)
      DwRefusal(DwCoreRefusal.invalid, field: 'text', params: {'max': 50}),
  ];

  @override
  String get dwTypeName => 'CreateNote';

  @override
  Map<String, Object?> toJson() => {
    'text': text,
    if (extraPublishes != 0) 'extraPublishes': extraPublishes,
  };

  static CreateNote fromJson(Map<String, Object?> json) => CreateNote(
    json['text']! as String,
    extraPublishes: (json['extraPublishes'] as int?) ?? 0,
  );
}

/// Publishes a note to `notes`, then ends as [ending].
final class PublishAndEnd extends DwCommand<void> {
  const PublishAndEnd(this.ending, {this.transactional = true});

  /// `refuse`, `fail`, or `commitThenFail` (non-transactional: publishes in a
  /// committed `ctx.transaction`, then throws).
  final String ending;
  final bool transactional;

  @override
  String get dwTypeName => 'PublishAndEnd';

  @override
  Map<String, Object?> toJson() => {
    'ending': ending,
    if (!transactional) 'transactional': false,
  };

  static PublishAndEnd fromJson(Map<String, Object?> json) => PublishAndEnd(
    json['ending']! as String,
    transactional: json['transactional'] as bool? ?? true,
  );
}

/// Counts executions of [label] in the `counter` table and returns the count.
/// `mode`: `ok`, `refuse`, `failOnce` (fails the first execution).
final class Count extends DwCommand<int> {
  const Count(this.label, {this.mode = 'ok'});

  final String label;
  final String mode;

  @override
  String get dwTypeName => 'Count';

  @override
  Map<String, Object?> toJson() => {'label': label, 'mode': mode};

  static Count fromJson(Map<String, Object?> json) =>
      Count(json['label']! as String, mode: json['mode']! as String);
}

/// Like [Count], as a non-transactional command.
final class CountOutside extends DwCommand<int> {
  const CountOutside(this.label);

  final String label;

  @override
  String get dwTypeName => 'CountOutside';

  @override
  Map<String, Object?> toJson() => {'label': label};

  static CountOutside fromJson(Map<String, Object?> json) =>
      CountOutside(json['label']! as String);
}

/// Another command type, for key reuse across types.
final class Ping extends DwCommand<String> {
  const Ping();

  @override
  String get dwTypeName => 'Ping';

  @override
  Map<String, Object?> toJson() => const {};

  static Ping fromJson(Map<String, Object?> json) => const Ping();
}

/// Anonymous access, but the handler requires an account.
final class NeedsAccount extends DwCommand<int> {
  const NeedsAccount();

  @override
  String get dwTypeName => 'NeedsAccount';

  @override
  Map<String, Object?> toJson() => const {};

  static NeedsAccount fromJson(Map<String, Object?> json) =>
      const NeedsAccount();
}

/// Revokes [accountId]'s subscription to `notes`.
final class RevokeNotes extends DwCommand<void> {
  const RevokeNotes(this.accountId);

  final int accountId;

  @override
  String get dwTypeName => 'RevokeNotes';

  @override
  Map<String, Object?> toJson() => {'accountId': accountId};

  static RevokeNotes fromJson(Map<String, Object?> json) =>
      RevokeNotes(json['accountId']! as int);
}

/// Enqueues job [name] with {'tag': tag}; refuses afterwards when [refuse].
final class EnqueueJob extends DwCommand<bool> {
  const EnqueueJob(
    this.name,
    this.tag, {
    this.key,
    this.refuse = false,
    this.delayMillis,
  });

  final String name;
  final String tag;
  final String? key;
  final bool refuse;
  final int? delayMillis;

  @override
  String get dwTypeName => 'EnqueueJob';

  @override
  Map<String, Object?> toJson() => {
    'name': name,
    'tag': tag,
    if (key != null) 'key': key,
    if (refuse) 'refuse': true,
    if (delayMillis != null) 'delayMillis': delayMillis,
  };

  static EnqueueJob fromJson(Map<String, Object?> json) => EnqueueJob(
    json['name']! as String,
    json['tag']! as String,
    key: json['key'] as String?,
    refuse: json['refuse'] == true,
    delayMillis: json['delayMillis'] as int?,
  );
}

/// Publishes [count] notes of [size] characters to `public`.
final class Burst extends DwCommand<void> {
  const Burst(this.count, this.size);

  final int count;
  final int size;

  @override
  String get dwTypeName => 'Burst';

  @override
  Map<String, Object?> toJson() => {'count': count, 'size': size};

  static Burst fromJson(Map<String, Object?> json) =>
      Burst(json['count']! as int, json['size']! as int);
}

/// All notes, live on the `notes` channel.
final class LiveNotes extends DwListRequest<NoteView> {
  const LiveNotes();

  @override
  List<DwChannel> get channels => const [DwChannel(TestChannel.notes)];

  @override
  String get dwTypeName => 'LiveNotes';

  @override
  Map<String, Object?> toJson() => const {};

  static LiveNotes fromJson(Map<String, Object?> json) => const LiveNotes();

  @override
  bool operator ==(Object other) => other is LiveNotes;

  @override
  int get hashCode => (LiveNotes).hashCode;
}

final DwProtocol testProtocol = DwProtocol([
  DwDtoEntry(LiveNotes, 'LiveNotes', LiveNotes.fromJson),
  DwDtoEntry(NoteView, 'NoteView', NoteView.fromJson),
  DwDtoEntry(ListNotes, 'ListNotes', ListNotes.fromJson),
  DwDtoEntry(MyNotes, 'MyNotes', MyNotes.fromJson),
  DwDtoEntry(SecretNotes, 'SecretNotes', SecretNotes.fromJson),
  DwDtoEntry(GetNote, 'GetNote', GetNote.fromJson),
  DwDtoEntry(FindNote, 'FindNote', FindNote.fromJson),
  DwDtoEntry(FeedNotes, 'FeedNotes', FeedNotes.fromJson),
  DwDtoEntry(NoteHistory, 'NoteHistory', NoteHistory.fromJson),
  DwDtoEntry(ExplodingRequest, 'ExplodingRequest', ExplodingRequest.fromJson),
  DwDtoEntry(SlowRequest, 'SlowRequest', SlowRequest.fromJson),
  DwDtoEntry(RevokeSessions, 'RevokeSessions', RevokeSessions.fromJson),
  DwDtoEntry(EnsureAccount, 'EnsureAccount', EnsureAccount.fromJson),
  DwDtoEntry(CreateNote, 'CreateNote', CreateNote.fromJson),
  DwDtoEntry(PublishAndEnd, 'PublishAndEnd', PublishAndEnd.fromJson),
  DwDtoEntry(Count, 'Count', Count.fromJson),
  DwDtoEntry(CountOutside, 'CountOutside', CountOutside.fromJson),
  DwDtoEntry(Ping, 'Ping', Ping.fromJson),
  DwDtoEntry(NeedsAccount, 'NeedsAccount', NeedsAccount.fromJson),
  DwDtoEntry(RevokeNotes, 'RevokeNotes', RevokeNotes.fromJson),
  DwDtoEntry(EnqueueJob, 'EnqueueJob', EnqueueJob.fromJson),
  DwDtoEntry(Burst, 'Burst', Burst.fromJson),
], include: DwProtocol.core);
