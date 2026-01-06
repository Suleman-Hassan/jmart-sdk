import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jmart_sdk/src/core/constants/api_constants.dart';
import 'package:jmart_sdk/src/pages/track_order/track_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../categories/home_category.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final String apiUrl = ApiConstants.orderHistoryURL;

  String? accessToken;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );

  final TextEditingController _search = TextEditingController();
  String _status = '';
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _visible = [];
  final Set<String> _expanded = {};
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  String? _apiMessage;
  bool _apiStatus = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _applyFilters);
  }

  Future<Map<String, String?>> getAuthTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access': prefs.getString('access_token'),
      'refresh': prefs.getString('refresh_token'),
    };
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _apiMessage = null;
    });

    try {
      final tokenMap = await getAuthTokens();
      final at = tokenMap['access'];
      if (at == null || at.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Authentication required: access token missing.';
        });
        return;
      }
      accessToken = at;

      final res = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            "Authorization": "Bearer $accessToken",
            "Accept": "application/json",
          },
        ),
      );

      final json =
          res.data is String
              ? jsonDecode(res.data)
              : Map<String, dynamic>.from(res.data);

      _apiStatus = json['status'] == true;
      _apiMessage = json['message']?.toString();

      if (!_apiStatus) {
        _orders = [];
        _visible = [];
      } else {
        final List data = json['data'] ?? [];
        _orders =
            data
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
        _orders.sort(
          (a, b) => DateTime.parse(
            b['created_at'],
          ).compareTo(DateTime.parse(a['created_at'])),
        );
        _applyFilters();
      }
    } catch (e) {
      _error = 'Failed to fetch orders: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _visible =
          _orders.where((o) {
            final st = (o['status'] ?? '').toString().toLowerCase();
            final matchesStatus = _status.isEmpty || st == _status;
            if (!matchesStatus) return false;

            if (q.isEmpty) return true;
            final orderNo = (o['order_no'] ?? '').toString().toLowerCase();
            final total = (o['grand_total'] ?? '').toString().toLowerCase();
            final created = (o['created_at'] ?? '').toString().toLowerCase();
            final items = (o['items'] as List? ?? [])
                .map(
                  (it) =>
                      (it['product_detail']?['name'] ?? '')
                          .toString()
                          .toLowerCase(),
                )
                .join(' ');
            return ('$orderNo $total $created $items').contains(q);
          }).toList();
    });
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'delivered':
        return const Color(0xFF137333);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFB3261E);
      default:
        return const Color(0xFF8E5B00);
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'delivered':
        return const Color(0xFFE7F6EC);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFFDE7E9);
      default:
        return const Color(0xFFFFF7E6);
    }
  }

  String _titleCase(String s) => s
      .split(RegExp(r'\s+|_'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy • hh:mm a');
    final money = NumberFormat.decimalPattern();

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 42),
              const SizedBox(height: 12),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _fetch, child: const Text('Retry'),),
            ],
          ),
        ),
      );
    } else if (!_apiStatus) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _apiMessage ?? 'No orders available',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _fetch,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Search orders, items, totals…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final entry
                              in {
                                '': 'All',
                                'pending': 'Pending',
                                'delivered': 'Delivered',
                                'cancelled': 'Cancelled',
                              }.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(entry.value),
                                selected: _status == entry.key,
                                onSelected: (_) {
                                  setState(() => _status = entry.key);
                                  _applyFilters();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No orders found')),
              )
            else
              SliverList.builder(
                itemCount: _visible.length,
                itemBuilder: (_, i) {
                  final o = _visible[i];
                  final orderNo = (o['order_no'] ?? '').toString();
                  final address = (o['address'] ?? '').toString();
                  final status = (o['status'] ?? '').toString().toLowerCase();
                  final phone = (o['phone'] ?? '').toString();
                  final isCancelled = const {
                    'cancelled',
                    'canceled',
                    'cancel',
                  }.contains(status);

                  final createdAt =
                      DateTime.tryParse(
                        (o['created_at'] ?? '').toString(),
                      )?.toLocal();
                  final total =
                      double.tryParse((o['grand_total'] ?? '0').toString()) ??
                      0;
                  final items = (o['items'] as List? ?? []);
                  final expanded = _expanded.contains(orderNo);

                  return Card(
                    elevation: 10,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order No: $orderNo',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: _statusBg(status),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _statusFg(status).withOpacity(.25),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  _titleCase(status),
                                  style: TextStyle(
                                    color: _statusFg(status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),
                          if (phone.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Phone Number: $phone',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 6),

                          if (address.isNotEmpty)
                            expanded
                                ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          address,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: Colors.black87,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          address,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: Colors.black87,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          const SizedBox(height: 10),
                          Text(
                            createdAt != null ? df.format(createdAt) : '',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),
                          if (!expanded)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final it in items.take(2))
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '• ${(it['product_detail']?['name'] ?? '')}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'x${it['product_detail']?['quantity'] ?? 0} • PKR ${(it['product_detail']?['price'] ?? 0).toStringAsFixed(0)}',
                                      ),
                                    ],
                                  ),
                                if (items.length > 2)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+ ${items.length - 2} more',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                for (final it in items)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '• ${it['product_detail']?['name'] ?? ''}',
                                        ),
                                      ),
                                      Text(
                                        'x${it['product_detail']?['quantity'] ?? 0} • PKR ${(it['product_detail']?['price'] ?? 0).toStringAsFixed(0)}',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                expanded
                                    ? _expanded.remove(orderNo)
                                    : _expanded.add(orderNo);
                              });
                            },
                            icon: Icon(
                              expanded ? Icons.expand_less : Icons.expand_more,
                            ),
                            label: Text(expanded ? 'Hide items' : 'View items'),
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total: PKR ${money.format(total)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!isCancelled)
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => TrackOrder(
                                              orderNo: orderNo,
                                              token: accessToken,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text('View Details'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBC02D),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Order History',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeCategoriesScreen()),
                (_) => false,
              ),
        ),
      ),
      body: body,
      backgroundColor: const Color(0xFFF8FAFC),
    );
  }
}
