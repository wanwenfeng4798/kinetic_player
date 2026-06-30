#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'kinetic_player'
  s.version          = '0.0.1'
  s.summary          = 'Dual-core video player: SGPlayer on iOS.'
  s.description      = <<-DESC
Flutter video player plugin. iOS uses libobjc/SGPlayer master; Android uses GSYVideoPlayer 13.0.0.
SGPlayer.xcframework is built on first `pod install` or `bash ios/scripts/build_sgplayer.sh` (30-60 min first run).
Shared artifact supports CocoaPods (vendored_frameworks) and Swift Package Manager (binaryTarget).
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.dependency       'Flutter'

  sgplayer_framework = 'Frameworks/SGPlayer.xcframework'

  s.prepare_command = <<-CMD
    set -e
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    if [ -d "#{sgplayer_framework}" ]; then
      echo "[kinetic_player] Using existing #{sgplayer_framework}"
    else
      echo "[kinetic_player] SGPlayer.xcframework not found - building automatically."
      echo "[kinetic_player] First run may take 30-60 minutes (FFmpeg + OpenSSL)."
      bash scripts/build_sgplayer.sh
    fi
  CMD

  s.vendored_frameworks = sgplayer_framework
  s.source_files = 'kinetic_player/Sources/**/*.{swift,h,m}'
  s.public_header_files = 'kinetic_player/Sources/SgNativePlayerBridge/include/*.h'
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'VideoToolbox', 'CoreMedia', 'Metal', 'MetalKit'
  s.libraries = 'iconv', 'bz2', 'z'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
