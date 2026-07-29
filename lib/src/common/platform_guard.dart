import 'package:flutter/foundation.dart';

/// Throws when the current platform is not [TargetPlatform.android].
void assertAndroidPlatform(String feature) {
  if (defaultTargetPlatform != TargetPlatform.android) {
    throw UnsupportedError(
      '$feature is only supported on Android (GSYVideoPlayer).',
    );
  }
}

/// Throws when the current platform is not Apple SGPlayer (iOS / macOS).
void assertAppleSgPlatform(String feature) {
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    throw UnsupportedError(
      '$feature is only supported on iOS/macOS (SGPlayer).',
    );
  }
}

/// Throws when the current platform is not [TargetPlatform.iOS].
void assertIosPlatform(String feature) {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    throw UnsupportedError(
      '$feature is only supported on iOS (SGPlayer).',
    );
  }
}

/// Throws when the current platform is not Flutter Web.
void assertWebPlatform(String feature) {
  if (!kIsWeb) {
    throw UnsupportedError(
      '$feature is only supported on Flutter Web (Artplayer).',
    );
  }
}

/// Throws when the current platform is not a supported player platform.
void assertSupportedPlayerPlatform() {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    throw UnsupportedError(
      'This video player plugin supports Android (GSY), iOS/macOS (SGPlayer), and Web (Artplayer).',
    );
  }
}

/// @deprecated Use [assertSupportedPlayerPlatform].
void assertSupportedMobilePlatform() => assertSupportedPlayerPlatform();
