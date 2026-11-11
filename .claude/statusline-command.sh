#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

# Context bar with threshold colors
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

# Git info: branch + staged/modified counts
GIT_INFO=""
if git -C "$DIR" --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" --no-optional-locks branch --show-current 2>/dev/null)
    STAGED=$(git -C "$DIR" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "$DIR" --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')

    GIT_STATUS=""
    [ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"
    [ -n "$GIT_STATUS" ] && GIT_STATUS=" $GIT_STATUS"

    GIT_INFO=" | $BRANCH$GIT_STATUS"
fi

# Clickable repo link (OSC 8)
REPO_LINK=""
REMOTE=$(git -C "$DIR" --no-optional-locks remote get-url origin 2>/dev/null \
    | sed 's/git@github\.com:/https:\/\/github.com\//' \
    | sed 's/\.git$//')
if [ -n "$REMOTE" ]; then
    REPO_NAME=$(basename "$REMOTE")
    REPO_LINK=" | \e]8;;${REMOTE}\a${REPO_NAME}\e]8;;\a"
fi

printf '%b\n' "${CYAN}[$MODEL]${RESET} ${DIR##*/}${GIT_INFO}${REPO_LINK}"
printf '%b\n' "${BAR_COLOR}${BAR}${RESET} ${PCT}%"
