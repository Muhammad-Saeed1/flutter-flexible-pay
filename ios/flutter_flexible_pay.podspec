#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_flexible_pay.podspec` to validate before publishing.
#

pubspec = YAML.load_file(File.join('..', 'pubspec.yaml'))
libraryVersion = pubspec['version'].gsub('+', '-')

Pod::Spec.new do |s|
  s.name             = 'flutter_flexible_pay'
  s.version          = '0.0.3'
  s.summary          = 'Felxible payments for your business on flutter via Google Pay'
  s.description      = <<-DESC
Felxible payments for your business on flutter via Google Pay
                       DESC
  s.homepage         = 'https://github.com/olubunmitosin/flutter_flexible_pay'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Olubunmi Tosin' => 'olubunmivictor6@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Stripe'
  s.ios.deployment_target = '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
