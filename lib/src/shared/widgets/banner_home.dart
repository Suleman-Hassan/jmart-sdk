import 'dart:async';
import 'package:flutter/material.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    this.aspectRatio = 16 / 9,
    this.radius = 32,
    this.interval = const Duration(seconds: 3),
  });

  final List<String> banners;
  final double aspectRatio;
  final double radius;
  final Duration interval;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || widget.banners.isEmpty) return;
      final next = (_current + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.banners.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: Image.network(
                    widget.banners[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.broken_image));
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.banners.length, (i) {
                    final active = i == _current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: active ? 18 : 8,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
