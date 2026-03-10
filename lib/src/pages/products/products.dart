import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jmart_sdk/src/shared/widgets/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/utils/toast_utils.dart';
import '../authentication/login.dart';
import '../cart/cart_screen.dart';

const kJmartYellow = Color(0xFFFBC02D);

class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final bool isActive;
  final int maxQty;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    required this.maxQty,
  });
}

class ProductScreen extends StatefulWidget {
  final String title;
  final String? categoryId;
  final String? subcategoryId;

  const ProductScreen({
    super.key,
    required this.title,
    this.categoryId,
    this.subcategoryId,
  });

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  bool _isLoading = true;
  String? _error;
  bool _serverError = false;
  String? _serverErrorMsg;

  List<Product> _fetched = [];
  List<Product> get _items => _fetched;

  final Map<String, int> _cart = {};
  static const _cartKey = 'jmart_cart_v1';

  List<Map<String, dynamic>> _persistedCart = [];

  String _searchQuery = '';


  int get totalQty => _persistedCart.fold(0, (a, e) => a + (e['qty'] as int));
  double get totalPrice => _persistedCart.fold(
    0.0,
        (a, e) => a + (e['qty'] as int) * (e['price'] as double),
  );

  @override
  void initState() {
    super.initState();
    _loadPersistedCart();

    ToastUtil.checkToken(
      onValid: (decoded) => _fetchProducts(),
      onInvalid: () {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      },
    );
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  String _getCartKey(String email) => 'jmart_cart_${email.toLowerCase()}';

  Future<void> _loadPersistedCart() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) return;

    final cartKey = _getCartKey(email);
    final blob = prefs.getString(cartKey);
    if (blob == null || blob.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final List<dynamic> raw = jsonDecode(blob);
      _persistedCart = raw
          .map<Map<String, dynamic>>((e) {
        return {
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
      })
          .where((m) =>
      (m['productId'] as String).isNotEmpty &&
          (m['qty'] as int) > 0)
          .toList();

      _cart
        ..clear()
        ..addEntries(_persistedCart.map(
              (e) => MapEntry(e['productId'] as String, e['qty'] as int),
        ));
    } catch (_) {
      _persistedCart = [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _savePersistedCart() async {
    _persistedCart =
        _persistedCart.where((e) => (e['qty'] as int) > 0).toList();

    final prefs = await SharedPreferences.getInstance();
    final email = await _getUserEmail();
    if (email == null) return;

    final cartKey = _getCartKey(email);
    await prefs.setString(cartKey, jsonEncode(_persistedCart));
  }



  // Future<void> _loadPersistedCart() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final blob = prefs.getString(_cartKey);
  //   if (blob == null || blob.isEmpty) {
  //     if (mounted) setState(() {});
  //     return;
  //   }
  //   try {
  //     final List<dynamic> raw = jsonDecode(blob);
  //     _persistedCart = raw.map<Map<String, dynamic>>((e) {
  //       return {
  //         'productId': (e['productId'] ?? '').toString(),
  //         'title': (e['title'] ?? '').toString(),
  //         'imageUrl': (e['imageUrl'] ?? '').toString(),
  //         'price': (e['price'] is num)
  //             ? (e['price'] as num).toDouble()
  //             : double.tryParse('${e['price']}') ?? 0.0,
  //         'qty': (e['qty'] is num)
  //             ? (e['qty'] as num).toInt()
  //             : int.tryParse('${e['qty']}') ?? 0,
  //         'maxQty': (e['maxQty'] is num)
  //             ? (e['maxQty'] as num).toInt()
  //             : int.tryParse('${e['maxQty']}') ?? 999999, // persist cap
  //       };
  //     }).where((m) => (m['productId'] as String).isNotEmpty && (m['qty'] as int) > 0).toList();
  //
  //     _cart
  //       ..clear()
  //       ..addEntries(_persistedCart.map(
  //             (e) => MapEntry(e['productId'] as String, e['qty'] as int),
  //       ));
  //   } catch (_) {
  //     _persistedCart = [];
  //   }
  //   if (mounted) setState(() {});
  // }

  // Future<void> _savePersistedCart() async {
  //   _persistedCart = _persistedCart.where((e) => (e['qty'] as int) > 0).toList();
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString(_cartKey, jsonEncode(_persistedCart));
  // }

  void _upsertPersistedItem({
    required String productId,
    required String title,
    required String imageUrl,
    required double price,
    required int qty,
    required int maxQty,
  }) {
    final i = _persistedCart.indexWhere((e) => e['productId'] == productId);
    if (i == -1) {
      if (qty > 0) {
        _persistedCart.add({
          'productId': productId,
          'title': title,
          'imageUrl': imageUrl,
          'price': price,
          'qty': qty,
          'maxQty': maxQty,
        });
      }
    } else {
      if (qty > 0) {
        _persistedCart[i]['qty'] = qty;
        _persistedCart[i]['maxQty'] = maxQty;
      } else {
        _persistedCart.removeAt(i);
      }
    }
  }

  Future<Map<String, String?>> _getAuthTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access': prefs.getString('access_token'),
      'refresh': prefs.getString('refresh_token'),
    };
  }

  String _resolveImage(dynamic v) {
    if (v is! String) return '';
    final s = v.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    final path = s.startsWith('/') ? s : '/$s';
    return '$base$path';
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _serverError = false;
      _serverErrorMsg = null;
    });

    try {
      final tokens = await _getAuthTokens();
      final access = tokens['access'];
      if (access == null) {
        // Session missing -> go to login
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
      final qp = <String, dynamic>{
        if ((widget.categoryId ?? '').isNotEmpty) "category": widget.categoryId,
        if ((widget.subcategoryId ?? '').isNotEmpty) "subcategory": widget.subcategoryId,
      };

      final resp = await dio.get(
        ApiConstants.productsUrl,
        queryParameters: qp.isEmpty ? null : qp,
        options: Options(
          headers: {
            'Authorization': 'Bearer $access',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Handle by status code first
      final status = resp.statusCode ?? 0;

      if (status == 200) {
        final List list = (resp.data['products'] as List?) ?? const [];
        final mapped = list.map<Product>((raw) {
          final idStr = (raw['id']).toString();
          final title = (raw['title'] as String? ?? '').trim();
          final price = double.tryParse((raw['sell_price'] ?? '0').toString()) ?? 0.0;
          final statusStr = (raw['status'] ?? '').toString().toLowerCase();
          final isActive = statusStr == 'active';
          final img = _resolveImage(raw['image']);
          final int maxQty = int.tryParse((raw['max_qnty'] ?? '').toString()) ?? 999999;

          return Product(
            id: idStr,
            name: title.isEmpty ? 'Untitled' : title,
            price: price,
            imageUrl: (img.isEmpty ? 'https://picsum.photos/seed/prod_$idStr/300/300' : img),
            isActive: isActive,
            maxQty: maxQty,
          );
        }).toList();

        // mirror persisted qty into working map
        final newMap = <String, int>{};
        for (final e in _persistedCart) {
          newMap[e['productId'] as String] = e['qty'] as int;
        }

        if (!mounted) return;
        setState(() {
          _fetched = mapped;
          _cart
            ..clear()
            ..addAll(newMap);
          _isLoading = false;
          _error = mapped.isEmpty ? (resp.data['message'] ?? 'No products found.') : null;
          _serverError = false;
          _serverErrorMsg = null;
        });

        await _reconcileMaxLimits();
        return;
      }

      if (status == 500) {
        if (!mounted) return;
        setState(() {
          _serverError = true;
          _serverErrorMsg = 'Something went wrong';
          _isLoading = false;
        });
        return;
      }

      if ({400, 401, 402, 403, 404}.contains(status)) {
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
        _serverErrorMsg = 'HTTP $status';
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

      // no response / timeout / DNS etc.
      if (mounted) {
        setState(() {
          _serverError = true;
          _serverErrorMsg = e.message ?? 'Network error';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = true;
          _serverErrorMsg = 'Unexpected error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showLimitSnack(int maxQty) {
    _messengerKey.currentState?.hideCurrentSnackBar();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Max quantity per item is $maxQty'),
        duration: const Duration(seconds: 2),
      ),
    );
    ToastUtil.showError('Maximum $maxQty allowed for this item.');
  }

  void _showReachedSnack(int maxQty) {
    _messengerKey.currentState?.hideCurrentSnackBar();
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('You reached the maximum limit for this item.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reconcileMaxLimits() async {
    bool changed = false;
    final Map<String, int> maxById = {for (final p in _fetched) p.id: p.maxQty};

    for (final e in _persistedCart) {
      final pid = e['productId'] as String;
      final int qty = e['qty'] as int;
      final int? max = maxById[pid];

      if (max != null) {
        e['maxQty'] = max; // persist latest cap
        if (qty > max) {
          e['qty'] = max; // clamp
          changed = true;
          _cart[pid] = max;

          final title = (e['title'] as String?) ?? 'This item';
          _messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('$title quantity reduced to max $max'),
              duration: const Duration(seconds: 2),
            ),
          );
          ToastUtil.showError('$title max allowed is $max. Adjusted automatically.');
        }
      }
    }

    if (changed) {
      await _savePersistedCart();
      if (mounted) setState(() {});
    }
  }

  void _applyQty(Product p, int newQty) {
    final clamped = newQty.clamp(0, p.maxQty);
    setState(() {
      if (clamped == 0) {
        _cart.remove(p.id);
      } else {
        _cart[p.id] = clamped;
      }
    });

    _upsertPersistedItem(
      productId: p.id,
      title: p.name,
      imageUrl: p.imageUrl,
      price: p.price,
      qty: clamped,
      maxQty: p.maxQty,
    );
    _savePersistedCart();
  }

  void _add(Product p) {
    final cur = _cart[p.id] ?? 0;
    if (p.maxQty == 0) {
      _showLimitSnack(0);
      return;
    }
    if (cur >= p.maxQty) {
      _showLimitSnack(p.maxQty);
      return;
    }
    _applyQty(p, cur + 1);
    if ((_cart[p.id] ?? 0) == p.maxQty) _showReachedSnack(p.maxQty);
  }

  void _inc(Product p) {
    final cur = _cart[p.id] ?? 0;
    if (cur >= p.maxQty) {
      _showLimitSnack(p.maxQty);
      return;
    }
    _applyQty(p, cur + 1);
    if ((_cart[p.id] ?? 0) == p.maxQty) _showReachedSnack(p.maxQty);
  }

  void _dec(String id) {
    Product makeFallback(String pid) {
      final e = _persistedCart.firstWhere(
            (x) => x['productId'] == pid,
        orElse: () => {
          'title': 'Unknown',
          'price': 0.0,
          'imageUrl': '',
          'qty': 0,
          'maxQty': 999999,
        },
      );
      return Product(
        id: pid,
        name: (e['title'] as String?) ?? 'Unknown',
        price: (e['price'] as double?) ?? 0.0,
        imageUrl: (e['imageUrl'] as String?) ?? '',
        isActive: true,
        maxQty: (e['maxQty'] as int?) ?? 999999,
      );
    }

    final p = _items.firstWhere(
          (x) => x.id == id,
      orElse: () => makeFallback(id),
    );

    final q = (_cart[id] ?? 0) - 1;
    _applyQty(p, q < 0 ? 0 : q);
  }

  Future<void> _openCartThenRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
    await _loadPersistedCart();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(
          backgroundColor: kJmartYellow,
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.title,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.black),
                    onPressed: _openCartThenRefresh,
                  ),
                  if (totalQty > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalQty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search products...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),

        body: _isLoading
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        )
            : _serverError
            ? _ErrorView(
          message: '',
          onRetry: () async {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _serverError = false;
            });
            await _fetchProducts();
          },
        )
            : (_error != null)
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        )
            : (filteredItems.isEmpty)
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No products found.'),
          ),
        )
            : GridView.builder(
          padding:
          const EdgeInsets.fromLTRB(12, 12, 12, 120),
          itemCount: filteredItems.length,
          gridDelegate:
           SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
             mainAxisExtent:
             MediaQuery.of(context).size.height < 800
                 ? MediaQuery.of(context).size.height * 0.42
                 : MediaQuery.of(context).size.height * 0.40,
          ),
          itemBuilder: (_, i) {
            final p = filteredItems[i];
            final qty = _cart[p.id] ?? 0;
            return _ProductCard(
              product: p,
              qty: qty,
              maxReached: qty >= p.maxQty,
              onAdd: p.isActive ? () => _add(p) : () {},
              onInc: p.isActive ? () => _inc(p) : () {},
              onDec: p.isActive ? () => _dec(p.id) : () {},
            );
          },
        ),

        bottomNavigationBar: totalQty == 0
            ? null
            : SafeArea(
          minimum: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Material(
              color: kJmartYellow,
              child: InkWell(
                onTap: _openCartThenRefresh,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$totalQty',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Text(
                          'View Cart',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        'Rs ${totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
            CustomButton(
              onPressed: onRetry, text: 'Retry',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int qty;
  final bool maxReached;
  final VoidCallback onAdd;
  final VoidCallback onInc;
  final VoidCallback onDec;

  const _ProductCard({
    required this.product,
    required this.qty,
    required this.maxReached,
    required this.onAdd,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = !product.isActive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image (dim if inactive)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Opacity(
                  opacity: inactive ? 0.5 : 1.0,
                  child: Image.network(
                    product.imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                if (inactive)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Stock unavailable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),

          // Price
          Text(
            'Rs. ${product.price.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),

          // Optional hint about limit
          if (product.maxQty != 999999)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Max ${product.maxQty} per order',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),

          const Spacer(),

          // Counter only when active; else red label bar
          if (!inactive)
            (qty == 0
                ? _AddButton(onTap: onAdd)
                : _QtyPill(qty: qty, onInc: onInc, onDec: onDec, maxReached: maxReached))
          else
            Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                'Stock unavailable',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material( // ensure InkWell works fully
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: kJmartYellow,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final bool maxReached;

  const _QtyPill({
    required this.qty,
    required this.onInc,
    required this.onDec,
    required this.maxReached,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: kJmartYellow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconRoundButton(icon: Icons.remove, onTap: onDec),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
            Opacity(
              opacity: maxReached ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: maxReached,
                child: _IconRoundButton(icon: Icons.add, onTap: onInc),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconRoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Icon(icon, size: 18, color: Colors.black),
      ),
    );
  }
}
