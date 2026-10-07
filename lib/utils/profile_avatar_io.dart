import 'dart:io';

import 'package:flutter/material.dart';

/// Mobile / desktop: load a local file path when present.
Widget buildProfileAvatarImage(String? path, {double size = 50}) {
  if (path != null && path.isNotEmpty) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _assetFallback(size),
        );
      }
    } catch (_) {
      // Fall through to asset.
    }
  }
  return _assetFallback(size);
}

Widget _assetFallback(double size) {
  return Image.asset(
    'assets/images/app_logo.png',
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Icon(
      Icons.person,
      color: Colors.white,
      size: size * 0.6,
    ),
  );
}
