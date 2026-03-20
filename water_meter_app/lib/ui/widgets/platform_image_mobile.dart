import 'dart:io' as io;
import 'package:flutter/material.dart';

class PlatformImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const PlatformImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(io.File(path), fit: fit);
  }
}
