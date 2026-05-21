import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'dart:async';

class InternetChecker {
  StreamSubscription<InternetStatus>? _listener;

  void startListening() {
    _listener = InternetConnection().onStatusChange.listen((status) {
      if (status == InternetStatus.connected) {
        print("✅ Internet is connected.");
      } else {
        print("❌ No internet connection.");
      }
    });
  }

  void stopListening() {
    _listener?.cancel();
  }
}