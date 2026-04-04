#!/bin/zsh
# claude-island-bridge launcher (auto-generated, do not edit)
H=/Contents/Helpers/claude-island-bridge

# 1. Direct path — most common case
B="/Applications/Claude Island.app${H}"
[ -x "$B" ] && exec "$B" "$@"

# 2. Try alternative standard paths
for P in "/Applications/Claude Island.app" "/Applications/claude-island.app" "$HOME/Applications/Claude Island.app"; do
  B="${P}${H}"; [ -x "$B" ] && exec "$B" "$@"
done

# 3. Cached path from app launch
C=~/.claude-island/bin/.bridge-cache
if [ -f "$C" ]; then
  P="$(cat "$C")"
  B="${P}${H}"
  [ -x "$B" ] && exec "$B" "$@"
fi

# 4. Spotlight mdfind as final fallback
P="$(/usr/bin/mdfind 'kMDItemCFBundleIdentifier == "com.celestial.ClaudeIsland"' 2>/dev/null | /usr/bin/head -1)"
B="${P}${H}"
[ -x "$B" ] && { mkdir -p ~/.claude-island/bin; echo "$P" > "$C"; exec "$B" "$@"; }

echo "claude-island-bridge: app not found. Launch Claude Island once to fix." >&2
exit 127
