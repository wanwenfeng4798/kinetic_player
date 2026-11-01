import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_player/src/common/kinetic_image_provider_io.dart';

void main() {
  test('local covers and watermarks support Windows paths and file URIs', () {
    for (final path in [
      r'C:\Users\demo\watermark.png',
      'D:/Media/cover.png',
      r'\\server\media\cover.png',
      '/tmp/cover.png',
    ]) {
      final provider = kineticImageProvider(path);
      expect(provider, isA<FileImage>(), reason: path);
      expect((provider as FileImage).file.path, path);
    }
    expect(kineticImageProvider('file:///tmp/cover.png'), isA<FileImage>());
    expect(
      kineticImageProvider('https://example.com/cover.png'),
      isA<NetworkImage>(),
    );
  });
}
