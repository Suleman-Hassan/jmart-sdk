// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// class CustomTextField extends StatelessWidget {
//   final TextEditingController? controller;
//   final String? hintText;
//   final String? labelText;
//   final TextInputType? keyboardType;
//   final bool obscureText;
//   final Widget? prefixIcon;
//   final Widget? suffixIcon;
//   final String? Function(String?)? validator;
//   final void Function(String)? onChanged;
//   final List<TextInputFormatter>? inputFormatters;
//
//   const CustomTextField({
//     super.key,
//     this.controller,
//     this.hintText,
//     this.labelText,
//     this.keyboardType,
//     this.obscureText = false,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.validator,
//     this.onChanged,
//     this.inputFormatters,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return TextFormField(
//       controller: controller,
//       keyboardType: keyboardType,
//       obscureText: obscureText,
//       onChanged: onChanged,
//       validator: validator,
//       inputFormatters: inputFormatters, // <-- Important to include
//       decoration: InputDecoration(
//         hintText: hintText,
//         labelText: labelText,
//         prefixIcon: prefixIcon,
//         suffixIcon: suffixIcon,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }
// }
//


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  // ✅ NEW
  final bool enabled;          // enables/disables input
  final bool readOnly;         // optional, for date pickers etc.
  final TextInputAction? textInputAction;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.inputFormatters,

    // ✅ NEW defaults
    this.enabled = true,
    this.readOnly = false,
    this.textInputAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
      inputFormatters: inputFormatters,
      enabled: enabled,
      readOnly: readOnly,
      textInputAction: textInputAction,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
