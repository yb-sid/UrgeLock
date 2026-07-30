APP_NAME := UrgeLock
BUNDLE_ID := app.urgelock.mac
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
MACOS_DIR := $(APP_DIR)/Contents/MacOS
RES_DIR := $(APP_DIR)/Contents/Resources
SDK := $(shell xcrun --show-sdk-path)
SWIFTC := swiftc
SOURCES := $(shell find Sources -name '*.swift' | sort)
SWIFT_FLAGS := -sdk $(SDK) -O -whole-module-optimization \
	-framework AppKit -framework Foundation -framework Security -framework CryptoKit \
	-target arm64-apple-macos13.0

.PHONY: all app run install clean dirs

all: app

dirs:
	@mkdir -p $(MACOS_DIR) $(RES_DIR)

app: dirs $(SOURCES) Resources/Info.plist Resources/blocklists/extra-domains.txt
	@echo "→ Compiling $(APP_NAME)..."
	$(SWIFTC) $(SWIFT_FLAGS) -o $(MACOS_DIR)/$(APP_NAME) $(SOURCES)
	@cp Resources/Info.plist $(APP_DIR)/Contents/Info.plist
	@cp -R Resources/blocklists $(RES_DIR)/
	@# ad-hoc sign so Gatekeeper is less angry for local runs
	@codesign --force --deep -s - $(APP_DIR) 2>/dev/null || true
	@echo "✓ Built $(APP_DIR)"

run: app
	open $(APP_DIR)

install: app
	mkdir -p $(HOME)/Applications
	rm -rf $(HOME)/Applications/$(APP_NAME).app
	cp -R $(APP_DIR) $(HOME)/Applications/
	@echo "✓ Installed to ~/Applications/$(APP_NAME).app"

clean:
	rm -rf $(BUILD_DIR)
