import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/services/api_services.dart';
import '../../shared/utils/toast_utils.dart';
import '../categories/home_category.dart';

class AskariEndPoint extends StatefulWidget {
  const AskariEndPoint({super.key});

  @override
  State<AskariEndPoint> createState() => _AskariEndPointState();
}

class _AskariEndPointState extends State<AskariEndPoint> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _login();
  }

  String _humanizeError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map &&
          data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        return (data['message'] as String).trim();
      }
      return e.message ?? 'Network error';
    }
    return e.toString();
  }

  Future<void> _login() async {
    final username = "guest@gmail.com";
    final pass = "Pakistan@123";
    final apiService = ApiService();

    setState(() => isLoading = true);

    try {
      final postData = {
        'email': username,
        'password': pass,
      };

      final response =
      await apiService.post(ApiConstants.loginUrl, data: postData);

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final responseMap = response.data;

        if (responseMap['status'] == true) {
          await saveUserSession(responseMap['user']);

          setState(() => isLoading = false);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeCategoriesScreen(),
            ),
          );
        } else {
          setState(() => isLoading = false);
          ToastUtil.showCustomBottomSheet(
            context,
            responseMap['message'] ?? 'Login failed',
          );
        }
      } else {
        setState(() => isLoading = false);
        ToastUtil.showCustomBottomSheet(
          context,
          'Invalid server response',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ToastUtil.showCustomBottomSheet(context, _humanizeError(e));
    }
  }

  Future<void> saveUserSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final tokens = user['tokens'];

    await prefs.setString('access_token', tokens['access']);
    await prefs.setString('refresh_token', tokens['refresh']);
    await prefs.setString('user_id', user['id'].toString());
    await prefs.setString('user_email', user['email']);
    await prefs.setString('user_name', user['full_name']);
    await prefs.setString('user_role', user['role']);
    await prefs.setString('user_phone', user['phone_number'] ?? '');
    await prefs.setString('user_status', user['status']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: isLoading
            ? Transform.scale(
          scale: 1.2,
          child: const CircularProgressIndicator(
            color: Color(0xFFFBC02D),
            strokeWidth: 6,
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}
