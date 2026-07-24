ROOT_FOLDER:=Sources

SOURCES:=$(shell find $(ROOT_FOLDER) -iname "*.swift")

buildServer.json: GraphingCalculator.xcodeproj
	xcode-build-server config -project *.xcodeproj

GraphingCalculator.xcodeproj: project.yml
	xcodegen generate

.build/Build/Products/Debug/GraphingCalculator.app: $(SOURCES) GraphingCalculator.xcodeproj
	xcodebuild \
		-project GraphingCalculator.xcodeproj \
		-scheme GraphingCalculator_macOS \
		-configuration Debug \
		-destination "platform=macOS" \
		-derivedDataPath .build

.build/Build/Products/Release/GraphingCalculator.app: $(SOURCES) GraphingCalculator.xcodeproj
	xcodebuild \
		-project GraphingCalculator.xcodeproj \
		-scheme GraphingCalculator_macOS \
		-configuration Release \
		-destination "platform=macOS" \
		-derivedDataPath .build

.PHONY release: .build/Build/Products/Release/GraphingCalculator.app
.PHONY build: .build/Build/Products/Release/GraphingCalculator.app

