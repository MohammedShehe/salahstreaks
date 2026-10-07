import 'package:flutter/material.dart';

/// Web: local file paths are not available — always use the asset logo.
Widget buildProfileAvatarImage(String? path, {double size = 50}) {
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
