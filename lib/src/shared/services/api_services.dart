import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: Duration(seconds: 60),
      receiveTimeout: Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  Future<Response> post(String endpoint, {Map<String, dynamic>? data}) async {
    try {
      final String rawJson = jsonEncode(data);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token') ;
      if (token == "" || token == null) {
        token = "";
      }
      final response = await _dio.post(
        endpoint,
        data: rawJson,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
        ),
      );

      return response;
    } catch (e) {
      if (e is DioError) {
        if (e.response != null) {
          print("Error occurred: ${e.response?.data}");
          if (e.response?.data is Map) {
            String message = e.response?.data['message'] ?? 'Unknown error';
            throw Exception('Error: $message');
          } else {
            throw Exception('Error: ${e.response?.statusMessage}');
          }
        } else {
          throw Exception('Failed to post data: ${e.message}');
        }
      } else {
        throw Exception('Failed to post data: $e');
      }
    }
  }

  Future<Response> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      return response;
    } catch (e) {
      rethrow;
    }
  }

}

