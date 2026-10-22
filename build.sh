#!/bin/bash
# One-step build + install of EdgeTodo into /Applications
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "⚠️  Xcode Command Line Tools are not installed. Opening the installer now."
  echo "   When it finishes, run this again: bash build.sh"
  xcode-select --install
  exit 1
fi

APP="EdgeTodo.app"
OUT="$APP/Contents/MacOS/EdgeTodo"
LOG="$(mktemp)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

# macOS 26+ SDK → enable Liquid Glass
glass_flag() {
  local ver major
  ver=$(/usr/libexec/PlistBuddy -c "Print :Version" "$1/SDKSettings.plist" 2>/dev/null)
  major=${ver%%.*}
  if [ -n "$major" ] && [ "$major" -ge 26 ] 2>/dev/null; then echo "-D GLASS"; fi
}

try_build() {   # $1 = SDK path
  local flags
  flags=$(glass_flag "$1")
  swiftc -O -parse-as-library -sdk "$1" $flags EdgeTodo.swift -o "$OUT" 2>"$LOG" || return 1
  if [ -n "$flags" ]; then GLASS_ON=1; fi
  return 0
}

echo "🔨 Building..."
built=0
GLASS_ON=0

DEFAULT_SDK="$(xcrun --show-sdk-path 2>/dev/null)"
if [ -n "$DEFAULT_SDK" ] && try_build "$DEFAULT_SDK"; then
  built=1
else
  # Default SDK doesn't match the compiler → try every other SDK on this Mac (newest first)
  for sdk in $(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk \
                     /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk \
                     2>/dev/null | sort -rV); do
    echo "   Trying $(basename "$sdk") ..."
    if try_build "$sdk"; then
      built=1
      echo "   ✓ Built with $(basename "$sdk")"
      break
    fi
  done
fi

if [ "$built" != "1" ]; then
  echo ""
  echo "❌ Build failed. Last error output:"
  echo "------------------------------------------"
  grep -m 15 "error:" "$LOG" || tail -n 30 "$LOG"
  echo "------------------------------------------"
  if grep -q "this SDK is not supported by the compiler" "$LOG"; then
    echo "👉 Your developer tools are only partly updated. Reinstall Command Line Tools:"
    echo "   sudo rm -rf /Library/Developer/CommandLineTools"
    echo "   xcode-select --install"
    echo "   Then run again: bash build.sh"
  else
    echo "👉 Open an issue on GitHub with the error above."
  fi
  exit 1
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "📦 Installing to /Applications..."
pkill -x EdgeTodo 2>/dev/null || true
rm -rf "/Applications/$APP"
cp -R "$APP" /Applications/
open "/Applications/$APP"

echo ""
echo "✅ Done! Move your mouse to the right edge of the screen (upper half) to open the panel."
echo "   ⚙︎  Settings: gear icon on the panel, or the ☑︎ menu bar icon → Settings…"
if [ "$GLASS_ON" = "1" ]; then
  echo "   📌 Pinned panel uses Liquid Glass."
else
  echo "   (This SDK is too old for Liquid Glass — the pinned panel stays frosted.)"
fi
echo "   Data file: ~/EdgeTodo/todos.json"
