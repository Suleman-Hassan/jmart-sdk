import 'package:flutter/material.dart';
// import 'package:cool_alert/cool_alert.dart';
import '../../core/constants/app_colors.dart';

class CustomAlerts {
  static void showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmBtnText = 'Yes',
    String cancelBtnText = 'No',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    Color? backgroundColor,
    Color? confirmBtnColor,
    TextStyle? titleTextStyle,
    TextStyle? textTextStyle,
    TextStyle? confirmBtnTextStyle,
    TextStyle? cancelBtnTextStyle,
  }) {
    AlertDialog(
      // context: context,
      // type: CoolAlertType.confirm,
      title: Text(title),
      // text: message,
      backgroundColor: backgroundColor ?? AppColors.alertBg,
      // confirmBtnColor: confirmBtnColor ?? AppColors.alertBg,
      // confirmBtnText: confirmBtnText,
      // cancelBtnText: cancelBtnText,
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onConfirm != null) onConfirm();
            },
            child: Text(
              confirmBtnText,
              style: TextStyle(
                fontFamily: 'Dosis',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )),
        TextButton(
            onPressed: () {
              // Navigator.pop(context);
              if (onCancel != null) onCancel();
            },
            child: Text(
              cancelBtnText,
              style: TextStyle(
                fontFamily: 'Dosis',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.alertBg,
              ),
            )),
      ],
      // onConfirmBtnTap:
      // onCancelBtnTap:
      titleTextStyle: titleTextStyle ??
          const TextStyle(
            fontFamily: 'Dosis',
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
      // textTextStyle: textTextStyle ??
      //     const TextStyle(
      //       fontSize: 16,
      //       color: Colors.black54,
      //     ),
      // confirmBtnTextStyle: confirmBtnTextStyle ??
      //     const TextStyle(
      //       fontFamily: 'Dosis',
      //       fontSize: 16,
      //       fontWeight: FontWeight.bold,
      //       color: Colors.white,
      //     ),
      // cancelBtnTextStyle: cancelBtnTextStyle ??
      //     const TextStyle(
      //       fontFamily: 'Dosis',
      //       fontSize: 16,
      //       fontWeight: FontWeight.bold,
      //       color: AppColors.alertBg,
      //     ),
    );
  }
}
