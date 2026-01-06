library jmart_sdk;

import 'package:flutter/material.dart';
import 'src/main.dart';

class JMartSDK {
  static Future<void> launch(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MyApp(),
      ),
    );
  }
}