import 'package:dartway_code_checker/dartway_code_checker.dart';

void main(List<String> args) async {
  final stat = DwFlutterStat(args);
  await stat.run();
}
