#!/bin/bash
set -e

APP_BUNDLE="${1:?Uso: $0 <App.app> <output.dmg> <volume-name>}"
DMG_OUTPUT="${2:?Falta nome do DMG}"
VOLUME_NAME="${3:-Share Multi Window}"

TEMP_DMG=$(mktemp -u).dmg

cleanup() {
    if [ -d "/Volumes/$VOLUME_NAME" ]; then
        hdiutil detach "/Volumes/$VOLUME_NAME" -force -quiet 2>/dev/null || true
    fi
    rm -f "$TEMP_DMG"
}
trap cleanup EXIT

# Desmontar volume anterior se existir (causa "Read-only file system")
if [ -d "/Volumes/$VOLUME_NAME" ]; then
    echo "  Desmontando volume anterior..."
    hdiutil detach "/Volumes/$VOLUME_NAME" -force -quiet 2>/dev/null || true
fi

# Remover DMG anterior
rm -f "$DMG_OUTPUT"

# Calcular tamanho necessario (app + 10MB margem)
APP_SIZE_KB=$(du -sk "$APP_BUNDLE" | cut -f1)
DMG_SIZE_KB=$(( APP_SIZE_KB + 10240 ))

echo "  Tamanho do app: $(( APP_SIZE_KB / 1024 ))MB"

# Criar DMG temporario read-write
hdiutil create \
    -size "${DMG_SIZE_KB}k" \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    -o "$TEMP_DMG" \
    -quiet

# Montar
hdiutil attach "$TEMP_DMG" -readwrite -quiet

MOUNT_DIR="/Volumes/$VOLUME_NAME"

# Copiar app e criar atalho para Applications
ditto "$APP_BUNDLE" "$MOUNT_DIR/$(basename "$APP_BUNDLE")"
ln -s /Applications "$MOUNT_DIR/Applications"

# Configurar visual do DMG (posicao dos icones, tamanho da janela)
# O AppleScript pode falhar se o Finder nao abrir a tempo — nao e critico
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, 720, 480}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "$(basename "$APP_BUNDLE")" of container window to {140, 140}
        set position of item "Applications" of container window to {380, 140}
        close
    end tell
end tell
APPLESCRIPT

sync

# Desmontar
hdiutil detach "$MOUNT_DIR" -quiet

# Converter para DMG comprimido read-only
rm -f "$DMG_OUTPUT"
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_OUTPUT" \
    -quiet

DMG_SIZE=$(du -sh "$DMG_OUTPUT" | cut -f1)
echo "  Instalador criado: $DMG_OUTPUT ($DMG_SIZE)"
echo ""
echo "  Para instalar: arraste o app para Applications"
open "$DMG_OUTPUT"
