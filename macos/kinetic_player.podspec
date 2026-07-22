#
Pod::Spec.new do |s|
  s.name             = 'kinetic_player'
  s.version          = '1.0.0'
  s.summary          = 'Dual-core video player: SGPlayer on macOS.'
  s.description      = <<-DESC
Flutter video player plugin. macOS uses wanwenfeng4798/SGPlayer master; Android uses GSYVideoPlayer 13.1.0.
SGPlayer.xcframework via SPM remote binaryTarget and/or `bash macos/scripts/spm_prebuild_hook.sh`.
                       DESC
  s.homepage         = 'https://github.com/wanwenfeng4798/kinetic_player'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'wanwenfeng4798' => 'https://github.com/wanwenfeng4798' }
  s.source           = { :path => '.' }
  s.osx.deployment_target = '11.0'
  s.swift_version    = '5.0'
  s.dependency       'FlutterMacOS'

  sgplayer_framework = '../darwin/Frameworks/macos/SGPlayer.xcframework'

  s.prepare_command = <<-CMD
    set -e
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    bash scripts/ensure_sgplayer.sh
  CMD

  s.vendored_frameworks = sgplayer_framework
  s.source_files = 'kinetic_player/Sources/**/*.{swift,h,m}', '../darwin/SgNativePlayerBridge/**/*.{h,m}', '../darwin/kinetic_player/Sources/SgPlayerKit/**/*.swift'
  s.public_header_files = '../darwin/SgNativePlayerBridge/include/*.h'
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'VideoToolbox', 'CoreMedia', 'Metal', 'MetalKit'
  s.libraries = 'iconv', 'bz2', 'z'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
end
