import 'package:flutter/material.dart';
import 'pages/authentication/login.dart';
// import 'pages/onboarding/onboarding.dart';
import 'pages/askari_end_point/askari_end_point.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JMart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AskariEndPoint(),
    );
  }
}


