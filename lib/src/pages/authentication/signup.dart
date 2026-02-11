import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/utils/toast_utils.dart';
import '../../shared/widgets/cnic_formatter.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_textfield.dart';
import 'login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cnicCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onSignUp() {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _register();
  }

  void _onLoginTap() {
    if (_isLoading) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void customPrompt(String message) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.all(24),
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'packages/jmart_sdk/assets/icons/success.png',
                    height: 120,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _onLoginTap();
                      },
                      child: const Text(
                        'Ok',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

  Future<void> _pickImage() async {
    if (_isLoading) return; // 🔒 no picking during submit

    final status = await Permission.camera.request();
    final galleryStatus = await Permission.photos.request();

    // If you want to enforce permissions, uncomment:
    // if (status.isDenied || galleryStatus.isDenied) {
    //   ToastUtil.showCustomBottomSheet(
    //     context,
    //     "Permissions are required to select an image",
    //   );
    //   return;
    // }

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    setState(() => _selectedImage = File(pickedFile.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    setState(() => _selectedImage = File(pickedFile.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _register() async {
    try {
      setState(() => _isLoading = true);

      final dio = Dio();

      MultipartFile? imageMultipart;
      if (_selectedImage != null) {
        imageMultipart = await MultipartFile.fromFile(
          _selectedImage!.path,
          filename: _selectedImage!.path.split('/').last,
        );
      }

      final formData = FormData.fromMap({
        'username': _emailCtrl.text,
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'password_confirm': _confirmPasswordCtrl.text,
        'first_name': _nameCtrl.text,
        'last_name': _lastNameCtrl.text,
        'phone_number': _phoneCtrl.text.trim(),
        'cnic': _cnicCtrl.text.replaceAll('-', ''),
        if (imageMultipart != null) 'profile_picture': imageMultipart,
      });

      final response = await dio.post(ApiConstants.registerUrl, data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['status'] == true) {
          customPrompt(responseData['message'] ?? 'Registration successful!');
        } else {
          ToastUtil.showCustomBottomSheet(
            context,
            responseData['message'] ?? 'Registration failed',
          );
        }
      } else {
        ToastUtil.showCustomBottomSheet(
          context,
          "${response.statusMessage ?? 'Unknown error'}",
        );
      }
    } on DioException catch (e) {
      final msg = _humanizeError(e);
      ToastUtil.showCustomBottomSheet(context, "$msg");
    } catch (e) {
      ToastUtil.showCustomBottomSheet(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double maxCardWidth = 480;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFBC02D),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxCardWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Create Account',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to get started',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        color: Colors.grey.shade100,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Avatar picker (disabled while loading)
                                GestureDetector(
                                  onTap: _isLoading ? null : _pickImage,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: _selectedImage != null
                                        ? FileImage(_selectedImage!)
                                        : null,
                                    child: _selectedImage == null
                                        ? const Icon(
                                            Icons.camera_alt,
                                            size: 40,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // First name
                                CustomTextField(
                                  controller: _nameCtrl,
                                  labelText: 'First Name',
                                  hintText: 'e.g. test',
                                  keyboardType: TextInputType.name,
                                  prefixIcon: const Icon(Icons.person_outline),
                                  enabled: !_isLoading,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'First name is required';
                                    }
                                    if (v.trim().length < 3) {
                                      return 'Enter a valid first name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Last Name
                                CustomTextField(
                                  controller: _lastNameCtrl,
                                  labelText: 'Last Name',
                                  hintText: 'e.g. test',
                                  keyboardType: TextInputType.name,
                                  prefixIcon: const Icon(Icons.person_outline),
                                  enabled: !_isLoading,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Last name is required';
                                    }
                                    if (v.trim().length < 3) {
                                      return 'Enter a valid last name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // CNIC
                                CustomTextField(
                                  controller: _cnicCtrl,
                                  labelText: 'CNIC',
                                  hintText: '35202-1234567-1',
                                  keyboardType: TextInputType.number,
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  inputFormatters: [CNICInputFormatter()],
                                  enabled: !_isLoading,
                                  validator: (v) {
                                    final text = (v ?? '').trim();
                                    final reg = RegExp(r'^\d{5}-\d{7}-\d{1}$');
                                    if (text.isEmpty) return 'CNIC is required';
                                    if (!reg.hasMatch(text)) {
                                      return 'Format: 35202-1234567-1';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Email
                                CustomTextField(
                                  controller: _emailCtrl,
                                  labelText: 'Email',
                                  hintText: 'you@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  enabled: !_isLoading,
                                  validator: (v) {
                                    final text = (v ?? '').trim();
                                    if (text.isEmpty)
                                      return 'Email is required';
                                    final emailRegex = RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$',
                                    );
                                    if (!emailRegex.hasMatch(text)) {
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
                                  hintText: 'Enter password',
                                  keyboardType: TextInputType.visiblePassword,
                                  obscureText: _obscure,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  enabled: !_isLoading,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : () => setState(() {
                                            _obscure = !_obscure;
                                          }),
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
                                const SizedBox(height: 16),

                                // Confirm Password
                                CustomTextField(
                                  controller: _confirmPasswordCtrl,
                                  labelText: 'Confirm Password',
                                  hintText: 'Re-enter password',
                                  keyboardType: TextInputType.visiblePassword,
                                  obscureText: _obscure,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  enabled: !_isLoading,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Confirm password is required';
                                    }
                                    if (v != _passwordCtrl.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Phone
                                CustomTextField(
                                  controller: _phoneCtrl,
                                  labelText: 'Mobile Number',
                                  hintText: '03XXXXXXXXX',
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  enabled: !_isLoading,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  validator: (v) {
                                    final text = (v ?? '').trim();
                                    if (text.isEmpty) {
                                      return 'Mobile number is required';
                                    }
                                    final pk1 = RegExp(r'^03\d{9}$');
                                    final pk2 = RegExp(r'^\+92\d{10}$');
                                    if (!(pk1.hasMatch(text) ||
                                        pk2.hasMatch(text))) {
                                      return 'Enter a valid Pakistani number';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 30),

                                // 🔥 Same inline loader as Login
                                CustomButton(
                                  onPressed: _isLoading ? null : _onSignUp,
                                  text: 'Sign Up',
                                  isLoading: _isLoading,
                                ),

                                const SizedBox(height: 20),
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text: 'Already have an account? ',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.black87,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Login',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = _isLoading
                                              ? null
                                              : _onLoginTap,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
