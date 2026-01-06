import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jmart_sdk/src/core/constants/api_constants.dart';

class TrackOrder extends StatefulWidget {
  const TrackOrder({
    super.key,
    required this.orderNo,
    this.token,
  });

  final String orderNo;
  final String? token;

  @override
  State<TrackOrder> createState() => _TrackOrderState();
}

class _TrackOrderState extends State<TrackOrder> {
  static const String _baseUrl = ApiConstants.orderTrackURL;
      //'https://jmart.dhai-r.com.pk/api/v1/orders/track-status/';

  final Dio _dio = Dio();
  bool _loading = true;
  String? _error;
  bool _apiStatus = true;
  String? _apiMessage;

  Map<String, dynamic>? _steps;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _apiMessage = null;
      _apiStatus = true;
    });

    try {
      final res = await _dio.get(
        _baseUrl,
        queryParameters: {'order_no': widget.orderNo},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${widget.token ?? ""}',
            'Accept': 'application/json',
          },
        ),
      );

      final data = res.data is String
          ? jsonDecode(res.data)
          : Map<String, dynamic>.from(res.data);

      _apiStatus = data['status'] == true;
      _apiMessage = data['message']?.toString();
      _steps = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'])
          : null;
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  IconData _iconFor(String name) {
    switch (name.toLowerCase()) {
      case 'pending':
        return Icons.shopping_cart;
      case 'processing':
        return Icons.store;
      case 'shipped':
      case 'in_transit':
      case 'dispatch':
      case 'dispatched':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.thumb_up;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel;
      default:
        return Icons.flag;
    }
  }

  String _titleCase(String s) =>
      s.split(RegExp(r'[\s_-]+')).map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool done,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: done ? Colors.yellow[700] : Colors.grey.shade300,
          child: Icon(done ? Icons.check : icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: done ? Colors.yellow[700] : Colors.grey,
                    fontSize: 16,
                  )),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line() => Container(
    margin: const EdgeInsets.only(left: 20),
    height: 30,
    width: 2,
    color: Colors.orange,
  );

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (!_apiStatus) {
      body = Center(child: Text(_apiMessage ?? 'Order not found'));
    } else if (_steps == null) {
      body = const Center(child: Text('No tracking data available'));
    } else {
      final orderNo = _steps!['order_no']?.toString() ?? '';
      final current = _steps!['current_status']?.toString() ?? '';
      final List statuses = _steps!['statuses'] as List? ?? [];

      // Build dynamic steps from the array
      final widgets = <Widget>[
        // Optional header showing order and current status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Order #$orderNo',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (current.isNotEmpty)
              Text(_titleCase(current), style: const TextStyle(color: Colors.green)),
          ],
        ),
        const SizedBox(height: 16),
      ];

      // Iterate statuses and render
      for (int i = 0; i < statuses.length; i++) {
        final s = statuses[i] as Map<String, dynamic>;
        final name = (s['name'] ?? '').toString();
        final done = s['status'] == true;

        widgets.add(_buildStep(
          icon: _iconFor(name),
          title: _titleCase(name),
          // You can inject per-step timestamps/notes here if backend adds them later:
          subtitle: done ? 'Completed' : 'Pending',
          done: done,
        ));

        if (i != statuses.length - 1) {
          widgets.add(_line());
        }
      }

      body = Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Track Order"),
        backgroundColor: Colors.yellow[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: body,
    );
  }
}
