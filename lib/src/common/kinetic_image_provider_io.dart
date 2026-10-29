import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider<Object> kineticImageProvider(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.scheme == 'file') return FileImage(File.fromUri(uri));
  if (url.startsWith('/')) return FileImage(File(url));
  return NetworkImage(url);
}
