// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "MathParser",
	platforms: [
		.macOS(.v15),
		.iOS(.v18),
	],
	products: [
		.library(
			name: "MathParser",
			targets: ["MathParser"]
		),
	],
	targets: [
		.target(
			name: "MathParser"
		),
		.testTarget(
			name: "MathParserTests",
			dependencies: ["MathParser"]
		),
		.executableTarget(
			name: "MathParserExe",
			dependencies: ["MathParser"]
		),

	],
	swiftLanguageModes: [.v6]
)
