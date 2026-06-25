import 'dart:io';

import 'package:flutter/foundation.dart';

class BuildInfo {
  static String backendUrl = !kIsWeb && Platform.isAndroid
      ? 'http://192.168.0.100:8080/'
      : 'http://localhost:8080/';

  static const String version = 'local';
  static const String buildNumber = '-';
  static const String flavor = 'dev';
}
