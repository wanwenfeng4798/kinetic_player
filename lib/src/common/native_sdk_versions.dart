/// Pinned native SDK versions for the dual-core player plugin.
abstract final class NativeSdkVersions {
  /// Android GSYVideoPlayer (Maven Central).
  static const String gsyVideoPlayer = '13.0.0';

  /// iOS libobjc/SGPlayer git branch (source builds).
  static const String sgPlayerBranch = 'master';

  /// iOS prebuilt binary manifest version (see ios/sgplayer_binary_manifest.json).
  static const String sgPlayerBinary = '1.0.0';
}
