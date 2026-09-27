#!/bin/bash
set -euo pipefail

MYAGENDA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$MYAGENDA_ROOT"
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export PATH="$HOME/Developer/flutter/bin:/opt/homebrew/bin:$PATH"
export CI=true

if ! command -v flutter >/dev/null; then
  echo "Installez Flutter, puis relancez ce fichier. Voir README.md."
  exit 1
fi
if ! xcodebuild -checkFirstLaunchStatus; then
  echo "Ouvrez Xcode et terminez sa configuration, puis relancez ce fichier."
  open -a Xcode
  exit 1
fi
flutter pub get
flutter build macos --release
mkdir -p "$HOME/Applications"
MYAGENDA_DEST="$HOME/Applications/MyAgenda.app"
if [ -e "$MYAGENDA_DEST" ]; then
  mv "$MYAGENDA_DEST" "$HOME/Applications/MyAgenda-backup-$(date +%Y%m%d-%H%M%S).app"
fi
ditto build/macos/Build/Products/Release/MyAgenda.app "$MYAGENDA_DEST"
open "$MYAGENDA_DEST"
