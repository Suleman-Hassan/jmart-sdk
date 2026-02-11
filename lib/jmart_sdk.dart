// library jmart_sdk;
//
// import 'package:flutter/material.dart';
// import 'src/main.dart';
//
// class JMartSDK {
//   static Future<void> launch(BuildContext context) async {
//     await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) => MyApp(),
//       ),
//     );
//     // await Navigator.of(context).push(
//     //   MaterialPageRoute(
//     //     fullscreenDialog: true,
//     //     builder: (context) => MyApp(),
//     //   ),
//     // );
//   }
// }

library jmart_sdk;

import 'package:flutter/material.dart';
import 'src/pages/askari_end_point/askari_end_point.dart';

class JMartSDK {
  static Future<void> launch(
      BuildContext context, {
        String? userEmail,
        String? firstName,
        String? lastName,
        String? phoneNumber,
      }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AskariEndPoint(
          userEmail: userEmail,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
        ),
      ),
    );
  }
}