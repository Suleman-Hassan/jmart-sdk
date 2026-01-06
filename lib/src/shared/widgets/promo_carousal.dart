import 'dart:async';
import 'package:flutter/material.dart';

class PromoCarousel extends StatefulWidget {
  final List<String> images; // asset or network paths; can be empty

  const PromoCarousel({super.key, required this.images});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _pageCtrl = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoIfPossible();
  }

  void _startAutoIfPossible() {
    _timer?.cancel();
    if (widget.images.length <= 1) return; // nothing to slide
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final next = (_index + 1) % widget.images.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _index = 0;
      _startAutoIfPossible();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard: empty list → render a small empty box instead of crashing
    if (widget.images.isEmpty) {
      return const SizedBox(height: 8);
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final img = widget.images[i];
                final isNetwork = img.startsWith('http');
                return isNetwork
                    ? Image.network(img, fit: BoxFit.cover)
                    : Image.asset(img, fit: BoxFit.cover);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.images.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 18 : 6,
              decoration: BoxDecoration(
                color: active ? Colors.black54 : Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }),
        ),
      ],
    );
  }
}
