import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class ImageSlider extends StatelessWidget {
  final List<String> images;

  const ImageSlider({Key? key, required this.images}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 180,
        enlargeCenterPage: true,
        enableInfiniteScroll: false,
      ),
      items: images.map((image) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            image,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        );
      }).toList(),
    );
  }
}
