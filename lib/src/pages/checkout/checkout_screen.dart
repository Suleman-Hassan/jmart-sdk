import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jmart_sdk/src/core/constants/api_constants.dart';
import 'package:jmart_sdk/src/pages/track_order/order_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/utils/toast_utils.dart';
import '../authentication/login.dart';
import '../webview/jazzcash.dart';

String _selectedPayment = "COD";
const kJmartYellow = Color(0xFFFBC02D);
const String kCartPrefsKey = 'jmart_cart_v1';

class Products {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final int? etaMinutes;

  const Products({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.etaMinutes,
  });
}

class CartLine {
  final Products product;
  final int qty;
  const CartLine({required this.product, required this.qty});
  double get lineTotal => product.price * qty;
}

class CheckoutScreen extends StatefulWidget {
  final String title;
  final List<CartLine>? lines;
  final double deliveryFee;
  final double discount;
  final List<String>? addresses;

  const CheckoutScreen({
    super.key,
    this.title = 'Checkout',
    this.lines,
    this.deliveryFee = 0,
    this.discount = 0,
    this.addresses,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final List<String> _addresses =
      widget.addresses ??
      const ['DHA PHASE 1', 'DHA PHASE 2', 'DHA PHASE 3', 'DHA PHASE 4'];

  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();
  final TextEditingController _housenoCtrl = TextEditingController();

  String? _selectedAddress;
  String? _sectorAddress;
  String? _houseNo;
  bool _submitting = false;

  List<CartLine> get _lines => widget.lines ?? const [];

  double get subTotal => _lines.fold(0, (s, l) => s + l.lineTotal);
  double get total {
    final delivery = double.tryParse(savedCharges ?? '0') ?? 0;
    return (subTotal - widget.discount) + delivery;
  }

  String kSavedPhaseKey = 'saved_phase';
  String kSavedSectorKey = 'saved_sector';
  String kSavedStreetKey = 'saved_street';
  String kSavedHouseKey = 'saved_house';
  String kSavedZoneId = 'saved_zone_id';

  List<DeliveryZone> zones = [];
  bool loading = true;
  final _dio = Dio();
  String? savedCharges;
  DeliveryZone? _selectedZone;
  String? selectedPhase;
  @override
  void initState() {
    super.initState();
    ToastUtil.checkToken(
      onValid: (decoded) {},
      onInvalid: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
    );
    _loadSavedAddress();
    fetchDeliveryZones();
  }

  Future<void> _loadSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) return;

    setState(() {
      selectedPhase =
          prefs.getString(_getAddressKey(email, kSavedPhaseKey)) ?? '';
      _addressCtrl.text =
          prefs.getString(_getAddressKey(email, kSavedSectorKey)) ?? '';
      _streetCtrl.text =
          prefs.getString(_getAddressKey(email, kSavedStreetKey)) ?? '';
      _housenoCtrl.text =
          prefs.getString(_getAddressKey(email, kSavedHouseKey)) ?? '';
    });
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  String _getZoneKey(String email) {
    return 'saved_zone_id_${email.toLowerCase()}';
  }

  String _getAddressKey(String email, String baseKey) {
    return '${baseKey}_${email.toLowerCase()}';
  }

  Future<void> _saveAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) return;

    await prefs.setString(
      _getAddressKey(email, kSavedPhaseKey),
      selectedPhase ?? '',
    );
    await prefs.setString(
      _getAddressKey(email, kSavedSectorKey),
      _addressCtrl.text.trim(),
    );
    await prefs.setString(
      _getAddressKey(email, kSavedStreetKey),
      _streetCtrl.text.trim(),
    );
    await prefs.setString(
      _getAddressKey(email, kSavedHouseKey),
      _housenoCtrl.text.trim(),
    );
  }

  Future<void> _clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) return;

    final cartKey = _getCartKey(email);
    await prefs.remove(cartKey);
  }

  String _getCartKey(String email) {
    return 'jmart_cart_${email.toLowerCase()}';
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _housenoCtrl.dispose();
    _streetCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String?>> _getAuthTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access': prefs.getString('access_token'),
      'refresh': prefs.getString('refresh_token'),
    };
  }

  String _formatMoney(double v) => 'Rs. ${v.toStringAsFixed(0)}';

  Map<String, dynamic> _buildOrderPayload() {
    final items = _lines.map((l) {
      final parsedId = int.tryParse(l.product.id);
      return {
        'product_detail': {
          'id': parsedId ?? l.product.id,
          'name': l.product.name,
          'quantity': l.qty,
          'price': double.parse(l.product.price.toStringAsFixed(2)),
        },
      };
    }).toList();

    final addr = _addressCtrl.text.trim();
    final street = _streetCtrl.text.trim();
    final houseno = _housenoCtrl.text.trim();

    return {
      'address': "$selectedPhase , $addr , $street  , $houseno",
      'grand_total': double.parse(total.toStringAsFixed(2)),
      'payment_method': _selectedPayment, //"JazzCash",
      'items': items,
    };
  }

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        responseType: ResponseType.json,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 600,
      ),
    );
    return dio;
  }

  Future<void> _clearPersistedCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kCartPrefsKey);
  }

  void _showMustSelectAddressAlert(String text) {
    ToastUtil.showCustomBottomSheet(context, text);
  }

  Future<void> jazzcashFromOrderResponse(Map<String, dynamic> respData) async {
    final paymentUrl = respData["data"]["payment_url"];
    final postData = Map<String, dynamic>.from(respData["data"]["post_data"]);

    final result = await JazzCashService.makeTransaction(
      paymentUrl: paymentUrl,
      postData: postData,
    );

    final responseCode = result["responseCode"];
    final responseMessage =
        result["responseMessage"] ?? "No message from server";

    print("JazzCash Response Code: $responseCode");
    await _saveAddress();
    try {
      final dio = Dio();
      await dio.post(
        ApiConstants.callBack,
        data: FormData.fromMap(JazzCashService.lastFullResponse ?? {}),
        options: Options(
          headers: {"Content-Type": "application/x-www-form-urlencoded"},
        ),
      );
      print("Callback hit successfully with JazzCash data (form-data)");
    } catch (e) {
      print("Callback API error: $e");
    }
    if (responseCode == "000") {
      await _clearPersistedCart();
      // try {
      //   final dio = Dio();
      //   await dio.post(
      //     ApiConstants.callBack,
      //     data: FormData.fromMap(JazzCashService.lastFullResponse ?? {}),
      //     options: Options(
      //       headers: {"Content-Type": "application/x-www-form-urlencoded"},
      //     ),
      //   );
      //   print("Callback hit successfully with JazzCash data (form-data)");
      // } catch (e) {
      //   print("Callback API error: $e");
      // }
      _clearCart();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  //const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: Image.asset(
                      'packages/jmart_sdk/assets/icons/order_success.gif',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Order Placed!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$responseMessage',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kJmartYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const OrderHistoryScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Transaction failed!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$responseMessage',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kJmartYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigator.of(context).pushAndRemoveUntil(
                        //   MaterialPageRoute(
                        //     builder: (_) => const OrderHistoryScreen(),
                        //   ),
                        //   (_) => false,
                        // );
                      },
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _placeOrder() async {
    if (_addressCtrl.text.trim().isEmpty) {
      _showMustSelectAddressAlert("Please select area");
      return;
    } else if (_streetCtrl.text.trim().isEmpty) {
      _showMustSelectAddressAlert("Please select area");
      return;
    } else if (_housenoCtrl.text.trim().isEmpty) {
      _showMustSelectAddressAlert("Please select area");
      return;
    } else if (selectedPhase == "" || selectedPhase == null) {
      _showMustSelectAddressAlert("Please add a delivery address first");
      return;
    }

    if (_lines.isEmpty) {
      ToastUtil.showError('Your cart is empty.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);

    try {
      final payload = _buildOrderPayload();
      final tokens = await _getAuthTokens();
      final access = tokens['access'];

      final dio = _buildDio();
      final resp = await dio.post(
        ApiConstants.placeOrderUrl,
        data: payload,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (access != null) 'Authorization': 'Bearer $access',
          },
        ),
      );

      final code = resp.statusCode ?? 0;

      if (code == 200 || code == 201) {
        // await _clearPersistedCart();
        // await _saveAddress();
        // _clearCart();
        final message = (resp.data is Map)
            ? (resp.data['message']) ?? "Confirmed"
            : null;
        // final url = resp.data['data']['redirect_url'];
        // print(url);
        // final respData = resp.data['data'];
        // final paymentUrl = respData['payment_url'];
        // final postData = Map<String, dynamic>.from(respData['post_data']);
        if (_selectedPayment == "COD") {
          await _clearPersistedCart();
          await _saveAddress();
          _clearCart();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 150,
                        width: 150,
                        child: Image.asset(
                          'packages/jmart_sdk/assets/icons/order_success.gif',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Order Placed!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your Order place ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kJmartYellow,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const OrderHistoryScreen(),
                              ),
                              (_) => false,
                            );
                          },
                          child: const Text('OK'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else {
          await jazzcashFromOrderResponse(resp.data);
        }
        if (!mounted) return;
        return;
      }
      if (code == 401) {
        ToastUtil.showError('Session expired. Please login again.');
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }

      final serverMessage = _extractApiError(resp.data);
      ToastUtil.showError(serverMessage ?? 'Failed to place order ($code).');
    } on DioException catch (e) {
      final serverMessage = _extractApiError(e.response?.data);
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        ToastUtil.showError('Network timeout. Please try again.');
      } else if (serverMessage != null) {
        ToastUtil.showError(serverMessage);
      } else {
        ToastUtil.showError('Order failed: ${e.message}');
      }
    } catch (e) {
      ToastUtil.showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _extractApiError(dynamic data) {
    if (data == null) return null;
    try {
      if (data is String) return data;
      if (data is Map) {
        if (data['message'] is String) return data['message'];
        if (data['detail'] is String) return data['detail'];
        if (data['errors'] is List && data['errors'].isNotEmpty) {
          return data['errors'].join(', ');
        }
        for (final v in data.values) {
          if (v is List && v.isNotEmpty && v.first is String) {
            return v.first as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Future<void> fetchDeliveryZones() async {
  //   final tokens = await _getAuthTokens();
  //   final access = tokens['access'];
  //   try {
  //     final response = await _dio.get(
  //       ApiConstants.zonesUrl,
  //       options: Options(headers: {"Authorization": "Bearer $access"}),
  //     );
  //
  //     if (response.statusCode == 200 && response.data['status'] == true) {
  //       List data = response.data['data'];
  //       setState(() {
  //         zones = data.map((item) => DeliveryZone.fromJson(item)).toList();
  //         loading = false;
  //       });
  //     }
  //   } catch (e) {
  //     print("Error: $e");
  //     setState(() => loading = false);
  //   }
  // }

  Future<void> fetchDeliveryZones() async {
    final tokens = await _getAuthTokens();
    final access = tokens['access'];

    try {
      final response = await _dio.get(
        ApiConstants.zonesUrl,
        options: Options(headers: {"Authorization": "Bearer $access"}),
      );

      if (response.statusCode == 200 && response.data['status'] == true) {
        List data = response.data['data'];
        final loadedZones = data
            .map((item) => DeliveryZone.fromJson(item))
            .toList();

        // final prefs = await SharedPreferences.getInstance();
        // final savedZoneId = prefs.getInt(kSavedZoneId);

        DeliveryZone? selected;
        // if (savedZoneId != null) {
        //   try {
        //     selected = loadedZones.firstWhere((z) => z.id == savedZoneId);
        //   } catch (_) {
        //     selected = null;
        //   }
        // }
        final prefs = await SharedPreferences.getInstance();
        final email = await _getUserEmail();
        if (email != null) {
          final savedZoneId = prefs.getInt(_getZoneKey(email));
          if (savedZoneId != null) {
            try {
              selected = loadedZones.firstWhere((z) => z.id == savedZoneId);
            } catch (_) {
              selected = null;
            }
          }
        }

        setState(() {
          zones = loadedZones;
          loading = false;
          if (selected != null) {
            _selectedZone = selected;
            selectedPhase = selected.title;
            savedCharges = selected.deliveryCharges;
          }
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: kJmartYellow,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Address
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _RowTitle('Delivery Address'),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<DeliveryZone>(
                    value: _selectedZone,
                    hint: Text(
                      loading
                          ? 'Loading zones...'
                          : 'Select saved area (optional)',
                    ),
                    items: loading
                        ? []
                        : zones.map((zone) {
                            return DropdownMenuItem<DeliveryZone>(
                              value: zone,
                              child: Text(zone.title),
                            );
                          }).toList(),
                    onChanged: loading
                        ? null
                        : (v) async {
                            setState(() {
                              selectedPhase = v?.title ?? '';
                              savedCharges = v?.deliveryCharges;
                              _selectedZone = v;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            final email = await _getUserEmail();
                            if (email != null) {
                              await prefs.setInt(
                                _getZoneKey(email),
                                v?.id ?? 0,
                              );
                            }
                          },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Sector (required)',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _streetCtrl,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Street no (required)',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _housenoCtrl,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'House no (required)',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Payment + Promo
            const _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RowTitle('Payment Method'),
                  SizedBox(height: 8),
                  _PaymentRow(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Items
            if (_lines.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Your cart is empty.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _LineTile(line: _lines[i]),
              ),
            const SizedBox(height: 16),
            // Totals + Place Order
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  _TotalRow(label: 'Subtotal', value: _formatMoney(subTotal)),
                  const SizedBox(height: 6),
                  _TotalRow(
                    label: 'Discount',
                    value: _formatMoney(widget.discount),
                  ),
                  const SizedBox(height: 6),
                  _TotalRow(
                    label: 'Delivery',
                    value: savedCharges != null
                        ? _formatMoney(double.tryParse(savedCharges!) ?? 0)
                        : 'Rs. 0',
                  ),
                  const Divider(height: 24),
                  _TotalRow(
                    label: 'Total',
                    value: _formatMoney(total),
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kJmartYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _submitting ? null : _placeOrder,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text('Place Order'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //@override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     backgroundColor: const Color(0xFFF6F6F6),
  //     appBar: AppBar(
  //       backgroundColor: kJmartYellow,
  //       elevation: 0,
  //       centerTitle: true,
  //       title: Text(
  //         widget.title,
  //         style: const TextStyle(
  //           color: Colors.black,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //       iconTheme: const IconThemeData(color: Colors.black),
  //     ),
  //     body: Column(
  //       children: [
  //         // Address
  //         _SectionCard(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const _RowTitle('Delivery Address'),
  //               const SizedBox(height: 8),
  //
  //               DropdownButtonFormField<DeliveryZone>(
  //                 value: _selectedZone,
  //                 hint: Text(loading ? 'Loading zones...' : 'Select saved area (optional)'),
  //                 items: loading
  //                     ? []
  //                     : zones.map((zone) {
  //                   return DropdownMenuItem<DeliveryZone>(
  //                     value: zone,
  //                     child: Text("${zone.title}"),
  //                   );
  //                 }).toList(),
  //                 onChanged: loading
  //                     ? null
  //                     : (v) async {
  //                   setState(() {
  //                     selectedPhase = v?.title ?? '' ;
  //                    // _addressCtrl.text = v?.title ?? '';
  //                     savedCharges = v?.deliveryCharges;
  //                   });
  //                   // final prefs = await SharedPreferences.getInstance();
  //                   // await prefs.setInt(kSavedZoneId, v?.id ?? 0);
  //                   final prefs = await SharedPreferences.getInstance();
  //                   final email = await _getUserEmail();
  //                   if (email != null) {
  //                     await prefs.setInt(_getZoneKey(email), v?.id ?? 0);
  //                   }
  //                 },
  //                 decoration: InputDecoration(
  //                   filled: true,
  //                   fillColor: const Color(0xFFF6F6F6),
  //                   contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  //                   border: OutlineInputBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                     borderSide: BorderSide.none,
  //                   ),
  //                 ),
  //               ),
  //
  //               const SizedBox(height: 10),
  //
  //               TextField(
  //                 controller: _addressCtrl,
  //                 maxLines: 2,
  //                 textInputAction: TextInputAction.done,
  //                 decoration: InputDecoration(
  //                   hintText: 'Sector (required)',
  //                   filled: true,
  //                   fillColor: const Color(0xFFF6F6F6),
  //                   contentPadding: const EdgeInsets.symmetric(
  //                     horizontal: 12,
  //                     vertical: 12,
  //                   ),
  //                   border: OutlineInputBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                     borderSide: BorderSide.none,
  //                   ),
  //                 ),
  //                 onChanged: (_) {
  //                   if (_selectedAddress != null) {
  //                     setState(() => _selectedAddress = null);
  //                   }
  //                 },
  //               ),
  //
  //               const SizedBox(height: 10),
  //
  //               TextField(
  //                 controller: _streetCtrl,
  //                 maxLines: 2,
  //                 textInputAction: TextInputAction.done,
  //                 decoration: InputDecoration(
  //                   hintText: 'Street no (required)',
  //                   filled: true,
  //                   fillColor: const Color(0xFFF6F6F6),
  //                   contentPadding: const EdgeInsets.symmetric(
  //                     horizontal: 12,
  //                     vertical: 12,
  //                   ),
  //                   border: OutlineInputBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                     borderSide: BorderSide.none,
  //                   ),
  //                 ),
  //                 onChanged: (_) {
  //                   if (_selectedAddress != null) {
  //                     setState(() => _selectedAddress = null);
  //                   }
  //                 },
  //               ),
  //
  //               const SizedBox(height: 10),
  //
  //               TextField(
  //                 controller: _housenoCtrl,
  //                 maxLines: 2,
  //                 textInputAction: TextInputAction.done,
  //                 decoration: InputDecoration(
  //                   hintText: 'House no (required)',
  //                   filled: true,
  //                   fillColor: const Color(0xFFF6F6F6),
  //                   contentPadding: const EdgeInsets.symmetric(
  //                     horizontal: 12,
  //                     vertical: 12,
  //                   ),
  //                   border: OutlineInputBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                     borderSide: BorderSide.none,
  //                   ),
  //                 ),
  //                 onChanged: (_) {
  //                   if (_selectedAddress != null) {
  //                     setState(() => _selectedAddress = null);
  //                   }
  //                 },
  //               ),
  //
  //               // const SizedBox(height: 10),
  //               // Row(
  //               //   children: [
  //               //     const Icon(Icons.phone, size: 16),
  //               //     const SizedBox(width: 6),
  //               //     Text(
  //               //       '+92 300 1234567',
  //               //       style: TextStyle(color: Colors.grey.shade800),
  //               //     ),
  //               //     const Spacer(),
  //               //   ],
  //               // ),
  //             ],
  //           ),
  //         ),
  //
  //         // Payment + Promo
  //         const _SectionCard(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               _RowTitle('Payment'),
  //               SizedBox(height: 8),
  //               _PaymentRow(),
  //               // SizedBox(height: 16),
  //               /// _PromoField(),
  //             ],
  //           ),
  //         ),
  //         SizedBox(height: 10),
  //         // Items
  //         Expanded(
  //           child:
  //               _lines.isEmpty
  //                   ? const Center(
  //                     child: Padding(
  //                       padding: EdgeInsets.all(24),
  //                       child: Text('Your cart is empty.'),
  //                     ),
  //                   )
  //                   : ListView.separated(
  //                     padding: const EdgeInsets.symmetric(horizontal: 12),
  //                     itemCount: _lines.length,
  //                     separatorBuilder: (_, __) => const SizedBox(height: 12),
  //                     itemBuilder: (_, i) => _LineTile(line: _lines[i]),
  //                   ),
  //         ),
  //
  //         // Totals + Place Order
  //         Container(
  //           decoration: const BoxDecoration(
  //             color: Colors.white,
  //             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //           ),
  //           padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
  //           child: Column(
  //             children: [
  //               _TotalRow(label: 'Subtotal', value: _formatMoney(subTotal)),
  //               const SizedBox(height: 6),
  //               _TotalRow(
  //                 label: 'Discount',
  //                 value: _formatMoney(widget.discount),
  //               ),
  //               const SizedBox(height: 6),
  //               _TotalRow(
  //                 label: 'Delivery',
  //                 value: savedCharges != null
  //                     ? _formatMoney(double.tryParse(savedCharges!) ?? 0)
  //                     : 'Rs. 0',
  //               ),
  //               const Divider(height: 24),
  //               _TotalRow(
  //                 label: 'Total',
  //                 value: _formatMoney(total),
  //                 bold: true,
  //               ),
  //               const SizedBox(height: 12),
  //               SizedBox(
  //                 width: double.infinity,
  //                 height: 48,
  //                 child: ElevatedButton(
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: kJmartYellow,
  //                     foregroundColor: Colors.black,
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     textStyle: const TextStyle(
  //                       fontWeight: FontWeight.w800,
  //                       fontSize: 16,
  //                     ),
  //                   ),
  //                   onPressed: _submitting ? null : _placeOrder,
  //                   child:
  //                       _submitting
  //                           ? const SizedBox(
  //                             width: 22,
  //                             height: 22,
  //                             child: CircularProgressIndicator(
  //                               strokeWidth: 2,
  //                               color: Colors.black,
  //                             ),
  //                           )
  //                           : const Text('Place Order'),
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _RowTitle extends StatelessWidget {
  final String text;
  const _RowTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}

class _PaymentRow extends StatefulWidget {
  const _PaymentRow({super.key});

  @override
  State<_PaymentRow> createState() => _PaymentRowState();
}

class _PaymentRowState extends State<_PaymentRow> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Radio<String>(
              value: "COD",
              groupValue: _selectedPayment,
              onChanged: (value) {
                setState(() {
                  _selectedPayment = value!;
                });
              },
            ),
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Cash on Delivery',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
                fontSize: 16,
              ),
            ),
          ],
        ),

        //
        // Row(
        //   children: [
        //     Radio<String>(
        //       value: "JazzCash",
        //       groupValue: _selectedPayment,
        //       onChanged: (value) {
        //         setState(() {
        //           _selectedPayment = value!;
        //         });
        //       },
        //     ),
        //     const Icon(Icons.credit_card, color: Colors.green, size: 20),
        //     const SizedBox(width: 8),
        //     const Text(
        //       'Jazzcash',
        //       style: TextStyle(
        //         fontWeight: FontWeight.w600,
        //         color: Colors.green,
        //         fontSize: 16,
        //       ),
        //     ),
        //   ],
        // ),
        const SizedBox(height: 20),

        Text(
          "Selected Payment: $_selectedPayment",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _PromoField extends StatelessWidget {
  const _PromoField();

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Promo code',
              filled: true,
              fillColor: const Color(0xFFF6F6F6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kJmartYellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Promo applied')));
            },
            child: const Text(
              'Apply',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  final CartLine line;
  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              line.product.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              line.product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'x${line.qty}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Rs. ${line.lineTotal.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 15,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

class DeliveryZone {
  final int id;
  final String title;
  final String deliveryCharges;

  DeliveryZone({
    required this.id,
    required this.title,
    required this.deliveryCharges,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'],
      title: json['title'],
      deliveryCharges: json['deliverycharges'],
    );
  }
}
