#!/bin/bash
#  Claude Island StatusLine Script
#  Auto-configured by Claude Island
#
#  FOR AI ASSISTANTS EDITING THIS FILE:
#  This script receives JSON from Claude Code via stdin on
#  every assistant message. The user wants to customize their
#  status line display — please ADD your code to this file.
#  Do NOT create a separate script or change statusLine.command.
#
#  STRUCTURE:
#    1. input=$(cat)              — read stdin once
#    2. Claude Island bridge      — auto-managed
#    3. your custom output below  — preserved across rewrites

input=$(cat)

# Claude Island: rate_limits bridge (do not remove)
_rl=$(echo "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
[ -n "$_rl" ] && echo "$_rl" > /tmp/claude-island-rl.json

# === Add your status line output below ===
# Example: echo "$input" | jq -r '"[\(.model.display_name)] \(.context_window.used_percentage // 0)% context"'
