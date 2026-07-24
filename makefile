ROOT_FOLDER:=Sources

SOURCES:=$(shell find $(ROOT_FOLDER) -iname "*.swift")

buildServer.json: KMeans.xcodeproj
	xcode-build-server config -project *.xcodeproj

KMeans.xcodeproj: project.yml
	xcodegen generate

KMeans.app: .build/Build/Products/Debug/KMeans.app .build/Build/Products/Release/KMeans.app
	cp -r $< $@

.build/Build/Products/Debug/KMeans.app: $(SOURCES) KMeans.xcodeproj
	xcodebuild \
		-project KMeans.xcodeproj \
		-scheme KMeans_macOS \
		-configuration Debug \
		-destination "platform=macOS" \
		-derivedDataPath .build

.build/Build/Products/Release/KMeans.app: $(SOURCES) KMeans.xcodeproj
	xcodebuild \
		-project KMeans.xcodeproj \
		-scheme KMeans_macOS \
		-configuration Release \
		-destination "platform=macOS" \
		-derivedDataPath .build

.PHONY release: .build/Build/Products/Release/KMeans.app
.PHONY build: .build/Build/Products/Release/KMeans.app

