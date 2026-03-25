import 'package:flutter/material.dart';

Widget buildNetworkAvatarImage({
  required String imageUrl,
  required BoxFit fit,
  required Widget fallback,
}) {
  if (imageUrl.trim().isEmpty) return fallback;

  return Image.network(
    imageUrl,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}
