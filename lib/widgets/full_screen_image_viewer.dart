import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildZoomableImage(String url) {
    Widget imageWidget;
    if (url.startsWith('http')) {
      imageWidget = Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: kTextDim, size: 60),
        ),
      );
    } else {
      try {
        imageWidget = Image.memory(
          base64Decode(url),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: kTextDim, size: 60),
          ),
        );
      } catch (_) {
        imageWidget = const Center(
          child: Icon(Icons.broken_image, color: kTextDim, size: 60),
        );
      }
    }

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      clipBehavior: Clip.none,
      child: Center(child: imageWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1} of ${widget.imageUrls.length}",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return _buildZoomableImage(widget.imageUrls[index]);
            },
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.imageUrls.asMap().entries.map((entry) {
                  return Container(
                    width: _currentIndex == entry.key ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: _currentIndex == entry.key ? Colors.white : Colors.white38,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
