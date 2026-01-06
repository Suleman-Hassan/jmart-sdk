import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/utils/toast_utils.dart';
import '../authentication/login.dart';
import '../authentication/signup.dart';
import '../categories/home_category.dart';
import '../checkout/checkout_screen.dart';

const kJmartYellow = Color(0xFFFBC02D);
const _cartKey = 'jmart_cart_v1';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  List<Map<String, dynamic>> _cart = [];
  double _subtotal = 0;

  @override
  void initState() {
    super.initState();
    _getUserEmail();
    _loadCart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCart();
  }


  // Future<void> _loadCart() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final blob = prefs.getString(_cartKey);
  //   if (blob == null || blob.isEmpty) {
  //     setState(() {
  //       _cart = [];
  //       _subtotal = 0;
  //     });
  //     return;
  //   }
  //
  //   bool changed = false;
  //
  //   try {
  //     final List<dynamic> raw = jsonDecode(blob);
  //     _cart =
  //         raw
  //             .map<Map<String, dynamic>>((e) {
  //               final m = <String, dynamic>{
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
  //                 'maxQty':
  //                     (e['maxQty'] is num)
  //                         ? (e['maxQty'] as num).toInt()
  //                         : int.tryParse('${e['maxQty']}') ?? 999999,
  //               };
  //
  //               final int q = m['qty'] as int;
  //               final int max = m['maxQty'] as int;
  //               if (q > max) {
  //                 m['qty'] = max;
  //                 changed = true;
  //               }
  //
  //               return m;
  //             })
  //             .where(
  //               (m) =>
  //                   (m['productId'] as String).isNotEmpty &&
  //                   (m['qty'] as int) > 0,
  //             )
  //             .toList();
  //   } catch (_) {
  //     _cart = [];
  //   }
  //
  //   if (changed) {
  //     await _saveCart();
  //     for (final e in _cart) {
  //       final int q = e['qty'] as int;
  //       final int max = e['maxQty'] as int;
  //       if (q == max) {
  //         final title = (e['title'] as String?) ?? 'This item';
  //         _showSnack('Adjusted $title quantity to max $max');
  //         ToastUtil.showError(
  //           '$title max allowed is $max. Adjusted automatically.',
  //         );
  //       }
  //     }
  //   }
  //
  //   _recalc();
  // }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();

    if (email == null) {
      setState(() {
        _cart = [];
        _subtotal = 0;
      });
      return;
    }

    final cartKey = _getCartKey(email);
    final blob = prefs.getString(cartKey);
    if (blob == null || blob.isEmpty) {
      setState(() {
        _cart = [];
        _subtotal = 0;
      });
      return;
    }

    bool changed = false;

    try {
      final List<dynamic> raw = jsonDecode(blob);
      _cart = raw
          .map<Map<String, dynamic>>((e) {
        final m = <String, dynamic>{
          'productId': (e['productId'] ?? '').toString(),
          'title': (e['title'] ?? '').toString(),
          'imageUrl': (e['imageUrl'] ?? '').toString(),
          'price': (e['price'] is num)
              ? (e['price'] as num).toDouble()
              : double.tryParse('${e['price']}') ?? 0.0,
          'qty': (e['qty'] is num)
              ? (e['qty'] as num).toInt()
              : int.tryParse('${e['qty']}') ?? 0,
          'maxQty': (e['maxQty'] is num)
              ? (e['maxQty'] as num).toInt()
              : int.tryParse('${e['maxQty']}') ?? 999999,
        };

        final int q = m['qty'] as int;
        final int max = m['maxQty'] as int;
        if (q > max) {
          m['qty'] = max;
          changed = true;
        }

        return m;
      })
          .where(
            (m) =>
        (m['productId'] as String).isNotEmpty &&
            (m['qty'] as int) > 0,
      )
          .toList();
    } catch (_) {
      _cart = [];
    }

    if (changed) {
      await _saveCart();
      for (final e in _cart) {
        final int q = e['qty'] as int;
        final int max = e['maxQty'] as int;
        if (q == max) {
          final title = (e['title'] as String?) ?? 'This item';
          _showSnack('Adjusted $title quantity to max $max');
          ToastUtil.showError(
            '$title max allowed is $max. Adjusted automatically.',
          );
        }
      }
    }

    _recalc();
  }


  String _getCartKey(String email) {
    return 'jmart_cart_${email.toLowerCase()}';
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }


  Future<void> _saveCart() async {
    _cart = _cart.where((e) => (e['qty'] as int) > 0).toList();
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) return;

    final cartKey = _getCartKey(email);
    await prefs.setString(cartKey, jsonEncode(_cart));
  }

//  Future<void> _saveCart() async {
//     _cart = _cart.where((e) => (e['qty'] as int) > 0).toList();
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_cartKey, jsonEncode(_cart));
//  }

  void _recalc() {
    _subtotal = _cart.fold(
      0.0,
      (a, e) => a + (e['qty'] as int) * (e['price'] as double),
    );
    setState(() {});
  }

  void _showSnack(String msg) {
    _messengerKey.currentState?.hideCurrentSnackBar();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showLimit(int max) {
    _showSnack('Max quantity per item is $max');
    ToastUtil.showError('Maximum $max allowed for this item.');
  }

  void _showReached(int max) {
    _showSnack('You reached the maximum limit for this item.');
    //  ToastUtil.showError('You reached the maximum ($max).');
  }

  Future<void> _inc(int idx) async {
    final int cur = (_cart[idx]['qty'] as int);
    final int max = (_cart[idx]['maxQty'] as int?) ?? 999999;

    if (cur >= max) {
      _showLimit(max);
      return;
    }

    _cart[idx]['qty'] = cur + 1;
    await _saveCart();
    _recalc();

    if ((_cart[idx]['qty'] as int) == max) {
      _showReached(max);
    }
  }

  Future<void> _dec(int idx) async {
    final q = (_cart[idx]['qty'] as int) - 1;
    if (q <= 0) {
      _cart.removeAt(idx);
    } else {
      _cart[idx]['qty'] = q;
    }
    await _saveCart();
    _recalc();

    if (_cart.isEmpty && mounted) {
      Navigator.pop(context, true);
    }
  }

  int get totalQty => _cart.fold(0, (a, e) => a + (e['qty'] as int));

  List<CartLine> _buildCartLines() {
    final List<CartLine> lines = [];
    for (final e in _cart) {
      final q = e['qty'] as int;
      if (q > 0) {
        lines.add(
          CartLine(
            product: Products(
              id: e['productId'] as String,
              name: e['title'] as String,
              price: e['price'] as double,
              imageUrl: e['imageUrl'] as String,
            ),
            qty: q,
          ),
        );
      }
    }
    return lines;
  }


  Future<void> checkGuestFlow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final guestEmail = prefs.getString('user_email');//guest

    if (guestEmail != null && guestEmail == 'guest@gmail.com') {
      await showDialog(
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
                  const Icon(Icons.person, color: kJmartYellow, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    "Continue as Guest?",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                        "Would you like to continue as guest or create a full account?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kJmartYellow,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignUpScreen()),
                            );
                          },
                          child: FittedBox(
                            child: const Text("Create Account",style: TextStyle(color: Colors.black)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(
          backgroundColor: kJmartYellow,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Cart',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body:
            _cart.isEmpty
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Your cart is empty.'),
                  ),
                )
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final e = _cart[i];
                    final title = e['title'] as String;
                    final image = (e['imageUrl'] as String?) ?? '';
                    final price = e['price'] as double;
                    final qty = e['qty'] as int;
                    final maxQty = (e['maxQty'] as int?) ?? 999999;
                    final lineTotal = (qty * price).toStringAsFixed(0);
                    final maxReached = qty >= maxQty;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(blurRadius: 6, color: Color(0x14000000)),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              image,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: const Color(0xFFF3F4F6),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs. ${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (maxQty != 999999) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Max $maxQty per order',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _QtyButton(
                                      icon: Icons.remove,
                                      onTap: () => _dec(i),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Opacity(
                                      opacity: maxReached ? 0.4 : 1.0,
                                      child: IgnorePointer(
                                        ignoring: maxReached,
                                        child: _QtyButton(
                                          icon: Icons.add,
                                          onTap: () => _inc(i),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Rs. $lineTotal',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        bottomNavigationBar:
            _cart.isEmpty
                ? null
                : SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: kJmartYellow,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$totalQty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Subtotal',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              'Rs. ${_subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final lines = _buildCartLines();
                                final guestEmail =
                                    await ToastUtil.getGuestEmail();
                                if (guestEmail != null && guestEmail == "guest@gmail.com") {
                                  print("Guest email: $guestEmail");
                                  checkGuestFlow(context);
                                } else {
                                  print("No guest email found");
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => CheckoutScreen(
                                        lines: lines,
                                        deliveryFee: 0,
                                        discount: 0,
                                      ),
                                    ),
                                  );
                                }

                              },
                              child: const Text('Proceed'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
