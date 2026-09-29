import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_state_rules.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// One way to hold state and one way to send a command (#389): hooks for a
/// widget's own state, a `Notifier` for shared state, `dw.command` in a
/// feature's `logic/` run inside `dw.action`.
void main() {
  List<(DwCheckType, int)> judge(String rel, String content) => [
    for (final finding in DwFlutterStateInspector.judge(rel, content).findings)
      (finding.type, finding.line),
  ];

  const holder = DwCheckType.forbiddenStateHolder;
  const command = DwCheckType.forbiddenCommandCall;

  group('state holders', () {
    test('a StatefulWidget is one finding, its State and setState with it', () {
      expect(
        judge('ui_kit/1_essentials/app_field.dart', '''
class AppField extends StatefulWidget {
  const AppField({super.key});
  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  var on = false;
  @override
  Widget build(BuildContext context) =>
      Switch(value: on, onChanged: (v) => setState(() => on = v));
}
'''),
        [(holder, 1)],
      );
    });

    test('every stateful base counts, prefixed or not', () {
      expect(
        judge('app/a/a_page.dart', '''
class APage extends ConsumerStatefulWidget {}
class BPage extends StatefulHookWidget {}
class CPage extends StatefulHookConsumerWidget {}
class DPage extends widgets.StatefulWidget {}
'''),
        [(holder, 1), (holder, 2), (holder, 3), (holder, 4)],
      );
    });

    test('ChangeNotifier and ValueNotifier held as state count, subclassed, '
        'mixed in or constructed', () {
      expect(
        judge('app/cart/logic/cart_state.dart', '''
class CartState extends ChangeNotifier {}
class CartBadge with ChangeNotifier {}
class CartCount extends ValueNotifier<int> { CartCount() : super(0); }
final class CartSession {
  final selected = ValueNotifier<int?>(null);
  final open = ValueNotifier(false);
}
'''),
        [(holder, 1), (holder, 2), (holder, 3), (holder, 5), (holder, 6)],
      );
    });

    test('setState and StatefulBuilder outside a State class count', () {
      expect(
        judge('app/a/widgets/a_row.dart', '''
Widget row() => StatefulBuilder(
  builder: (context, setState) => Checkbox(
    value: false,
    onChanged: (_) => setState(() {}),
  ),
);
'''),
        [(holder, 1), (holder, 4)],
      );
    });

    test('hooks and Notifiers pass; words in comments and strings are not '
        'code', () {
      expect(
        judge('app/a/a_page.dart', r'''
/// Not a StatefulWidget: `setState(` has no place here, nor a
/// ValueNotifier<int>(0).
class APage extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = useState(false);
    final count = useValueNotifier(0);
    final text = useValueListenable(controller).text;
    // setState(() {}) is how it used to be done.
    return Text('StatefulWidget ${open.value} setState(');
  }
}

class CartController extends Notifier<int> {
  @override
  int build() => 0;
}
'''),
        isEmpty,
      );
    });

    test('the marker passes over the class it stands on, its State with it, '
        'and is counted', () {
      final judged = DwFlutterStateInspector.judge('core/router/state.dart', '''
/// The router's refresh listenable.
// dw:allow-stateful go_router listens to a Listenable
@immutable
class RouterState extends ChangeNotifier {}

// dw:allow-stateful a platform view needs a State subclass
class MapView extends StatefulWidget {
  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  void move() => setState(() {});
}

class Other extends ChangeNotifier {}
''');
      expect(
        [for (final f in judged.findings) (f.type, f.line)],
        [(holder, 16)],
      );
      expect(judged.allowances, [
        'core/router/state.dart:2 RouterState — go_router listens to a Listenable',
        'core/router/state.dart:6 MapView — a platform view needs a State subclass',
      ]);
    });

    test('a marker without a reason, or on no class, is a finding itself', () {
      final judged = DwFlutterStateInspector.judge('core/a.dart', '''
// dw:allow-stateful
class RouterState extends ChangeNotifier {}

// dw:allow-stateful stray
final x = 1;
''');
      expect(
        [for (final f in judged.findings) (f.type, f.line)],
        [(holder, 1), (holder, 2), (holder, 4)],
      );
      expect(judged.findings.first.message, contains('gives no reason'));
      expect(judged.findings.last.message, contains('allows nothing'));
      expect(judged.allowances, isEmpty);
    });
  });

  group('commands', () {
    test('dw.command in a feature\'s logic/ passes', () {
      expect(
        judge('app/invoices/invoice_card/logic/invoice_card_commands.dart', '''
abstract final class InvoiceCardCommands {
  static Future<DwCallResult<Invoice>> pay(Invoice invoice) =>
      dw.command(PayInvoice(invoiceId: invoice.id));
}
'''),
        isEmpty,
      );
      expect(
        judge('auth/logic/auth_controller.dart', '''
class AuthController extends Notifier<AuthFlow> {
  Future<DwCallResult<DwCodeTicket>> requestCode() async {
    final result = await dw.command(DwRequestCode(kind: kind, identifier: id));
    if (result case DwCallOk(:final value)) state = state.withTicket(value);
    return result;
  }
}
'''),
        isEmpty,
        reason: 'a flow controller reads a result to move the flow on',
      );
    });

    test('dw.command anywhere else fails: widgets/, the entry file, shared/, '
        'the kit', () {
      const body = 'final a = dw.command(PayInvoice(invoiceId: 1));\n';
      for (final rel in [
        'app/invoices/invoice_card/widgets/pay_button.dart',
        'app/invoices/invoice_card/invoice_card.dart',
        'shared/invoices/invoice_commands.dart',
        'ui_kit/2_frequent/pay_button.dart',
      ]) {
        expect(judge(rel, body), [(command, 1)], reason: rel);
      }
    });

    test('a command inside try/catch fails; try/finally passes', () {
      expect(
        judge('app/a/logic/a_commands.dart', '''
Future<void> save() async {
  try {
    await dw.command(SaveThing());
  } catch (e) {
    notify(e);
  }
  try {
    await ThingCommands.save();
  } on DwRefusalException {
    notify();
  }
  try {
    await dw.command(SaveThing());
  } finally {
    done();
  }
}
'''),
        [(command, 2), (command, 7)],
      );
    });

    test('a widget reading a result fails', () {
      expect(
        judge('app/a/widgets/a_row.dart', '''
Future<void> tap() async {
  final result = await dw.action((_) => ACommands.save())(context);
  if (result case DwCallOk(:final value)) show(value);
  if (result is DwCallRefused) retry();
  final value = (await ACommands.save()).valueOrThrow;
}
'''),
        [(command, 3), (command, 4), (command, 5), (command, 5)],
      );
    });

    test('a widget runs <Feature>Commands inside dw.action only', () {
      expect(
        judge('app/a/a_page.dart', '''
Widget build(BuildContext context) => Column(children: [
  AppButton.primary('Pay', onTap: dw.action((_) => InvoiceCommands.pay(i))),
  AppButton.primary('Undo', onTap: dw.action<void>(
    (_) async {
      await InvoiceCommands.undo(i);
    },
    confirmation: DwUiConfirmation('Sure?'),
  )),
  TextButton(onPressed: () => InvoiceCommands.pay(i), child: Text('Pay')),
]);
'''),
        [(command, 9)],
      );
    });
  });

  group('review cases', () {
    test('a State apart from its widget is a finding of its own', () {
      expect(
        judge('app/map/widgets/map_view_state.dart', '''
part of '../map_page.dart';

class _MapViewState extends State<MapView> {
  void move() => setState(() {});
}
'''),
        [(holder, 3)],
      );
    });

    test('a marker on a State in a part file passes it over', () {
      final judged = DwFlutterStateInspector.judge('app/map/map_state.dart', '''
// dw:allow-stateful the map SDK calls into a State subclass
class _MapViewState extends State<MapView> {
  void move() => setState(() {});
}
''');
      expect(judged.findings, isEmpty);
      expect(judged.allowances.single, contains('_MapViewState'));
    });

    test('the marker reaches past abstract and other modifiers', () {
      final judged = DwFlutterStateInspector.judge('core/a.dart', '''
// dw:allow-stateful a base the router extends
abstract class RouterBase extends ChangeNotifier {}
''');
      expect(judged.findings, isEmpty);
      expect(judged.allowances.single, contains('RouterBase'));
    });

    test('the marker is a real line comment, not text in a string or a '
        'block comment', () {
      final judged = DwFlutterStateInspector.judge(
        'core/a.dart',
        "const doc = '''\n"
            '// dw:allow-stateful not a marker\n'
            "''';\n"
            '/*\n'
            '// dw:allow-stateful not a marker either\n'
            '*/\n'
            'class RouterState extends ChangeNotifier {}\n',
      );
      expect([for (final f in judged.findings) f.line], [7]);
      expect(judged.allowances, isEmpty);
    });

    test("setState inside a flutter_hooks HookState is the hook's own", () {
      expect(
        judge('shared/use_ticker.dart', '''
class _TickerHookState extends HookState<int, _TickerHook> {
  void tick() => setState(() {});
}
'''),
        isEmpty,
      );
    });

    test("a State with no type argument is not Flutter's", () {
      expect(
        judge('app/a/logic/a_flow.dart', '''
class DraftState extends State {}
class OtherState extends ConsumerState {}
'''),
        isEmpty,
      );
    });

    test(
      'core/ may send a command and read a result: wiring with no button',
      () {
        expect(
          judge('core/push/push_token.dart', '''
Future<void> registerToken(String token) async {
  final result = await dw.command(RegisterPushToken(token: token));
  if (result case DwCallFailed()) report(result);
}
'''),
          isEmpty,
        );
      },
    );

    test('DwCallFailed read in a widget fails', () {
      expect(
        judge('app/a/widgets/a_row.dart', '''
void show(DwCallResult<int> result) {
  if (result is DwCallFailed) retry();
}
'''),
        [(command, 2)],
      );
    });

    test('only the first argument of dw.action is inside it', () {
      expect(
        judge('app/a/a_page.dart', '''
final a = dw.action(
  (_) => ACommands.save(),
  followUpIfMountedAction: (_, _) => ACommands.log(),
);
'''),
        [(command, 3)],
      );
    });

    test('lookalikes of holders pass: TextEditingValue, '
        'ValueListenableBuilder, a ValueNotifier parameter', () {
      expect(
        judge('ui_kit/1_essentials/app_field.dart', '''
class AppField extends HookWidget {
  const AppField({required this.source});
  final ValueNotifier<String> source;
  static void set(TextEditingController c, String text) =>
      c.value = TextEditingValue(text: text);
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: source,
    builder: (context, value, _) => Text(value),
  );
}
'''),
        isEmpty,
      );
    });
  });

  group('over a Flutter package', () {
    late Directory package;

    setUp(() {
      package = Directory.systemTemp.createTempSync('dw_state_rules');
      File(
        p.join(package.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: shop_flutter\n');
    });
    tearDown(() => package.deleteSync(recursive: true));

    void write(String path, String content) =>
        File(p.join(package.path, 'lib', path))
          ..createSync(recursive: true)
          ..writeAsStringSync(content);

    test('fails on both checks, prints and tallies the allowances; generated '
        'code is nobody\'s', () {
      write('app/cart/cart_page.dart', '''
class CartPage extends StatefulWidget {}
final a = dw.command(ClearCart());
''');
      write('core/router/app_router_state.dart', '''
// dw:allow-stateful the router listens to a Listenable
class AppRouterState extends ChangeNotifier {}
''');
      write(
        'l10n/app_localizations.dart',
        'class A extends StatefulWidget {}\n',
      );
      write(
        'app/cart/logic/cart.g.dart',
        'class B extends StatefulWidget {}\n',
      );

      final tally = DwCheckTally();
      final inspector = DwFlutterStateInspector(flutterPackageDir: package);
      expect(inspector.run(tally: tally), 2);
      expect(tally.counts, {holder: 1, command: 1});
      expect(tally.errors, 2);
      expect(inspector.allowances.single, contains('AppRouterState'));
      expect(
        tally.summary,
        containsAll([
          '• [ERROR] forbiddenStateHolder — 1',
          '🔓 Allowed by dw:allow-stateful — 1:',
        ]),
      );
    });

    test('a clean package passes, and the checks run only when asked for or '
        'unfiltered', () {
      write(
        'app/cart/cart_page.dart',
        'class CartPage extends HookWidget {}\n',
      );
      expect(DwFlutterStateInspector(flutterPackageDir: package).run(), 0);

      write('app/cart/widgets/row.dart', 'class R extends StatefulWidget {}\n');
      expect(
        DwFlutterStateInspector(
          flutterPackageDir: package,
          filterType: DwCheckType.forbiddenCommandCall,
        ).run(),
        0,
      );
      expect(
        DwFlutterStateInspector(
          flutterPackageDir: package,
          filterSeverity: DwCheckSeverity.warning,
        ).run(),
        0,
      );
      expect(
        DwFlutterStateInspector(
          flutterPackageDir: package,
          targetDirPath: 'lib/app/cart/widgets',
        ).run(),
        1,
      );
    });

    test('both checks are errors', () {
      expect(holder.severity, DwCheckSeverity.error);
      expect(command.severity, DwCheckSeverity.error);
    });
  });

  test(
    'comments and strings are blanked in place, interpolations with them',
    () {
      const source = r'''
final a = 'x ${b('y')} z'; // c
/* d
e */ final f = """g""";
''';
      final blank = DwFlutterStateInspector.blankCommentsAndStrings(source);
      expect(blank.length, source.length);
      expect(blank.split('\n').length, source.split('\n').length);
      expect(blank, isNot(contains('y')));
      expect(blank, isNot(contains('//')));
      expect(blank, contains('final f = """'));
    },
  );
}
