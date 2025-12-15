import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../private/dw_singleton.dart';

extension DwSessionRefExtension on Ref {
  int? get watchSignedInUserId => watch(dw.sessionProvider!).signedInUserId;
  int? get readSignedInUserId => read(dw.sessionProvider!).signedInUserId;
}

extension DwSessionWidgetRefExtension on WidgetRef {
  int? get watchSignedInUserId => watch(dw.sessionProvider!).signedInUserId;
  int? get readSignedInUserId => read(dw.sessionProvider!).signedInUserId;
}
