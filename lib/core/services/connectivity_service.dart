import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Stream<bool> watchIsOnline() async* {
    yield await _isCurrentlyOnline();

    yield* _connectivity.onConnectivityChanged.map((results) {
      return _hasConnection(results);
    }).distinct();
  }

  Future<bool> _isCurrentlyOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
