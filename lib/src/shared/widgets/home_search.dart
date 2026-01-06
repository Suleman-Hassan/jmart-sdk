import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  final String hintText;
  final VoidCallback? onTap;

  const AppSearchBar({
    super.key,
    required this.hintText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF1),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.black38),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hintText,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
