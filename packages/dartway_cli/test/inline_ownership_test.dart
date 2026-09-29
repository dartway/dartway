import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_inline_ownership.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `inlineOwnershipCheck`: ownership compared by hand after
/// `DwAccessRule.signedIn` is what `DwAccessRule.resource` answers once
/// (dartway/dartway#387). The fixtures are the shapes found in real handlers.
void main() {
  List<int> lines(String source) => [
    for (final site in DwInlineOwnershipInspector.inlineOwnershipIn(source))
      site.line,
  ];
  List<String?> helpers(String source) => [
    for (final site in DwInlineOwnershipInspector.inlineOwnershipIn(source))
      site.helper,
  ];

  group('flags', () {
    test('a signedIn command comparing the owner and refusing notFound', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.command<DeleteCheckIn, void>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final checkIn = await ctx.db.checkIns.findById(command.checkInId);
      if (checkIn == null || checkIn.userProfileId != (await ctx.profile).id) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      await ctx.db.checkIns.delete(checkIn.id!);
    },
  ),
];
'''),
        [6],
      );
    });

    test('forbidden, a local named me, and the caller on the left', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.command<EditComment, Comment>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final found = await ctx.db.comments.findById(command.commentId);
      if (found == null) ctx.refuse(DwCoreRefusal.notFound);
      if (found.authorId != me.id && !await ctx.isAdmin) {
        ctx.refuse(DwCoreRefusal.forbidden);
      }
      if (ctx.accountId != found.ownerAccountId) ctx.refuse(DwCoreRefusal.notFound);
      return found;
    },
  ),
];
'''),
        [8, 11],
      );
    });

    test(
      'null from a single handler, which the framework refuses notFound',
      () {
        expect(
          lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.single<GetDish, Dish>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final dish = await ctx.db.dishes.findById(request.dishId);
      if (dish == null || dish.userProfileId != (await ctx.profile).id) {
        return null;
      }
      return Dish.of(dish);
    },
  ),
];
'''),
          [6],
        );
      },
    );

    test('a helper of the file that a signedIn handler calls', () {
      const source = '''
final handlers = <DwCallHandler>[
  DwCallHandler.command<CompleteTask, Task>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final task = await ctx._requireOwnTask(command.taskId);
      return Task.of(task);
    },
  ),
];

extension on DwCallContext {
  Future<TaskRow> _requireOwnTask(int taskId, {DwRowLock? lock}) async {
    final task = await db.tasks.findById(taskId, lock: lock);
    if (task == null || task.userProfileId != (await profile).id) {
      refuse(DwCoreRefusal.notFound);
    }
    return task;
  }
}
''';
      expect(lines(source), [14]);
      expect(helpers(source), ['_requireOwnTask']);
    });
  });

  group('passes', () {
    test('the same check made by DwAccessRule.resource', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.command<CancelBooking, Booking>(
    access: DwAccessRule.resource<CancelBooking, BookingRow>(
      load: (ctx, command) => ctx.db.bookings.findById(command.bookingId),
      allows: (ctx, command, booking) async =>
          booking.clientProfileId == (await ctx.profile).id,
    ),
    handle: (ctx, command) async {
      final booking = ctx.accessed<BookingRow>();
      if (booking.status != BookingStatus.booked) {
        ctx.refuse(AppRefusal.bookingNotActive);
      }
      return Booking.of(booking);
    },
  ),
];
'''),
        isEmpty,
      );
    });

    test('a handler under a role rule, and a helper only it calls', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.command<EditNote, Note>(
    access: AppAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx._requireNote(command.noteId);
      if (row.authorProfileId != me.id) ctx.refuse(DwCoreRefusal.forbidden);
      return Note.of(row);
    },
  ),
  DwCallHandler.list<ListMyNotes, Note>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => [],
  ),
];

extension on DwCallContext {
  Future<NoteRow> _requireNote(int id) async {
    final row = await db.notes.findById(id);
    if (row == null || row.authorProfileId != (await profile).id) {
      refuse(DwCoreRefusal.notFound);
    }
    return row;
  }
}
'''),
        isEmpty,
      );
    });

    test('a list filtered by the caller, and comparisons that are not '
        'ownership', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.list<ListMyTasks, Task>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final me = await ctx.profile;
      return [
        for (final row in await ctx.db.tasks.find(
          where: (t) => t.userProfileId.equals(me.id!),
        ))
          Task.of(row),
      ];
    },
  ),
  DwCallHandler.command<SendMessage, Message>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final quoted = await ctx.db.messages.findById(command.replyToId);
      if (quoted == null || quoted.conversationId != command.conversationId) {
        ctx.refuse(DwCoreRefusal.notFound, field: 'replyToId');
      }
      if (quoted.senderId != command.recipientId) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      if (command.utcOffsetMinutes != me.lastKnownUtcOffsetMinutes) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      if (quoted.authorId != me.id) {
        await notify(quoted.authorId);
      }
      return Message.of(quoted);
    },
  ),
];
'''),
        isEmpty,
      );
    });

    test('null from a maybe handler is an answer, not a refusal', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.maybe<FindMyDraft, Draft>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final draft = await ctx.db.drafts.findById(request.draftId);
      if (draft == null || draft.authorId != (await ctx.profile).id) {
        return null;
      }
      return Draft.of(draft);
    },
  ),
];
'''),
        isEmpty,
      );
    });

    test('comments and strings', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.command<Touch, void>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      // if (row.userProfileId != me.id) ctx.refuse(DwCoreRefusal.notFound);
      ctx.log.info('if (row.userProfileId != me.id) refuse(notFound);');
    },
  ),
];
'''),
        isEmpty,
      );
    });
  });

  group('the inspector', () {
    late Directory root;
    late Directory server;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dw_inline_ownership');
      server = Directory(p.join(root.path, 'shop_server'))..createSync();
    });
    tearDown(() => root.deleteSync(recursive: true));

    const inline = '''
final handlers = <DwCallHandler>[
  DwCallHandler.command<PayInvoice, void>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final invoice = await ctx.db.invoices.findById(command.invoiceId);
      if (invoice == null || invoice.ownerProfileId != (await ctx.profile).id) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
    },
  ),
];
''';

    void write(String relative, String content) => (File(
      p.join(server.path, relative),
    )..parent.createSync(recursive: true)).writeAsStringSync(content);

    test(
      'judges *_handlers.dart under lib/ as a warning that does not fail',
      () {
        write('lib/src/billing/billing_handlers.dart', inline);
        write('lib/src/billing/billing_rules.dart', inline);
        write('test/billing_handlers.dart', inline);
        final tally = DwCheckTally();
        final inspector = DwInlineOwnershipInspector(serverPackageDir: server);

        expect(inspector.run(tally: tally), 0);
        expect(inspector.findings, hasLength(1));
        expect(
          inspector.findings.single,
          contains(
            p.join(
              'shop_server',
              'lib',
              'src',
              'billing',
              'billing_handlers.dart:6',
            ),
          ),
        );
        expect(inspector.findings.single, contains('DwAccessRule.resource'));
        expect(tally.counts, {DwCheckType.inlineOwnershipCheck: 1});
        expect(
          DwCheckType.inlineOwnershipCheck.severity,
          DwCheckSeverity.warning,
        );
      },
    );

    test('silent when filtered to another check', () {
      write('lib/src/billing/billing_handlers.dart', inline);
      final inspector = DwInlineOwnershipInspector(
        serverPackageDir: server,
        filterSeverity: DwCheckSeverity.error,
      );
      expect(inspector.run(), 0);
      expect(inspector.findings, isEmpty);
    });
  });
}
