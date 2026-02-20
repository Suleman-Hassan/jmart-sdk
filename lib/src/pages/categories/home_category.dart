import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/utils/toast_utils.dart';
import '../../shared/widgets/banner_home.dart';
import '../../shared/widgets/search_bar.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/custom_button.dart';

import '../authentication/login.dart';
import '../cart/cart_screen.dart';
import '../change_password/change_password.dart';
import '../products/products.dart';
import '../support/support.dart';
import '../support/support_model.dart';
import '../track_order/order_history.dart';
import 'model/section_model.dart';

const kJmartYellow = Color(0xFFFBC02D);

class HomeCategoriesScreen extends StatefulWidget {
  const HomeCategoriesScreen({super.key});

  @override
  State<HomeCategoriesScreen> createState() => _HomeCategoriesScreenState();
}

class _HomeCategoriesScreenState extends State<HomeCategoriesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  final ScrollController _scrollCtrl = ScrollController();
  bool _canJump = false;
  bool _atBottom = false;

  List<String> _banners = [];
  List<SectionM> _sections = [];
  bool _isLoading = true;

  bool _fetchInFlight = false;
  DateTime? _lastFetch;
  static const _minFetchGap = Duration(seconds: 5);

  bool _serverError = false;
  String? _serverErrorMsg;

  static const _cartKey = 'jmart_cart_v1';
  List<Map<String, dynamic>> _persistedCart = [];
  final Map<String, int> _cart = {};
  int totalQty = 0;
  // int get totalQty => _persistedCart.fold(0, (a, e) => a + (e['qty'] as int));
  double get totalPrice => _persistedCart.fold(
    0.0,
    (a, e) => a + (e['qty'] as int) * (e['price'] as double),
  );

  bool showGuestButton = false;
  ContactInfo? _contact;
  static const String _endpoint = ApiConstants.supportURL;
  String? _error;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
    ),
  );

  @override
  void initState() {
    super.initState();
    _checkIsDeleted();
    _fetchContacts();
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      final bool canJumpNow = pos.maxScrollExtent > 300;
      final bool atBottomNow = pos.pixels >= pos.maxScrollExtent - 8;

      if (canJumpNow != _canJump || atBottomNow != _atBottom) {
        setState(() {
          _canJump = canJumpNow;
          _atBottom = atBottomNow;
        });
      }
    });

    _loadPersistedCart();

    ToastUtil.checkToken(
      onValid: (decoded) => fetchHomeScreenData(),
      onInvalid: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
    );
  }

  Future<void> _fetchContacts() async {
    setState(() {
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
        });
      } else {
        setState(() {
          _error = 'No contact details found';
        });
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;

      if (code == 401 || code == 403 || code == 404) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }

      setState(() {
        _error = _explainDioError(e);
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
      });
    }
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

  Future<int> getTotalQty() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) return 0;

    final cartKey = _getCartKey(email);
    final blob = prefs.getString(cartKey);
    if (blob == null || blob.isEmpty) return 0;

    try {
      final List<dynamic> raw = jsonDecode(blob);
      return raw.fold<int>(0, (a, e) => a + (e['qty'] as int? ?? 0));
    } catch (_) {
      return 0;
    }
  }

  String _getCartKey(String email) {
    return 'jmart_cart_${email.toLowerCase()}';
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await _loadPersistedCart();
    await fetchHomeScreenData(force: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _jump() async {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final target = _atBottom ? 0.0 : pos.maxScrollExtent;
    await _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  // Future<void> _loadPersistedCart() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final blob = prefs.getString(_cartKey);
  //   if (blob == null || blob.isEmpty) {
  //     setState(() {});
  //     return;
  //   }
  //   try {
  //     final List<dynamic> raw = jsonDecode(blob);
  //     _persistedCart =
  //         raw
  //             .map<Map<String, dynamic>>((e) {
  //               return {
  //                 'productId': (e['productId'] ?? '').toString(),
  //                 'title': (e['title'] ?? '').toString(),
  //                 'imageUrl': (e['imageUrl'] ?? '').toString(),
  //                 'price':
  //                     (e['price'] is num)
  //                         ? (e['price'] as num).toDouble()
  //                         : double.tryParse('${e['price']}') ?? 0.0,
  //                 'qty':
  //                     (e['qty'] is num)
  //                         ? (e['qty'] as num).toInt()
  //                         : int.tryParse('${e['qty']}') ?? 0,
  //               };
  //             })
  //             .where(
  //               (m) =>
  //                   (m['productId'] as String).isNotEmpty &&
  //                   (m['qty'] as int) > 0,
  //             )
  //             .toList();
  //
  //     _cart
  //       ..clear()
  //       ..addEntries(
  //         _persistedCart.map(
  //           (e) => MapEntry(e['productId'] as String, e['qty'] as int),
  //         ),
  //       );
  //   } catch (_) {
  //     _persistedCart = [];
  //   }
  //   setState(() {});
  // }

  Future<void> _loadPersistedCart() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) {
      _persistedCart = [];
      _cart.clear();
      setState(() {});
      return;
    }

    final cartKey = _getCartKey(email);
    final blob = prefs.getString(cartKey);

    if (blob == null || blob.isEmpty) {
      _persistedCart = [];
      _cart.clear();
      setState(() {});
      return;
    }

    try {
      final List<dynamic> raw = jsonDecode(blob);
      _persistedCart =
          raw
              .map<Map<String, dynamic>>((e) {
                return {
                  'productId': (e['productId'] ?? '').toString(),
                  'title': (e['title'] ?? '').toString(),
                  'imageUrl': (e['imageUrl'] ?? '').toString(),
                  'price':
                      (e['price'] is num)
                          ? (e['price'] as num).toDouble()
                          : double.tryParse('${e['price']}') ?? 0.0,
                  'qty':
                      (e['qty'] is num)
                          ? (e['qty'] as num).toInt()
                          : int.tryParse('${e['qty']}') ?? 0,
                };
              })
              .where(
                (m) =>
                    (m['productId'] as String).isNotEmpty &&
                    (m['qty'] as int) > 0,
              )
              .toList();

      _cart
        ..clear()
        ..addEntries(
          _persistedCart.map(
            (e) => MapEntry(e['productId'] as String, e['qty'] as int),
          ),
        );
    } catch (_) {
      _persistedCart = [];
      _cart.clear();
    }

    final qty = _persistedCart.fold<int>(
      0,
      (a, e) => a + (e['qty'] as int? ?? 0),
    );
    setState(() {
      totalQty = qty;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  String _norm(String s) => s.toLowerCase().trim();

  List<SubWithCat> _flattenSubs() {
    final out = <SubWithCat>[];
    for (final sec in _sections) {
      for (final sub in sec.subcategories) {
        out.add(SubWithCat(sub: sub, cat: sec.category));
      }
    }
    return out;
  }

  List<SubWithCat> _searchSubs(String q) {
    if (q.isEmpty) return const [];
    final needle = _norm(q);
    final all = _flattenSubs();

    final subMatches = <SubWithCat>[];
    for (final swc in all) {
      if (_norm(swc.sub.title).contains(needle)) {
        subMatches.add(swc);
      }
    }
    if (subMatches.isNotEmpty) {
      subMatches.sort(
        (a, b) => _norm(
          a.sub.title,
        ).indexOf(needle).compareTo(_norm(b.sub.title).indexOf(needle)),
      );
      return subMatches;
    }

    final catMatches = <SubWithCat>[];
    for (final sec in _sections) {
      if (_norm(sec.category.title).contains(needle)) {
        for (final s in sec.subcategories) {
          catMatches.add(SubWithCat(sub: s, cat: sec.category));
        }
      }
    }
    if (catMatches.isNotEmpty) {
      final map = <int, SubWithCat>{for (final x in catMatches) x.sub.id: x};
      return map.values.toList();
    }

    return const [];
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return path;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }

  Future<Map<String, String?>> getAuthTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access': prefs.getString('access_token'),
      'refresh': prefs.getString('refresh_token'),
    };
  }

  Future<void> fetchHomeScreenData({bool force = false}) async {
    if (_serverError) {
      if (mounted) setState(() => _serverError = false);
    }

    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _minFetchGap) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (_fetchInFlight) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _fetchInFlight = true;

    try {
      final tokens = await getAuthTokens();
      final accessToken = tokens['access'];

      if (accessToken == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      final dio = Dio();
      final response = await dio.get(
        ApiConstants.categoriesUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == true) {
        final data = response.data;
        if (!mounted) return;
        setState(() {
          _banners = List<String>.from(data['banners'] ?? const []);
          _sections =
              (data['sections'] as List<dynamic>? ?? [])
                  .map((x) => SectionM.fromJson(x as Map<String, dynamic>))
                  .toList();
          _isLoading = false;
          _serverError = false;
          _serverErrorMsg = null;
        });
        return;
      }

      final code = response.statusCode ?? 0;
      if (code == 500) {
        if (!mounted) return;
        setState(() {
          _serverError = true;
          _serverErrorMsg = 'Something went wrong';
          _isLoading = false;
        });
        return;
      }

      if ({400, 401, 402, 403, 404}.contains(code)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _serverError = true;
        _serverErrorMsg = 'HTTP $code';
        _isLoading = false;
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;

      if (code != null && {400, 401, 402, 403, 404}.contains(code)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      if (code == 500) {
        if (mounted) {
          setState(() {
            _serverError = true;
            _serverErrorMsg = 'HTTP 500';
            _isLoading = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _serverError = true;
          _serverErrorMsg = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = true;
          _serverErrorMsg = '$e';
          _isLoading = false;
        });
      }
    } finally {
      _lastFetch = DateTime.now();
      _fetchInFlight = false;
      if (mounted && !_serverError) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> logout() async {
    final tokens = await getAuthTokens();
    final accessToken = tokens['access'];
    final refreshToken = tokens['refresh'];

    if (accessToken == null || refreshToken == null) {
      ToastUtil.showError("Session expired. Please login again.");
      final prefs = await SharedPreferences.getInstance();
      // await prefs.clear();
      await removeAccessToken();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    var headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    var data = json.encode({"refresh": refreshToken});

    try {
      var dio = Dio();
      var response = await dio.request(
        ApiConstants.logoutUrl,
        options: Options(method: 'POST', headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        //  await prefs.clear();
        await removeAccessToken();
        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ToastUtil.showError('${response.statusMessage}');
      }
    } catch (e) {
      ToastUtil.showError('$e');
    }
  }

  Future<void> _checkIsDeleted() async {
    final prefs = await SharedPreferences.getInstance();
    final isDeleted = prefs.getString("isDeleted") ?? "no";
    debugPrint("isDeleted from prefs = $isDeleted");

    setState(() {
      showGuestButton = isDeleted.toLowerCase() == "yes";
    });
  }

  Future<void> removeAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString("user_email") ?? "";
    final token = prefs.getString("access_token") ?? "";

    if (email.isEmpty || token.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Missing email or token")));
      }
      return;
    }

    try {
      final response = await Dio().post(
        ApiConstants.deleteUrl,
        data: FormData.fromMap({"email": email}),
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200) {
        await prefs.clear();

        if (context.mounted) {
          Navigator.of(context).pop();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      } else {
        if (context.mounted) {
          Navigator.of(context).pop(); // close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data["message"] ?? "Delete failed"),
            ),
          );
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data["message"] ?? "Network error";
      if (context.mounted) {
        Navigator.of(context).pop(); // close dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout,
                      color: Color(0xFFFBC02D),
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Account Deletion",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Are you sure you want to delete account?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                isLoading ? null : () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBC02D),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                isLoading
                                    ? null
                                    : () async {
                                      setState(() => isLoading = true);
                                      await _deleteAccount(
                                        context,
                                      ); // ✅ handles dialog close
                                      setState(() => isLoading = false);
                                    },
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                    : const Text("Delete"),
                          ),
                        ),
                      ],
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

  Future<void> _confirmLogout() async {
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout,
                      color: Color(0xFFFBC02D),
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Logout Confirmation",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Are you sure you want to logout?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                isLoading ? null : () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBC02D),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                isLoading
                                    ? null
                                    : () async {
                                      setState(() => isLoading = true);
                                      await logout(); // 👈 iske andar hi navigation hoga
                                      // Yahan extra Navigator.pop(context) NAHI karna
                                    },
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                    : const Text("Logout"),
                          ),
                        ),
                      ],
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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  @override
  Widget build(BuildContext context) {
    final results = _searchSubs(_query);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      drawer: _AppDrawer(
        onHome: () => Navigator.pop(context),
        onOrders: () async {
          Navigator.pop(context);
          Navigator.popUntil(context, (route) => route.isFirst);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
          );
          await _refreshAll();
        },
        onSupport: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          );
          await _refreshAll();
        },
        // onChangePassword: () async {
        //   Navigator.pop(context);
        //   await Navigator.push(
        //     context,
        //     MaterialPageRoute(builder: (_) => const ChangePassword()),
        //   );
        //   await _refreshAll();
        // },
        // onLogout: () async {
        //   Navigator.pop(context);
        //   await _confirmLogout();
        // },
        onCart: () async {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
        // onDeleteAccount: () async {
        //   Navigator.pop(context);
        //   await _confirmDeleteAccount();
        // },
      ),

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(95),
        child: AppBar(
          backgroundColor: kJmartYellow,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            'J Mart',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart,
                      color: Colors.black,
                      size: 24,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                      await _refreshAll();
                    },
                  ),
                  if (totalQty > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalQty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 57, left: 20, right: 20),
              child:
                  (_contact?.phone != null || _contact?.whatsapp != null)
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_contact?.phone != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _launchCall(_contact!.phone),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.phone_outlined,
                                      size: 18,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _contact!.phone!,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_contact?.whatsapp != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _openWhatsApp(_contact!.whatsapp),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      "packages/jmart_sdk/assets/icons/whatsapp.png",
                                      width: 18,
                                      height: 18,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _contact!.whatsapp!,
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                      : const SizedBox.shrink(),
            ),
          ),
        ),
      ),

      // appBar: AppBar(
      //   backgroundColor: kJmartYellow,
      //   elevation: 0,
      //   centerTitle: true,
      //   title: const Text(
      //     'J Mart',
      //     style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      //   ),
      //   iconTheme: const IconThemeData(color: Colors.black),
      //   actions: [
      //     Padding(
      //       padding: const EdgeInsets.only(right: 8),
      //       child: Stack(
      //         clipBehavior: Clip.none,
      //         children: [
      //           IconButton(
      //             icon: const Icon(Icons.shopping_cart, color: Colors.black),
      //             onPressed: () async {
      //               await Navigator.push(
      //                 context,
      //                 MaterialPageRoute(builder: (_) => const CartScreen()),
      //               );
      //               await _refreshAll();
      //             },
      //           ),
      //           if (totalQty > 0)
      //             Positioned(
      //               right: 4,
      //               top: 4,
      //               child: Container(
      //                 padding: const EdgeInsets.symmetric(
      //                   horizontal: 6,
      //                   vertical: 2,
      //                 ),
      //                 decoration: BoxDecoration(
      //                   color: Colors.black,
      //                   borderRadius: BorderRadius.circular(12),
      //                 ),
      //                 child: Text(
      //                   '$totalQty',
      //                   style: const TextStyle(
      //                     color: Colors.white,
      //                     fontSize: 10,
      //                     fontWeight: FontWeight.w800,
      //                   ),
      //                 ),
      //               ),
      //             ),
      //         ],
      //       ),
      //     ),
      //   ],
      // ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
                : _serverError
                ? _ErrorView(
                  message: _serverErrorMsg ?? '',
                  onRetry: () async {
                    if (!mounted) return;
                    setState(() {
                      _isLoading = true;
                      _serverError = false;
                    });
                    await fetchHomeScreenData(force: true);
                  },
                )
                : Stack(
                  children: [
                    ScrollConfiguration(
                      behavior: const _GlowScrollBehavior(),
                      child: Scrollbar(
                        controller: _scrollCtrl,
                        thumbVisibility: false,
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1) Search
                              JSearchBar(
                                controller: _searchCtrl,
                                query: _query,
                                onChanged: _onSearchChanged,
                                onClear: _clearSearch,
                              ),

                              // 2) Carousel
                              if (_banners.isNotEmpty)
                                BannerCarousel(banners: _banners),
                              const SizedBox(height: 16),

                              if (_query.isNotEmpty) ...[
                                const SectionHeader('Search Results'),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child:
                                      results.isEmpty
                                          ? const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 24,
                                            ),
                                            child: Text('No results found.'),
                                          )
                                          : _SubWithCatGrid(
                                            items: results,
                                            resolve: _resolveImageUrl,
                                            onTap: (x) async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) => ProductScreen(
                                                        title: x.sub.title,
                                                        categoryId:
                                                            x.cat.catcode,
                                                        subcategoryId:
                                                            x.sub.subcode,
                                                      ),
                                                ),
                                              );
                                              if (!mounted) return;
                                              _clearSearch();
                                              await _refreshAll();
                                            },
                                          ),
                                ),
                              ] else ...[
                                for (final section in _sections) ...[
                                  SectionHeader(section.category.title),
                                  const SizedBox(height: 8),

                                  if (section.subcategories.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Text('No items yet.'),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: _SubWithCatGrid(
                                        items:
                                            section.subcategories
                                                .map(
                                                  (s) => SubWithCat(
                                                    sub: s,
                                                    cat: section.category,
                                                  ),
                                                )
                                                .toList(),
                                        resolve: _resolveImageUrl,
                                        onTap: (x) async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => ProductScreen(
                                                    title: x.sub.title,
                                                    categoryId: x.cat.catcode,
                                                    subcategoryId:
                                                        x.sub.subcode,
                                                  ),
                                            ),
                                          );
                                          await _refreshAll();
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // FLOATING JUMP BUTTON
                    Positioned(
                      right: 16,
                      bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
                      child: AnimatedScale(
                        scale: _canJump ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: AnimatedOpacity(
                          opacity: _canJump ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: FloatingActionButton(
                            backgroundColor: kJmartYellow,
                            foregroundColor: Colors.black,
                            onPressed: _jump,
                            child: Icon(
                              _atBottom
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (message.isNotEmpty)
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(height: 16),
            CustomButton(onPressed: onRetry, text: 'Retry'),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatefulWidget {
  final VoidCallback onHome;
  final VoidCallback onOrders;
  final VoidCallback onCart;
  // final VoidCallback onDeleteAccount;
  final VoidCallback onSupport;
  // final VoidCallback onChangePassword;
  // final Future<void> Function() onLogout;

  const _AppDrawer({
    super.key,
    required this.onHome,
    required this.onOrders,
    required this.onSupport,
    // required this.onChangePassword,
    // required this.onLogout,
    required this.onCart,
    // required this.onDeleteAccount,
  });

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  String _name = '';
  String _email = '';
  String _isDeleted = "no";

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? '';
      _email = prefs.getString('user_email') ?? '';
      _isDeleted = prefs.getString('isDeleted') ?? "no";
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? '';
      _email = prefs.getString('user_email') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                _name.isNotEmpty ? _name : 'Guest User',
                style: const TextStyle(color: Colors.black),
              ),
              accountEmail: Text(
                _email.isNotEmpty ? _email : 'No email saved',
                style: const TextStyle(color: Colors.black),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.black12,
                child: Icon(Icons.person, size: 36, color: Colors.black54),
              ),
              decoration: const BoxDecoration(color: Color(0xFFFBC02D)),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('Home'),
                    onTap: widget.onHome,
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('My Orders'),
                    onTap: widget.onOrders,
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_shopping_cart),
                    title: const Text('My Cart'),
                    onTap: widget.onCart,
                  ),
                  // ListTile(
                  //   leading: const Icon(Icons.password),
                  //   title: const Text('Change Password'),
                  //   onTap: widget.onChangePassword,
                  // ),
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined),
                    title: const Text('Support'),
                    onTap: widget.onSupport,
                  ),
                  // if (_isDeleted.toLowerCase() == "yes")
                  //   ListTile(
                  //     leading: const Icon(Icons.delete),
                  //     title: const Text('Delete Account'),
                  //     onTap: widget.onDeleteAccount,
                  //   ),
                ],
              ),
            ),
           // const Divider(height: 2),
            // ListTile(
            //   leading: const Icon(Icons.logout),
            //   title: const Text('Logout'),
            //   onTap: widget.onLogout,
            // ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _SubWithCatGrid extends StatelessWidget {
  final List<SubWithCat> items;
  final String Function(String) resolve;
  final void Function(SubWithCat) onTap;

  const _SubWithCatGrid({
    required this.items,
    required this.resolve,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, i) {
        final x = items[i];
        final img = resolve(x.sub.image);

        return InkWell(
          onTap: () => onTap(x),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Color(0x14000000)),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      img,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  x.sub.title.isEmpty ? 'Untitled' : x.sub.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  x.cat.title,
                  // maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
// class _SubWithCatGrid extends StatelessWidget {
//   final List<SubWithCat> items;
//   final String Function(String) resolve;
//   final void Function(SubWithCat) onTap;
//
//   const _SubWithCatGrid({
//     required this.items,
//     required this.resolve,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return MasonryGridView.count(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       crossAxisCount: 3,
//       mainAxisSpacing: 10,
//       crossAxisSpacing: 10,
//       itemCount: items.length,
//       itemBuilder: (context, i) {
//         final x = items[i];
//         final img = resolve(x.sub.image);
//
//         return InkWell(
//           onTap: () => onTap(x),
//           borderRadius: BorderRadius.circular(16),
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: const [
//                 BoxShadow(blurRadius: 6, color: Color(0x14000000)),
//               ],
//             ),
//             padding: const EdgeInsets.all(10),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: Image.network(
//                     img,
//                     fit: BoxFit.cover,
//                     errorBuilder: (_, __, ___) =>
//                     const Icon(Icons.broken_image, size: 40),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   x.sub.title.isEmpty ? 'Untitled' : x.sub.title,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   x.cat.title,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(fontSize: 11, color: Colors.grey),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

class _GlowScrollBehavior extends ScrollBehavior {
  const _GlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return super.buildOverscrollIndicator(context, child, details);
  }
}
