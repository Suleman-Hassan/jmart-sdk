import 'package:flutter/material.dart';


class HomeItem {
  final String title;
  final IconData icon;
  const HomeItem({required this.title, required this.icon});
}

class JSearchBar extends StatelessWidget {
  const JSearchBar({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Search ...',
  });


  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(30),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}