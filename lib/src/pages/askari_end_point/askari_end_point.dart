// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:dio/dio.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../core/constants/api_constants.dart';
// import '../../shared/services/api_services.dart';
// import '../../shared/utils/toast_utils.dart';
// import '../categories/home_category.dart';
//
// class AskariEndPoint extends StatefulWidget {
//   const AskariEndPoint({super.key});
//
//   @override
//   State<AskariEndPoint> createState() => _AskariEndPointState();
// }
//
// class _AskariEndPointState extends State<AskariEndPoint> {
//   bool isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     // _login();
//     // WidgetsBinding.instance.addPostFrameCallback((_) {
//     //   _showLoginDialog();
//     // });
//     getEmail();
//   }
//
//   void getEmail() async {
//     bool? exists = await checkEmailExists('test8@gmail.com');
//
//     if (exists == true) {
//       print('Email already exists');
//     } else if (exists == false) {
//       print('Email available');
//     } else {
//       print('Error checking email');
//     }
//   }
//
//   Future<bool?> checkEmailExists(String email) async {
//     try {
//       setState(() => isLoading = true);
//       var dio = Dio();
//
//       var data = FormData.fromMap({'email': email});
//
//       var response = await dio.request(
//         'http://192.168.100.90:1234/api/v1/auth/check-email/',
//         options: Options(method: 'GET', contentType: 'multipart/form-data'),
//         data: data,
//       );
//
//       if (response.statusCode == 200) {
//         print(json.encode(response.data));
//         bool exists = response.data['data']['exists'] ?? false;
//         print('Email exists: $exists');
//         if (exists == false) {
//           _showLoginDialog();
//         }
//         return exists;
//       }
//
//       return null;
//     } on DioException catch (e) {
//       if (e.response != null) {
//         print('Error: ${e.response?.statusCode}');
//         print('Message: ${e.response?.data}');
//       } else {
//         print('Error: ${e.message}');
//         print('Type: ${e.type}');
//       }
//       return null;
//     } catch (e) {
//       print('Unexpected error: $e');
//       return null;
//     }finally{
//       setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> _register() async {
//     try {
//       // setState(() => _isLoading = true);
//
//       final dio = Dio();
//       //
//       // MultipartFile? imageMultipart;
//       // if (_selectedImage != null) {
//       //   imageMultipart = await MultipartFile.fromFile(
//       //     _selectedImage!.path,
//       //     filename: _selectedImage!.path.split('/').last,
//       //   );
//       // }
//
//       final formData = FormData.fromMap({
//         'username': "",
//         'email': "",
//         'password': "",
//         'password_confirm': "",
//         'first_name': "",
//         'last_name': "",
//         'phone_number': "",
//         'cnic': "",
//         //  if (imageMultipart != null) 'profile_picture': imageMultipart,
//       });
//
//       final response = await dio.post(ApiConstants.registerUrl, data: formData);
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final responseData = response.data;
//         if (responseData['status'] == true) {
//           //  customPrompt(responseData['message'] ?? 'Registration successful!');
//         } else {
//           ToastUtil.showCustomBottomSheet(
//             context,
//             responseData['message'] ?? 'Registration failed',
//           );
//         }
//       } else {
//         ToastUtil.showCustomBottomSheet(
//           context,
//           "${response.statusMessage ?? 'Unknown error'}",
//         );
//       }
//     } on DioException catch (e) {
//       final msg = _humanizeError(e);
//       ToastUtil.showCustomBottomSheet(context, "$msg");
//     } catch (e) {
//       ToastUtil.showCustomBottomSheet(context, e.toString());
//     } finally {
//       //  if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   void _showLoginDialog() {
//     final emailController = TextEditingController(text: "guest@gmail.com");
//     final passwordController = TextEditingController(text: "Pakistan@123");
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return Dialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // 🔵 Icon
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.blue.withOpacity(0.1),
//                       ),
//                       child: const Icon(
//                         Icons.lock_outline,
//                         size: 40,
//                         color: Color(0xFFFBC02D),
//                       ),
//                     ),
//
//                     const SizedBox(height: 12),
//
//                     const Text(
//                       "Complete your profile",
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//
//                     const SizedBox(height: 6),
//
//                     const Text(
//                       "Please confirm your credentials",
//                       style: TextStyle(color: Colors.grey),
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     // 📧 Email
//                     TextField(
//                       controller: emailController,
//                       decoration: InputDecoration(
//                         labelText: "Email",
//                         prefixIcon: const Icon(Icons.email),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 12),
//
//                     // 🔒 Password
//                     TextField(
//                       controller: passwordController,
//                       obscureText: true,
//                       decoration: InputDecoration(
//                         labelText: "Password",
//                         prefixIcon: const Icon(Icons.lock),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 24),
//
//                     // Login Button
//                     SizedBox(
//                       width: double.infinity,
//                       height: 48,
//                       child: ElevatedButton(
//                         onPressed: isLoading
//                             ? null
//                             : () async {
//                                 Navigator.pop(context);
//                                 await _login();
//                               },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Color(0xFFFBC02D),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                         ),
//                         child: isLoading
//                             ? const CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2,
//                               )
//                             : const Text(
//                                 "Complete",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   String _humanizeError(Object e) {
//     if (e is DioException) {
//       final data = e.response?.data;
//       if (data is Map &&
//           data['message'] is String &&
//           (data['message'] as String).trim().isNotEmpty) {
//         return (data['message'] as String).trim();
//       }
//       return e.message ?? 'Network error';
//     }
//     return e.toString();
//   }
//
//   Future<void> _login() async {
//     final username = "guest@gmail.com";
//     final pass = "Pakistan@123";
//     final apiService = ApiService();
//
//     setState(() => isLoading = true);
//
//     try {
//       final postData = {'email': username, 'password': pass};
//
//       final response = await apiService.post(
//         ApiConstants.loginUrl,
//         data: postData,
//       );
//
//       if (!mounted) return;
//
//       if (response != null && response.statusCode == 200) {
//         final responseMap = response.data;
//
//         if (responseMap['status'] == true) {
//           await saveUserSession(responseMap['user']);
//
//           setState(() => isLoading = false);
//
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const HomeCategoriesScreen()),
//           );
//         } else {
//           setState(() => isLoading = false);
//           ToastUtil.showCustomBottomSheet(
//             context,
//             responseMap['message'] ?? 'Login failed',
//           );
//         }
//       } else {
//         setState(() => isLoading = false);
//         ToastUtil.showCustomBottomSheet(context, 'Invalid server response');
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => isLoading = false);
//       ToastUtil.showCustomBottomSheet(context, _humanizeError(e));
//     }
//   }
//
//   Future<void> saveUserSession(Map<String, dynamic> user) async {
//     final prefs = await SharedPreferences.getInstance();
//     final tokens = user['tokens'];
//
//     await prefs.setString('access_token', tokens['access']);
//     await prefs.setString('refresh_token', tokens['refresh']);
//     await prefs.setString('user_id', user['id'].toString());
//     await prefs.setString('user_email', user['email']);
//     await prefs.setString('user_name', user['full_name']);
//     await prefs.setString('user_role', user['role']);
//     await prefs.setString('user_phone', user['phone_number'] ?? '');
//     await prefs.setString('user_status', user['status']);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: isLoading
//             ? Transform.scale(
//                 scale: 1.2,
//                 child: const CircularProgressIndicator(
//                   color: Color(0xFFFBC02D),
//                   strokeWidth: 6,
//                 ),
//               )
//             : const SizedBox.shrink(),
//       ),
//     );
//   }
// }
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/services/api_services.dart';
import '../../shared/utils/toast_utils.dart';
import '../categories/home_category.dart';

class AskariEndPoint extends StatefulWidget {
  final String? userEmail;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;

  const AskariEndPoint({
    super.key,
    this.userEmail,
    this.firstName,
    this.lastName,
    this.phoneNumber,
  });

  @override
  State<AskariEndPoint> createState() => _AskariEndPointState();
}

class _AskariEndPointState extends State<AskariEndPoint> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getEmail();
  }

  void getEmail() async {
    final email = widget.userEmail ?? 'test8@gmail.com';

    bool? exists = await checkEmailExists(email);

    if (exists == true) {
      print('Email already exists - Login karo');
      await _login(email);
    } else if (exists == false) {
      print('Email available - Registration dialog show karo');
    } else {
      print('Error checking email');
    }
  }

  Future<bool?> checkEmailExists(String email) async {
    try {
      setState(() => isLoading = true);
      var dio = Dio();

      var data = FormData.fromMap({'email': email});

      var response = await dio.request(
        'http://192.168.100.90:1234/api/v1/auth/check-email/',
        options: Options(method: 'GET', contentType: 'multipart/form-data'),
        data: data,
      );

      if (response.statusCode == 200) {
        print(json.encode(response.data));
        bool exists = response.data['data']['exists'] ?? false;
        print('Email exists: $exists');

        if (exists == false) {
          _showPasswordDialog();
        }
        return exists;
      }

      return null;
    } on DioException catch (e) {
      if (e.response != null) {
        print('Error: ${e.response?.statusCode}');
        print('Message: ${e.response?.data}');
      } else {
        print('Error: ${e.message}');
        print('Type: ${e.type}');
      }
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _registerOrLogin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    try {
      setState(() => isLoading = true);

      final dio = Dio();

      // Username email se generate karo
      final username = email.split('@')[0];

      final formData = FormData.fromMap({
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'password': password,
        'password_confirm': password,
      });

      final response = await dio.post(
        'http://192.168.100.90:1234/api/v1/auth/register-or-login/',
        data: formData,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        if (responseData['status'] == true) {
          // Session save karo
          await saveUserSession(responseData['data']);

          setState(() => isLoading = false);

          // Home screen pe navigate karo
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeCategoriesScreen()),
          );
        } else {
          setState(() => isLoading = false);
          ToastUtil.showCustomBottomSheet(
            context,
            responseData['message'] ?? 'Registration failed',
          );
        }
      } else {
        setState(() => isLoading = false);
        ToastUtil.showCustomBottomSheet(
          context,
          "${response.statusMessage ?? 'Unknown error'}",
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      final msg = _humanizeError(e);
      ToastUtil.showCustomBottomSheet(context, msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ToastUtil.showCustomBottomSheet(context, e.toString());
    }
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Color(0xFFFBC02D),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "Complete your profile",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      "Please set your password",
                      style: TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 20),

                    // Password
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Complete Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                          if (passwordController.text.trim().isEmpty) {
                            ToastUtil.showCustomBottomSheet(
                              context,
                              'Please enter password',
                            );
                            return;
                          }

                          Navigator.pop(context);

                          await _registerOrLogin(
                            email: widget.userEmail ?? 'test8@gmail.com',
                            password: passwordController.text.trim(),
                            firstName: widget.firstName ?? 'User',
                            lastName: widget.lastName ?? 'Guest',
                            phoneNumber: widget.phoneNumber ?? '0000000000',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBC02D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                            : const Text(
                          "Complete",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
      return e.message ?? 'Network error';
    }
    return e.toString();
  }

  Future<void> _login(String email) async {
    // Ye method tab call hoga jab email already exist karti hai
    // Yahan pe login API call karo
    print('Login called for: $email');
    // Your existing login logic
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
      backgroundColor: Colors.white,
      body: Center(
        child: isLoading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: 1.2,
              child: const CircularProgressIndicator(
                color: Color(0xFFFBC02D),
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}