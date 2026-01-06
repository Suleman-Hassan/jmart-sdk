import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jmart_sdk/src/core/constants/api_constants.dart';
import 'package:jmart_sdk/src/shared/utils/toast_utils.dart';
import '../../shared/widgets/custom_button.dart';
import '../authentication/login.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _submit() async {

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await Dio().post(
       ApiConstants.forgotPasswordUrl,
        data: {
          "email": _emailController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
        ToastUtil.showSuccess(response.data["message"]);
      } else {
        setState(() {
          _errorMessage = response.data["message"] ?? "Unknown error";
          ToastUtil.showError(_errorMessage!);
        });
      }
    } on DioException catch (e) {
      setState(() {
        if (e.response != null) {
          _errorMessage = e.response?.data["message"] ?? "Request failed";
        } else {
          _errorMessage = "Network error, please try again";
        }
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFFBC02D),
        title: const Text("Forgot Password"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              CircleAvatar(
                radius: screenWidth * 0.2,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage("packages/jmart_sdk/assets/icons/logo.png"),
              ),
              const SizedBox(height: 50,),
              const Text(
                "Enter your email to reset password",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Email is required";
                    }
                    if (!RegExp(r"^[^@]+@[^@]+\.[^@]+").hasMatch(value)) {
                      return "Enter a valid email";
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Forgot Password',
                onPressed: _loading ? null : _submit,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
