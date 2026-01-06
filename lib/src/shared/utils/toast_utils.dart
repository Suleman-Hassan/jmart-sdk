import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ToastUtil {
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      gravity: ToastGravity.BOTTOM,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      gravity: ToastGravity.BOTTOM,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  static void showCustomBottomSheet(
      BuildContext context,
      String message, {
        IconData icon = Icons.error,
        Color iconColor = Colors.red,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8, // max 80% screen
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 120, color: iconColor),
                SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("OK", style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );

      },
    );
  }

  static Future<String?> getGuestEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');//guest
  }

  static Future<Map<String, dynamic>?> decodeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    if (token != null && token.isNotEmpty) {
      if (!JwtDecoder.isExpired(token)) {
        return JwtDecoder.decode(token);
      } else {
        debugPrint("Token is expired");
      }
    }
    return null;
  }

  static Future<void> checkToken({
    Function(Map<String, dynamic>)? onValid,
    Function()? onInvalid,
  }) async {
    Map<String, dynamic>? decodedToken = await decodeToken();
    if (decodedToken != null) {
      debugPrint("Token payload: $decodedToken");
      if (onValid != null) onValid(decodedToken);
    } else {
      debugPrint("Invalid or expired token.");
      if (onInvalid != null) onInvalid();
    }
  }

}
