import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final String ratting;

  const RatingStars({
    super.key,
    required this.ratting,
  });

  @override
  Widget build(BuildContext context) {
    final double rating = double.tryParse(ratting) ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.star_rounded,
          color: Color(0xFFF59E0B),
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
