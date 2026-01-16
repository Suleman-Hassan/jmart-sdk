import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class AskariEndPoint extends StatefulWidget {
  const AskariEndPoint({super.key});

  @override
  State<AskariEndPoint> createState() => _AskariEndPointState();
}

class _AskariEndPointState extends State<AskariEndPoint> {
  @override
  // Widget build(BuildContext context) {
  //   return const Scaffold(
  //     body: Center(
  //       child: CircularProgressIndicator(color: const Color(0xFFFBC02D)),
  //     ),
  //   );
  // }
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Transform.scale(
          scale: 1.5,
          child: const CircularProgressIndicator(color: Color(0xFFFBC02D)),
        ),
      ),
    );
  }
}
