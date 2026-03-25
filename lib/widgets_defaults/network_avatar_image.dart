import 'package:flutter/material.dart';

import 'network_avatar_image_impl_stub.dart'
    if (dart.library.html) 'network_avatar_image_impl_web.dart'
    as impl;

class NetworkAvatarImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget fallback;

  const NetworkAvatarImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildNetworkAvatarImage(
      imageUrl: imageUrl,
      fit: fit,
      fallback: fallback,
    );
  }
}
