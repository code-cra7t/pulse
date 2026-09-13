import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/user_settings_providers.dart';
import '../data/automation_policy.dart';
import '../models/automation_preferences.dart';

final automationPolicyProvider = Provider<AutomationPolicy>((ref) {
  return const AutomationPolicy();
});

final automationPreferencesProvider = Provider<AutomationPreferences>((ref) {
  final settings = ref.watch(currentUserSettingsProvider).asData?.value;
  return settings?.automationPreferences ?? AutomationPreferences.defaults();
});
