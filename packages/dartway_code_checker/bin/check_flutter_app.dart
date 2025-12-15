import 'package:dartway_code_checker/dartway_code_checker.dart';

void main(List<String> args) async {
  final checker = DwFlutterInspector(args);
  await checker.run();
}
