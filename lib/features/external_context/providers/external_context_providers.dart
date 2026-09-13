import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_share_service.dart';

final deviceShareServiceProvider = Provider<DeviceShareService>((ref) {
  final service = DeviceShareService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
