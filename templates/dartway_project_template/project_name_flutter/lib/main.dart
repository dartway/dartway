// ignore: unused_import
import 'dart:io';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:project_name_flutter/build_info.dart';
import 'package:project_name_flutter/core/app_core.dart';
import 'package:project_name_flutter/core/default_models.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

import 'core/router/router.dart';
import 'core/user_profile_provider.dart';

void main() async {
  DwApp(
    title: 'Awesome DartWay Project',
    routerProvider: appRouterProvider,
    dwConfig: const DwConfig(
      defaultModelGetter: DwRepository.getDefault,
    ),
    appWrapper: (context, child) => SignedInUserScope(
      userProfileProvider: userProfileProvider,
      child: child,
    ),
    flutterAppOptions: DwFlutterAppOptions(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 4, 49, 57),
        ),
        extensions: const [
          DwFlutterTheme(
            multiLinkText: AppText.body,
            multiLinkTextLink: AppText.link,
            primaryButton: AppButton.primary,
            secondaryButton: AppButton.secondary,
            textButton: AppButton.text,
          ),
        ],
      ),
    ),
    appInitializers: [
      (ref) async => ref.initDartwayServerpodApp<UserProfile>(
            client: AppCore.initServerpodClient(
              BuildInfo.backendUrl,
            ),
            initRepositoryFunction: DefaultModels.initRepository,
          ),
    ],
  ).run();
}
