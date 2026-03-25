// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final Set<String> _registeredFactories = <String>{};

Widget buildNetworkAvatarImage({
  required String imageUrl,
  required BoxFit fit,
  required Widget fallback,
}) {
  final normalized = imageUrl.trim();
  if (normalized.isEmpty) return fallback;

  final encoded = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  final viewType = 'network-avatar-$encoded';

  if (!_registeredFactories.contains(viewType)) {
    _registeredFactories.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final image = html.ImageElement()
        ..src = normalized
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = _toCssObjectFit(fit)
        ..style.display = 'block'
        ..style.pointerEvents = 'none';

      image.draggable = false;
      image.referrerPolicy = 'no-referrer';
      return image;
    });
  }

  return HtmlElementView(viewType: viewType);
}

String _toCssObjectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.fitWidth:
      return 'scale-down';
    case BoxFit.fitHeight:
      return 'scale-down';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.cover:
      return 'cover';
  }
}
