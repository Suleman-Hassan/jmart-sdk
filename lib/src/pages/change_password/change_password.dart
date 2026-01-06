import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/utils/toast_utils.dart';
import '../../shared/widgets/custom_button.dart'; // ⬅️ use same loading button as Login
import '../authentication/login.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final _formKey = GlobalKey<FormState>();

  // ⬇️ all empty as requested
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _obOld = true;
  bool _obNew = true;
  bool _obConfirm = true;

  bool isLoading = false; // ⬅️ same pattern as Login
  bool _serverCrashed = false;
  String? _fieldErrorOld;
  String? _fieldErrorNew;
  String? _fieldErrorConfirm;

  Map<String, String>? _lastPayload;

  final _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrorOld = null;
      _fieldErrorNew = null;
      _fieldErrorConfirm = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'old_password': _oldC.text.trim(),
      'new_password': _newC.text.trim(),
      'new_password_confirm': _confirmC.text.trim(),
    };

    _lastPayload = payload;
    await _changePassword(payload);
  }

  Future<void> _changePassword(Map<String, String> body) async {
    setState(() {
      isLoading = true;
      _serverCrashed = false;
    });

    final tokens = await getAuthTokens();
    final accessToken = tokens['access'];

    try {
      final headers = Map<String, dynamic>.from(_dio.options.headers);
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final Response res = await _dio.post(
        ApiConstants.changePasswordURL,
        data: body,
        options: Options(headers: headers),
      );

      final code = res.statusCode ?? 0;

      if (code == 200) {
        _showSnack('Password changed successfully.');
        if (!mounted) return;
        Navigator.pop(context); // done
      } else if (code == 404) {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } else if (code >= 500) {
        setState(() => _serverCrashed = true);
      } else if (code == 400) {
        _handleValidationErrors(res.data);
      } else {
        _showSnack('Unexpected response: $code');
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;

      if (code == 404) {
        if (!mounted) return;
        await logout();
      } else if (code == 400) {
        _handleValidationErrors(e.response?.data);
      } else if (code != null && code >= 500) {
        setState(() => _serverCrashed = true);
      } else {
        setState(() => _serverCrashed = true);
      }
    } catch (_) {
      setState(() => _serverCrashed = true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<Map<String, String?>> getAuthTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access': prefs.getString('access_token'),
      'refresh': prefs.getString('refresh_token'),
    };
  }

  Future<void> logout() async {
    final tokens = await getAuthTokens();
    final accessToken = tokens['access'];
    final refreshToken = tokens['refresh'];

    if (accessToken == null || refreshToken == null) {
      ToastUtil.showError("Session expired. Please login again.");
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }

    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    final data = json.encode({"refresh": refreshToken});

    try {
      final dio = Dio();
      final response = await dio.request(
        ApiConstants.logoutUrl,
        options: Options(method: 'POST', headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        ToastUtil.showError('${response.statusMessage}');
      }
    } catch (e) {
      ToastUtil.showError('$e');
    }
  }

  void _handleValidationErrors(dynamic data) {
    if (data is Map) {
      setState(() {
        if (data['old_password'] != null) {
          _fieldErrorOld = _stringifyErr(data['old_password']);
        }
        if (data['new_password'] != null) {
          _fieldErrorNew = _stringifyErr(data['new_password']);
        }
        if (data['new_password_confirm'] != null) {
          _fieldErrorConfirm = _stringifyErr(data['new_password_confirm']);
        }
      });

      final nonField =
          data['non_field_errors'] ?? data['detail'] ?? data['message'];
      if (nonField != null) _showSnack(_stringifyErr(nonField));
    } else {
      _showSnack('Validation error.');
    }
  }

  String _stringifyErr(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is List) return v.map((e) => e.toString()).join('\n');
    if (v is Map) return v.values.map((e) => e.toString()).join('\n');
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_serverCrashed) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor:  Color(0xFFFBC02D),
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Change Password',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text('Please try again.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Retry',
                  onPressed:
                      (isLoading || _lastPayload == null)
                          ? null
                          : () => _changePassword(_lastPayload!),
                  isLoading: isLoading,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor:  Color(0xFFFBC02D),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Change Password',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _PasswordField(
                    controller: _oldC,
                    label: 'Old Password',
                    obscure: _obOld,
                    errorText: _fieldErrorOld,
                    onToggle:
                        isLoading
                            ? null
                            : () => setState(() => _obOld = !_obOld),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return 'Old password is required';
                      }
                      return null;
                    },
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _newC,
                    label: 'New Password',
                    obscure: _obNew,
                    errorText: _fieldErrorNew,
                    onToggle:
                        isLoading
                            ? null
                            : () => setState(() => _obNew = !_obNew),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'New password is required';
                      if (t.length < 8) return 'Minimum 8 characters';
                      return null;
                    },
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _confirmC,
                    label: 'Confirm New Password',
                    obscure: _obConfirm,
                    errorText: _fieldErrorConfirm,
                    onToggle:
                        isLoading
                            ? null
                            : () => setState(() => _obConfirm = !_obConfirm),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Please confirm the new password';
                      if (t != _newC.text.trim())
                        return 'Passwords do not match';
                      return null;
                    },
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Change Password',
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool obscure;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;
  final bool enabled;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.enabled,
    this.errorText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
        ),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}
