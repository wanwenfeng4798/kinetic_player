/// Pinned native SDK versions for the dual-core player plugin.
abstract final class NativeSdkVersions {
  /// Android GSYVideoPlayer (Maven Central).
  static const String gsyVideoPlayer = '13.1.0';

  /// iOS SGPlayer git branch (source builds).
  static const String sgPlayerBranch = 'master';

  /// SGPlayer source repository (see darwin/sgplayer/manifest.*.json).
  static const String sgPlayerRepository =
      'https://github.com/wanwenfeng4798/SGPlayer';

  /// iOS / macOS prebuilt binary manifest version (see darwin/sgplayer/manifest.*.json).
  static const String sgPlayerBinary = '1.0.0';

  /// macOS prebuilt binary manifest version.
  static const String sgPlayerBinaryMacOS = '1.0.0';
}
