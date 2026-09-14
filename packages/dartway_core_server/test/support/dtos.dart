// DTOs of the test application, written by hand in the shape `dartway
// generate` produces (omission of absent fields, value equality).
import 'package:dartway_core_server/dartway_core_server.dart';

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
    'ownerId': ?ownerId,
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

final class MessageView extends DwDataObject {
  const MessageView({
    required this.id,
    required this.text,
    required this.sentAt,
  });

  @override
  final int id;
  final String text;
  final DateTime sentAt;

  @override
  String get dwTypeName => 'MessageView';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'sentAt': DwJsonCodec.encodeDateTime(sentAt),
  };

  static MessageView fromJson(Map<String, Object?> json) => MessageView(
    id: json['id']! as int,
    text: json['text']! as String,
    sentAt: DwJsonCodec.decodeDateTime(json['sentAt']),
  );

  @override
  bool operator ==(Object other) =>
      other is MessageView && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);

  @override
  String toString() => 'MessageView($id, $text)';
}

/// All notes, or the notes of [ownerId].
final class ListNotes extends DwListRequest<NoteView> {
  const ListNotes({this.ownerId});

  final int? ownerId;

  @override
  String get dwTypeName => 'ListNotes';

  @override
  Map<String, Object?> toJson() => {'ownerId': ?ownerId};

  static ListNotes fromJson(Map<String, Object?> json) =>
      ListNotes(ownerId: json['ownerId'] as int?);
}

/// Every note, newest first, live on `notes`: a new note goes to the head.
final class LiveNotes extends DwListRequest<NoteView> {
  const LiveNotes();

  @override
  List<DwLiveChannel> get channels => const [DwLiveChannel(TestChannel.notes)];

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

/// Needs a signed-in account.
final class MyNotes extends DwListRequest<NoteView> {
  const MyNotes();

  @override
  String get dwTypeName => 'MyNotes';

  @override
  Map<String, Object?> toJson() => const {};

  static MyNotes fromJson(Map<String, Object?> json) => const MyNotes();
}

/// The notes of [ownerId]: the owner or a staff member may read them — an
/// access check on the request's own parameter.
final class NotesOfOwner extends DwListRequest<NoteView>
    implements DwSelfValidating {
  const NotesOfOwner(this.ownerId);

  final int ownerId;

  @override
  List<DwCallRefusal> validate() => [
    if (ownerId < 1) DwCallRefusal(DwCoreRefusal.invalid, field: 'ownerId'),
  ];

  @override
  String get dwTypeName => 'NotesOfOwner';

  @override
  Map<String, Object?> toJson() => {'ownerId': ownerId};

  static NotesOfOwner fromJson(Map<String, Object?> json) =>
      NotesOfOwner(json['ownerId']! as int);
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
  bool matches(NoteView item) => item.id == noteId;

  @override
  String get dwTypeName => 'FindNote';

  @override
  Map<String, Object?> toJson() => {'noteId': noteId};

  static FindNote fromJson(Map<String, Object?> json) =>
      FindNote(json['noteId']! as int);
}

/// Offset pages of notes with [prefix], by id: 3 per page, up to 5 a call.
final class FeedNotes extends DwPageRequest<NoteView> {
  const FeedNotes(this.prefix) : super(pageSize: 3, maxPageSize: 5);

  final String prefix;

  @override
  String get dwTypeName => 'FeedNotes';

  @override
  Map<String, Object?> toJson() => {'prefix': prefix};

  static FeedNotes fromJson(Map<String, Object?> json) =>
      FeedNotes(json['prefix']! as String);
}

/// A page request whose handler ignores its fetch limit.
final class GreedyFeed extends DwPageRequest<NoteView> {
  const GreedyFeed() : super(pageSize: 2);

  @override
  String get dwTypeName => 'GreedyFeed';

  @override
  Map<String, Object?> toJson() => const {};

  static GreedyFeed fromJson(Map<String, Object?> json) => const GreedyFeed();
}

/// Numbered pages of notes with [prefix], at most 4 per page.
final class TableNotes extends DwTableRequest<NoteView> {
  const TableNotes(this.prefix, {this.page = 1, this.pageSize = 2})
    : super(maxPageSize: 4);

  final String prefix;

  @override
  final int page;

  @override
  final int pageSize;

  @override
  String get dwTypeName => 'TableNotes';

  @override
  Map<String, Object?> toJson() => {
    'prefix': prefix,
    'page': page,
    'pageSize': pageSize,
  };

  static TableNotes fromJson(Map<String, Object?> json) => TableNotes(
    json['prefix']! as String,
    page: json['page']! as int,
    pageSize: json['pageSize']! as int,
  );
}

/// The messages of [room], newest first: 4 per load, up to 10 a call.
final class ChatWindow extends DwWindowRequest<MessageView, DateTime, int> {
  const ChatWindow(this.room) : super(pageSize: 4, maxPageSize: 10);

  final String room;

  @override
  DwWindowPosition<DateTime, int> positionOf(MessageView item) =>
      (sortValue: item.sentAt, id: item.id);

  @override
  String get dwTypeName => 'ChatWindow';

  @override
  Map<String, Object?> toJson() => {'room': room};

  static ChatWindow fromJson(Map<String, Object?> json) =>
      ChatWindow(json['room']! as String);
}

/// A window over notes sorted by text: its cursors carry a String sort
/// value, not a ChatWindow's DateTime.
final class NotesByText extends DwWindowRequest<NoteView, String, int> {
  const NotesByText() : super(pageSize: 2);

  @override
  DwWindowPosition<String, int> positionOf(NoteView item) =>
      (sortValue: item.text, id: item.id);

  @override
  String get dwTypeName => 'NotesByText';

  @override
  Map<String, Object?> toJson() => const {};

  static NotesByText fromJson(Map<String, Object?> json) => const NotesByText();
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

/// A request whose handler publishes, which a read may not.
final class PublishingRequest extends DwListRequest<NoteView> {
  const PublishingRequest();

  @override
  String get dwTypeName => 'PublishingRequest';

  @override
  Map<String, Object?> toJson() => const {};

  static PublishingRequest fromJson(Map<String, Object?> json) =>
      const PublishingRequest();
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
final class OrphanCommand extends DwActionCommand<void> {
  const OrphanCommand();

  @override
  String get dwTypeName => 'OrphanCommand';

  @override
  Map<String, Object?> toJson() => const {};

  static OrphanCommand fromJson(Map<String, Object?> json) =>
      const OrphanCommand();
}

/// Not registered in the protocol at all.
final class UnregisteredRequest extends DwListRequest<NoteView> {
  const UnregisteredRequest();

  @override
  String get dwTypeName => 'UnregisteredRequest';

  @override
  Map<String, Object?> toJson() => const {};
}

/// Revokes every session of [accountId] through `ctx.accounts`, then ends as
/// [ending]: `ok` or `refuse` (rolling the revocation back).
final class RevokeSessions extends DwActionCommand<void> {
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
final class EnsureAccount extends DwActionCommand<int> {
  const EnsureAccount(this.email);

  final String email;

  @override
  String get dwTypeName => 'EnsureAccount';

  @override
  Map<String, Object?> toJson() => {'email': email};

  static EnsureAccount fromJson(Map<String, Object?> json) =>
      EnsureAccount(json['email']! as String);
}

/// Creates a note owned by the caller and publishes it to `notes`, and to
/// `account:<owner>`.
final class CreateNote extends DwActionCommand<NoteView>
    implements DwSelfValidating {
  const CreateNote(this.text, {this.extraPublishes = 0});

  final String text;

  /// Publishes the same note this many more times (collapse test).
  final int extraPublishes;

  @override
  List<DwCallRefusal> validate() => [
    if (text.isEmpty) DwCallRefusal(DwCoreRefusal.invalid, field: 'text'),
    if (text.length > 50)
      DwCallRefusal(DwCoreRefusal.invalid, field: 'text', params: {'max': 50}),
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

/// Publishes a note to `notes`, then ends as [ending]: `refuse` or `fail`.
final class PublishAndEnd extends DwActionCommand<void> {
  const PublishAndEnd(this.ending);

  final String ending;

  @override
  String get dwTypeName => 'PublishAndEnd';

  @override
  Map<String, Object?> toJson() => {'ending': ending};

  static PublishAndEnd fromJson(Map<String, Object?> json) =>
      PublishAndEnd(json['ending']! as String);
}

/// Counts executions of [label] in the `counter` table and returns the count.
/// `mode`: `ok`, `refuse`, `outdated`, `failOnce`, `conflictOnce`.
final class Count extends DwActionCommand<int> {
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

/// Like [Count], as a non-transactional command that also publishes from a
/// committed transaction; a label starting with `fail` throws afterwards.
final class CountOutside extends DwActionCommand<int> {
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
final class Ping extends DwActionCommand<String> {
  const Ping();

  @override
  String get dwTypeName => 'Ping';

  @override
  Map<String, Object?> toJson() => const {};

  static Ping fromJson(Map<String, Object?> json) => const Ping();
}

/// Anonymous access, but the handler requires an account.
final class NeedsAccount extends DwActionCommand<int> {
  const NeedsAccount();

  @override
  String get dwTypeName => 'NeedsAccount';

  @override
  Map<String, Object?> toJson() => const {};

  static NeedsAccount fromJson(Map<String, Object?> json) =>
      const NeedsAccount();
}

/// Revokes [accountId]'s subscription to `notes`, then publishes a note to
/// `notes` and to `public`.
final class RevokeNotes extends DwActionCommand<void> {
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
final class EnqueueJob extends DwActionCommand<bool> {
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
    'key': ?key,
    if (refuse) 'refuse': true,
    'delayMillis': ?delayMillis,
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
final class Burst extends DwActionCommand<void> {
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

/// A command whose handler allows only a small body.
final class SmallUpload extends DwActionCommand<int> {
  const SmallUpload(this.data);

  final String data;

  @override
  String get dwTypeName => 'SmallUpload';

  @override
  Map<String, Object?> toJson() => {'data': data};

  static SmallUpload fromJson(Map<String, Object?> json) =>
      SmallUpload(json['data']! as String);
}

/// A command whose handler allows a body over the server's limit.
final class LargeUpload extends DwActionCommand<int> {
  const LargeUpload(this.data);

  final String data;

  @override
  String get dwTypeName => 'LargeUpload';

  @override
  Map<String, Object?> toJson() => {'data': data};

  static LargeUpload fromJson(Map<String, Object?> json) =>
      LargeUpload(json['data']! as String);
}

/// Waits [millis], then creates a note with [text] and publishes it to
/// `notes`.
final class SlowNote extends DwActionCommand<NoteView> {
  const SlowNote(this.text, this.millis);

  final String text;
  final int millis;

  @override
  String get dwTypeName => 'SlowNote';

  @override
  Map<String, Object?> toJson() => {'text': text, 'millis': millis};

  static SlowNote fromJson(Map<String, Object?> json) =>
      SlowNote(json['text']! as String, json['millis']! as int);
}

final DwWireProtocol testProtocol = DwWireProtocol([
  DwProtocolEntry<NoteView>('NoteView', NoteView.fromJson),
  DwProtocolEntry<MessageView>('MessageView', MessageView.fromJson),
  DwProtocolEntry<ListNotes>('ListNotes', ListNotes.fromJson),
  DwProtocolEntry<LiveNotes>('LiveNotes', LiveNotes.fromJson),
  DwProtocolEntry<MyNotes>('MyNotes', MyNotes.fromJson),
  DwProtocolEntry<NotesOfOwner>('NotesOfOwner', NotesOfOwner.fromJson),
  DwProtocolEntry<GetNote>('GetNote', GetNote.fromJson),
  DwProtocolEntry<FindNote>('FindNote', FindNote.fromJson),
  DwProtocolEntry<FeedNotes>('FeedNotes', FeedNotes.fromJson),
  DwProtocolEntry<GreedyFeed>('GreedyFeed', GreedyFeed.fromJson),
  DwProtocolEntry<TableNotes>('TableNotes', TableNotes.fromJson),
  DwProtocolEntry<ChatWindow>('ChatWindow', ChatWindow.fromJson),
  DwProtocolEntry<NotesByText>('NotesByText', NotesByText.fromJson),
  DwProtocolEntry<ExplodingRequest>(
    'ExplodingRequest',
    ExplodingRequest.fromJson,
  ),
  DwProtocolEntry<PublishingRequest>(
    'PublishingRequest',
    PublishingRequest.fromJson,
  ),
  DwProtocolEntry<SlowRequest>('SlowRequest', SlowRequest.fromJson),
  DwProtocolEntry<RevokeSessions>('RevokeSessions', RevokeSessions.fromJson),
  DwProtocolEntry<EnsureAccount>('EnsureAccount', EnsureAccount.fromJson),
  DwProtocolEntry<CreateNote>('CreateNote', CreateNote.fromJson),
  DwProtocolEntry<PublishAndEnd>('PublishAndEnd', PublishAndEnd.fromJson),
  DwProtocolEntry<Count>('Count', Count.fromJson),
  DwProtocolEntry<CountOutside>('CountOutside', CountOutside.fromJson),
  DwProtocolEntry<Ping>('Ping', Ping.fromJson),
  DwProtocolEntry<NeedsAccount>('NeedsAccount', NeedsAccount.fromJson),
  DwProtocolEntry<RevokeNotes>('RevokeNotes', RevokeNotes.fromJson),
  DwProtocolEntry<EnqueueJob>('EnqueueJob', EnqueueJob.fromJson),
  DwProtocolEntry<Burst>('Burst', Burst.fromJson),
  DwProtocolEntry<SmallUpload>('SmallUpload', SmallUpload.fromJson),
  DwProtocolEntry<LargeUpload>('LargeUpload', LargeUpload.fromJson),
  DwProtocolEntry<SlowNote>('SlowNote', SlowNote.fromJson),
], include: DwWireProtocol.core);
