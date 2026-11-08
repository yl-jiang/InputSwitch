APP_DIR := dist/InputSwitch.app
CONTENTS_DIR := $(APP_DIR)/Contents

.PHONY: build test

build:
	swift build -c release
	mkdir -p $(CONTENTS_DIR)/MacOS $(CONTENTS_DIR)/Resources
	cp .build/release/InputSwitch $(CONTENTS_DIR)/MacOS/InputSwitch
	cp Resources/Info.plist $(CONTENTS_DIR)/Info.plist
	cp Resources/AppIcon.icns Resources/MenuBarIcon.png $(CONTENTS_DIR)/Resources/
	codesign --force --sign - $(APP_DIR)

test:
	swift run InputSwitchTests
