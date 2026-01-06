import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jmart_sdk/src/pages/authentication/signup.dart';
import 'package:jmart_sdk/src/pages/forgot_password/forgot_password.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/services/api_services.dart';
import '../../shared/utils/toast_utils.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_textfield.dart';
import '../categories/home_category.dart';
import '../support/support.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    clearGuest();
  }

  Future<void> clearGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest');
  }


  void _onForgotPassword() {
    // if (isLoading) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('Forgot Password tapped')),
    // );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );

  }

  void _onSignUp() {
    if (isLoading) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  String _humanizeError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map &&
          data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        return (data['message'] as String).trim();
      }
      return (e.message ?? 'Network error').toString();
    }
    final s = e.toString();
    return s
        .replaceFirst(RegExp(r'^\s*\w*Exception:\s*'), '')
        .replaceFirst(RegExp(r'^\s*Error:\s*'), '')
        .trim();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final username = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    final apiService = ApiService();

    setState(() => isLoading = true);

    try {
      final postData = {'email': username, 'password': pass};
      final response =
      await apiService.post(ApiConstants.loginUrl, data: postData);

      if (response != null && response.statusCode == 200) {
        final responseMap = response.data;
        if (responseMap['status'] == true) {
          final user = responseMap['user'];
          await saveUserSession(user);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeCategoriesScreen()),
          );
        } else {
          if (!mounted) return;
          ToastUtil.showCustomBottomSheet(
            context,
            responseMap['message'] ?? 'Login failed.',
          );
        }
      } else {
        if (!mounted) return;
        ToastUtil.showCustomBottomSheet(
          context,
          response?.data?['message'] ??
              'Something went wrong with the response.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ToastUtil.showCustomBottomSheet(context, _humanizeError(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
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
    final theme = Theme.of(context);
    const double maxCardWidth = 420;

    return Scaffold(
      backgroundColor: const Color(0xFFFBC02D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxCardWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Welcome Back',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Card
                  Card(
                    color: Colors.grey.shade100,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email
                            CustomTextField(
                              controller: _emailCtrl,
                              labelText: 'Email',
                              hintText: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.email_outlined),
                              enabled: !isLoading, // disable while loading
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(v.trim())) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            CustomTextField(
                              controller: _passwordCtrl,
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              obscureText: _obscure,
                              prefixIcon: const Icon(Icons.lock_outline),
                              enabled: !isLoading,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'Minimum 6 characters';
                                }
                                return null;
                              },
                            ),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLoading ? null : _onForgotPassword,
                                child: const Text(
                                  'Forgot password?',
                                  style:
                                  TextStyle(color: Color(0xFFFBC02D)),
                                ),
                              ),
                            ),

                            CustomButton(
                              text: 'Login',
                              onPressed: isLoading ? null : _login,
                              isLoading: isLoading,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Sign up row
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Sign up',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = isLoading ? null : _onSignUp,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black87,
        child: const Icon(Icons.support_agent_sharp,size: 35, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          );
        },
      ),

    );
  }
}
