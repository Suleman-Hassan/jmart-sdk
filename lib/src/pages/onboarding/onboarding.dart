import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jmart_sdk/src/core/constants/api_constants.dart';
import 'package:jmart_sdk/src/pages/splash/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  @override
  void initState() {
    super.initState();
    _hitApi();
  }

  Future<void> _hitApi() async {
    try {
      final response = await Dio().get(ApiConstants.splashUrl);

      if (response.statusCode == 200) {
        final respData = response.data;

        String? isDeleted = respData["data"]?["isdeleted"];

        if (isDeleted != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("isDeleted", isDeleted);
        }

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
        );
      }
    } on DioException catch (e) {
      debugPrint("API Error: ${e.response?.data ?? e.message}");
    } catch (e) {
      debugPrint("Unexpected Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          "",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
