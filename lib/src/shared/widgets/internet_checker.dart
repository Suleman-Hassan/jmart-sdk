import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'dart:async';

class InternetChecker {
  StreamSubscription<InternetConnectionStatus>? _listener;

  void startListening() {
    final checker = InternetConnectionChecker.instance;
    _listener = checker.onStatusChange.listen((status) {
      if (status == InternetConnectionStatus.connected) {
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
