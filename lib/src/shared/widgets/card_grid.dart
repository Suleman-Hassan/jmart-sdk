import 'package:flutter/material.dart';
import 'package:jmart_sdk/src/shared/widgets/search_bar.dart';
import 'home_card.dart';

class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.items, this.onItemTap});
  final List<HomeItem> items;
  final void Function(HomeItem)? onItemTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (context, index) => CategoryCard(
        item: items[index],
        onTap: onItemTap == null ? null : () => onItemTap!(items[index]),
      ),
    );
  }
}