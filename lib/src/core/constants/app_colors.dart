import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0052CC);
  static const Color secondary = Color(0xFF36B37E);
  static const Color alertBg = Color(0xFF487ACE);
  static const Color background = Color(0xEBEDF6FF);
  static const Color text = Color(0xFF172B4D);
  static const Color error = Colors.red;
  static const Color success = Colors.green;
  static const Color white = Colors.white;
  static const Color grey = Colors.grey;

  // Linear Gradient for Primary Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0052CC),  // Primary Blue
      Color(0xFF36B37E),  // Secondary Green
    ],
  );

  // Radial Gradient for Soft Background
  static const RadialGradient backgroundGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.8,
    colors: [
      Color(0xEBEDF6FF),  // Light background color
      Color(0xA8D5BAFF),  // Light Greenish background
    ],
  );

  // Dark Green Gradient
  static const LinearGradient darkGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1F3B2DFF), // Dark green color
      Color(0xA8D5BAFF),  // Lighter green color
    ],
  );

}
