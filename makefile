ROOT_FOLDER:=Sources

NAME:=GraphingCalculator

SOURCES:=$(shell find $(ROOT_FOLDER) -iname "*.swift")

buildServer.json: $(NAME).xcodeproj
	xcode-build-server config -project *.xcodeproj

$(NAME).xcodeproj: project.yml
	xcodegen generate

.build/Build/Products/Debug/$(NAME).app: $(SOURCES) $(NAME).xcodeproj
	xcodebuild \
		-project $(NAME).xcodeproj \
		-scheme $(NAME)_macOS \
		-configuration Debug \
		-destination "platform=macOS" \
		-derivedDataPath .build

.build/Build/Products/Release/$(NAME).app: $(SOURCES) $(NAME).xcodeproj
	xcodebuild \
		-project $(NAME).xcodeproj \
		-scheme $(NAME)_macOS \
		-configuration Release \
		-destination "platform=macOS" \
		-derivedDataPath .build

.PHONY release: .build/Build/Products/Release/$(NAME).app
.PHONY build: .build/Build/Products/Release/$(NAME).app

