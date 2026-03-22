APP_NAME     := Share Multi Window
DISPLAY_NAME := Share Multi Window
BUNDLE_ID    := com.sharemultiwindow.app
VERSION      := 1.0

APP_BUNDLE   := $(APP_NAME).app
DMG_FILE     := $(APP_NAME)-$(VERSION).dmg
INSTALL_DIR  := /Applications

.PHONY: build app dmg install uninstall run clean

build:
	@echo "Compilando $(APP_NAME)..."
	@swift build -c release 2>&1

app: build
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp ".build/release/ShareMultiWindow" "$(APP_BUNDLE)/Contents/MacOS/ShareMultiWindow"
	@cp Info.plist "$(APP_BUNDLE)/Contents/"
	@cp AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	@codesign --force --sign - "$(APP_BUNDLE)"
	@echo "$(APP_BUNDLE) criado."

dmg: app
	@echo "Criando $(DMG_FILE)..."
	@./create-dmg.sh "$(APP_BUNDLE)" "$(DMG_FILE)" "$(DISPLAY_NAME)"

install: app
	@echo "Instalando em $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Instalado em $(INSTALL_DIR)/$(APP_BUNDLE)"

uninstall:
	@rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "Removido de $(INSTALL_DIR)/$(APP_BUNDLE)"

run: app
	@open "$(APP_BUNDLE)"

clean:
	@rm -rf .build "$(APP_BUNDLE)" "$(DMG_FILE)" build/
	@echo "Limpo."
