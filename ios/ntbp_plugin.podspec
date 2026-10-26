#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ntbp_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ntbp_plugin'
  s.version          = '3.0.0'
  s.summary          = 'Thermal Bluetooth label printing for TSPL printers (Xprinter XP-420B, N41).'
  s.description      = <<-DESC
Flutter plugin for thermal Bluetooth label printing. Renders label layouts to
TSPL and transports them through the Xprinter iOS PrinterSDK over BLE.
                       DESC
  s.homepage         = 'https://github.com/NewtonCB/ntbp_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'NTBP' => 'mobile@otapp.net' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{swift,h,m}'
  s.public_header_files = 'Classes/ntbp_plugin.h', 'Classes/PrinterSDK/*.h'

  # Xprinter PrinterSDK (Objective-C static library). Device slices only
  # (arm64); the simulator is x86_64 only, so Apple-silicon simulators need
  # Rosetta. Real devices are unaffected.
  s.vendored_libraries = 'Libraries/libPrinterSDK.a'
  s.preserve_paths   = 'Libraries/libPrinterSDK.a'
  s.frameworks       = 'Foundation', 'UIKit', 'CoreBluetooth', 'ExternalAccessory', 'CFNetwork'
  s.libraries        = 'z'

  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-ObjC',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64 i386',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER' => 'NO'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64 i386'
  }
  s.swift_version = '5.0'

  s.resource_bundles = {'ntbp_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
