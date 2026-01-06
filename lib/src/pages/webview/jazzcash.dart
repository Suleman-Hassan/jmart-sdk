import 'package:dio/dio.dart';

class JazzCashService {
  static String? lastResponseCode;
  static String? responseMessage;
  static Map<String, String?>? lastFullResponse;

  static Future<Map<String, String?>> makeTransaction({
    required String paymentUrl,
    required Map<String, dynamic> postData,
  }) async {
    try {
      final dio = Dio();

      final resp = await dio.post(
        paymentUrl,
        data: postData,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        final responseCode = data["pp_ResponseCode"]?.toString() ?? "N/A";
        final responsemsg = data["pp_ResponseMessage"]?.toString() ?? "N/A";
        final data1 = Map<String, dynamic>.from(resp.data);

        final converted = data1.map((key, value) => MapEntry(key, value?.toString()));

        lastFullResponse = converted;

        lastResponseCode = responseCode;
        responseMessage = responsemsg;

        return {
          "responseCode": responseCode,
          "responseMessage": responsemsg,
        };
      } else {
        print("JazzCash error: ${resp.statusCode}");
        return {
          "responseCode": "error",
          "responseMessage": "HTTP Error ${resp.statusCode}",
        };
      }
    } catch (e) {
      print("JazzCash exception: $e");
      return {
        "responseCode": "exception",
        "responseMessage": "Exception: $e",
      };
    }
  }

}
