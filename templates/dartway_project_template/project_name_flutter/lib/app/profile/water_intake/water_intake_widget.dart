import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:project_name_flutter/core/app_backend_filters.dart';
import 'package:project_name_flutter/core/user_profile_provider.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

class WaterIntakeWidget extends ConsumerWidget {
  const WaterIntakeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watchModelList<WaterIntake>(
            backendFilter:
                AppBackendFilters.userWaterIntake(ref.watchUserProfile.id!))
        .dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (waterIntakes) {
            return Column(
              children: [
                AppText.title('Water Intake'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    waterIntakes.length,
                    (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () {
                            ref.deleteModel(waterIntakes[index]);
                          },
                          child: const Icon(Icons.local_drink,
                              color: Colors.blue, size: 32),
                        )),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Glass'),
                  onPressed: () {
                    ref.saveModel(
                      WaterIntake(
                        userProfileId: ref.watchUserProfile.id!,
                        intakeAmount: 200,
                        intakeTime: DateTime.now(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
  }
}
