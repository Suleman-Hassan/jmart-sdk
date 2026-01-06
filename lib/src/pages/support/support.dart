import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jmart_sdk/src/core/constants/api_constants.dart';
import 'package:jmart_sdk/src/pages/support/support_model.dart';
import 'package:jmart_sdk/src/shared/widgets/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../authentication/login.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const String _endpoint = ApiConstants.supportURL;
  //
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
    ),
  );

  ContactInfo? _contact;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<Map<String, String?>> getAuthTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access': prefs.getString('access_token'),
      'refresh': prefs.getString('refresh_token'),
    };
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tokens = await getAuthTokens();
      final accessToken = tokens['access'];

      final res = await _dio.get(
        _endpoint,
        options: Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final data = res.data;
      if (data is Map<String, dynamic> &&
          data['data'] is List &&
          (data['data'] as List).isNotEmpty) {
        final first = data['data'][0] as Map<String, dynamic>;
        setState(() {
          _contact = ContactInfo.fromJson(first);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'No contact details found';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;

      if (code == 401 || code == 403 || code == 404) {
        _gotoLogin();
        return;
      }

      setState(() {
        _error = _explainDioError(e);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
        _loading = false;
      });
    }
  }

  void _gotoLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _explainDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Network timeout. Please try again.';
    }
    if (e.type == DioExceptionType.badResponse) {
      final code = e.response?.statusCode;
      final msg =
          e.response?.data is Map &&
                  (e.response!.data as Map).containsKey('message')
              ? (e.response!.data['message']?.toString() ??
                  'Server responded with an error')
              : 'Server responded with an error';
      return 'Error $code: $msg';
    }
    if (e.type == DioExceptionType.unknown) {
      return 'Network error. Check your internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: Uri.encodeFull('subject=Support Request&body=Hello JMart team,'),
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Could not open email app');
  }

  Future<void> _launchCall(String? phoneRaw) async {
    final phone = _normalizeForTel(phoneRaw);
    if (phone == null) {
      _toast('Phone number unavailable');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await canLaunchUrl(uri)) {
      _toast('Can’t open dialer on this device');
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String? phoneRaw) async {
    final wa = _normalizeForWhatsApp(phoneRaw);
    if (wa == null) {
      _toast('WhatsApp number unavailable');
      return;
    }
    final uri = Uri.parse('https://wa.me/$wa');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Could not open WhatsApp');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _normalizeForTel(String? input) {
    final digits = _digits(input);
    if (digits == null) return null;

    if (digits.length == 11 && digits.startsWith('0')) {
      return '+92${digits.substring(1)}';
    }
    if (digits.startsWith('92')) {
      return '+$digits';
    }
    if ((input ?? '').trim().startsWith('+')) {
      return (input ?? '').trim();
    }
    return '+$digits';
  }

  String? _normalizeForWhatsApp(String? input) {
    final digits = _digits(input);
    if (digits == null) return null;

    if (digits.length == 11 && digits.startsWith('0')) {
      return '92${digits.substring(1)}';
    }
    if (digits.startsWith('92')) return digits;
    if ((input ?? '').trim().startsWith('+')) {
      return (input ?? '').trim().replaceAll('+', '');
    }
    return digits;
  }

  String? _digits(String? s) {
    if (s == null) return null;
    final only = s.replaceAll(RegExp(r'\D'), '');
    return only.isEmpty ? null : only;
  }

  @override
  Widget build(BuildContext context) {
    final themeYellow = const Color(0xFFFBC02D);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: themeYellow,
        title: const Text(
          'Support',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(message: _error!, onRetry: _fetchContacts)
                : _contact == null
                ? _ErrorView(
                  message: 'No contact details found',
                  onRetry: _fetchContacts,
                )
                : ListView(
                  children: [
                    const Text(
                      'How can we help you?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email Support'),
                      subtitle: Text(_contact!.email ?? '—'),
                      onTap:
                          _contact!.email == null
                              ? null
                              : () => _openEmail(_contact!.email!),
                    ),
                    const Divider(),

                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Call Us'),
                      subtitle: Text(_contact!.phone ?? '—'),
                      onTap:
                          _contact!.phone == null
                              ? null
                              : () => _launchCall(_contact!.phone),
                    ),
                    const Divider(),

                    ListTile(
                      leading: Image.asset(
                        "packages/jmart_sdk/assets/icons/whatsapp.png",
                        width: 24,
                        height: 24,
                      ),
                      title: const Text('WhatsApp'),
                      subtitle: Text(_contact!.whatsapp ?? '—'),
                      onTap:
                          _contact!.whatsapp == null
                              ? null
                              : () => _openWhatsApp(_contact!.whatsapp),
                    ),
                  ],
                ),
      ),
      floatingActionButton:
          (_contact?.whatsapp ?? '').isEmpty
              ? null
              : FloatingActionButton(
                backgroundColor: themeYellow,
                onPressed: () => _openWhatsApp(_contact!.whatsapp),
                child: Image.asset(
                  "packages/jmart_sdk/assets/icons/whatsapp.png",
                  width: 28,
                  height: 28,
                  color: Colors.white,
                ),
              ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          // ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          CustomButton(text: "Retry", onPressed: onRetry),
        ],
      ),
    );
  }
}


