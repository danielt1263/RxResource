Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  spec.name          = "RxResource"
  spec.version       = "0.2.0"
  spec.summary       = "Easily create resources for use with the Observable.using(_:observableFactory:) operator."

  spec.description   = <<-DESC
  Manage resources the RxSwift way with this simple template. The package also includes several example resources that are ready for use in your projects.
                   DESC

  spec.homepage      = "https://github.com/danielt1263/RxResource"
  spec.license       = "MIT"
  spec.author        = { "Daniel Tartaglia" => "danielt1263@gmail.com" }
  spec.platform      = :ios, "9.0"
  spec.source        = { :git => "https://github.com/danielt1263/RxResource.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/RxResource/*.swift"
  spec.exclude_files = "Classes/Exclude"
  spec.dependency "RxCocoa", "~> 6.0"
  spec.dependency "RxSwift", "~> 6.0"
  spec.swift_version = '5.5'

end
