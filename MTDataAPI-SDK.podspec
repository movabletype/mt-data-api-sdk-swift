#
# Be sure to run `pod lib lint MyLibrary.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "MTDataAPI-SDK"
  s.version          = "1.0.3"
  s.summary          = "Movable Type Data API SDK for Swift."
  s.description      = <<-DESC
                       This is the SDK for Movable Type Data API. You can use/redistribute under the MIT license.

                       DESC
  s.homepage         = "https://github.com/movabletype/mt-data-api-sdk-swift"
  s.license          = 'MIT'
  s.author           = { "Six Apart" => "cocoapods@sixapart.com" }
  s.source           = { :git => "https://github.com/movabletype/mt-data-api-sdk-swift.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true
  s.ios.deployment_target = '8.0'

  s.source_files = 'SDK/**/*'

  s.dependency 'Alamofire'
  s.dependency 'SwiftyJSON'
end
