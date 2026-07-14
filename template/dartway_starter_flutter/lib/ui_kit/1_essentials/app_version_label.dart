part of '../ui_kit.dart';

class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      exampleAppVersion,
      style: const TextStyle(fontSize: 8, color: Colors.blueGrey),
    );
  }
}
