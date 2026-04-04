#!/bin/zsh
# Claude Island Bridge Launcher
# Multi-level discovery of the bridge binary to handle App relocation.
H=/Contents/Helpers/claude-island-bridge

# 1. Standard application paths
for P in "/Applications/Claude Island.app" "$HOME/Applications/Claude Island.app"; do
  B="${P}${H}"; [ -x "$B" ] && exec "$B" "$@"
done

# 2. Cached path from previous discovery
C=~/.claude-island/bin/.bridge-cache
if [ -f "$C" ]; then
  read -r P < "$C"
  B="${P}${H}"
  [ -x "$B" ] && exec "$B" "$@"
fi

# 3. Spotlight search as fallback
P="$(/usr/bin/mdfind 'kMDItemCFBundleIdentifier == "com.celestial.ClaudeIsland"' 2>/dev/null | head -1)"
if [ -n "$P" ]; then
  mkdir -p ~/.claude-island/bin
  echo "$P" > "$C"
  B="${P}${H}"
  [ -x "$B" ] && exec "$B" "$@"
fi

echo "Claude Island not found" >&2
exit 1
