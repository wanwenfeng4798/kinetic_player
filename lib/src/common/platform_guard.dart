import 'package:flutter/foundation.dart';

/// Throws when the current platform is not [TargetPlatform.android].
void assertAndroidPlatform(String feature) {
  if (defaultTargetPlatform != TargetPlatform.android) {
    throw UnsupportedError(
      '$feature is only supported on Android (GSYVideoPlayer).',
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

/// Throws when the current platform is neither Android nor iOS.
void assertSupportedMobilePlatform() {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    throw UnsupportedError(
      'This video player plugin only supports Android (GSY) and iOS (SGPlayer).',
    );
  }
}
