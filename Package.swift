// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "RxResource",
	platforms: [
		.iOS(.v9),
	],
    products: [
        .library(
            name: "RxResource",
            targets: ["RxResource"]),
    ],
    dependencies: [
		.package(
			url: "https://github.com/ReactiveX/RxSwift.git",
			.upToNextMajor(from: "6.0.0")
		)
    ],
    targets: [
        .target(
            name: "RxResource",
			dependencies: [
				"RxSwift",
				.product(name: "RxCocoa", package: "RxSwift"),
			]),
        .testTarget(
            name: "RxResourceTests",
            dependencies: [
				"RxResource",
				"RxSwift",
				.product(name: "RxTest", package: "RxSwift"),
			]),
    ]
)
