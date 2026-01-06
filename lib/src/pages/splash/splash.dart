import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:jmart_sdk/src/pages/categories/home_category.dart';
import 'package:jmart_sdk/src/shared/utils/toast_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../shared/services/api_services.dart';
import '../../shared/widgets/custom_button.dart';
import '../authentication/login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final CarouselSliderController _controller = CarouselSliderController();

  bool isLoading = false;
  bool showGuestButton = false;

  final _images = const [
    'packages/jmart_sdk/assets/splash/welcome1.png',
    'packages/jmart_sdk/assets/splash/welcome2.png',
    'packages/jmart_sdk/assets/splash/welcome3.png',
    'packages/jmart_sdk/assets/splash/welcome4.png'
  ];

  int _current = 0;

  @override
  void initState() {
    super.initState();
    _checkIsDeleted();
  }

  Future<void> _checkIsDeleted() async {
    final prefs = await SharedPreferences.getInstance();
    final isDeleted = prefs.getString("isDeleted") ?? "no";
    debugPrint("isDeleted from prefs = $isDeleted");

    setState(() {
       showGuestButton = isDeleted.toLowerCase() == "yes";
    });
  }

  Future<void> checkToken() async {

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');

    if (email == "guest@gmail.com" || email == null || email == ""){
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
      return;
    }

    ToastUtil.checkToken(
      onValid: (decoded) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeCategoriesScreen()),
              (_) => false,
        );
      },
      onInvalid: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      },
    );
  }

  Future<void> saveUserSession(Map<String, dynamic> user, String email) async {
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
    await prefs.setString('guest', email);
  }

  Future<void> _login() async {
    final username = "guest@gmail.com";
    final pass = "Pakistan@123";
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
          await saveUserSession(user, "guest@gmail.com");

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

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final bottomSafe = padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen carousel
          Positioned.fill(
            child: CarouselSlider.builder(
              carouselController: _controller,
              itemCount: _images.length,
              itemBuilder: (_, index, __) => Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      _images[index],
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
              options: CarouselOptions(
                height: double.infinity,
                viewportFraction: 1,
                enlargeCenterPage: false,
                enableInfiniteScroll: true,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 2),
                autoPlayAnimationDuration: const Duration(milliseconds: 600),
                onPageChanged: (i, _) => setState(() => _current = i),
              ),
            ),
          ),

          // bottom gradient overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 200 + bottomSafe,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),
          ),

          // dots indicator
          Positioned(
            left: 0,
            right: 0,
            bottom: 100 + bottomSafe,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 22 : 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
          ),

          // buttons
          Positioned(
            left: 24,
            right: 24,
            bottom: 24 + bottomSafe,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomButton(
                  text: "Get Started",
                  onPressed: checkToken,
                ),
                if (showGuestButton) ...[
                  const SizedBox(height: 12),
                  CustomButton(
                    text: "Continue as Guest",
                    onPressed: isLoading ? null : _login,
                    isLoading: isLoading,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
