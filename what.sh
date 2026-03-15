#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Ensure we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: Not a git repository." >&2
  exit 1
fi

# Check that claude CLI is available
if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found. Install it first." >&2
  exit 1
fi

# Cache tags only (newest first)
_cached_refs=$(git tag --sort=-creatordate 2>/dev/null)

# Interactive tag picker with live autocomplete and arrow-key selection
read_with_completion() {
  local prompt="$1"
  local input=""
  local selected=-1  # -1 = typing mode, 0..2 = candidate index
  local matches=()

  _find_matches() {
    matches=()
    while IFS= read -r tag; do
      [ -z "$tag" ] && continue
      if [[ "$tag" == "$input"* ]]; then
        matches+=("$tag")
        [ ${#matches[@]} -ge 3 ] && break
      fi
    done <<< "$_cached_refs"
  }

  _draw() {
    local display="$input"
    if [ $selected -ge 0 ] && [ $selected -lt ${#matches[@]} ]; then
      display="${matches[$selected]}"
    fi

    # Draw 3 candidate lines below the input line
    local i
    for ((i=0; i<3; i++)); do
      printf '\n\033[2K'
      if [ $i -lt ${#matches[@]} ]; then
        if [ $i -eq $selected ]; then
          printf "  ${GREEN}> %s${RESET}" "${matches[$i]}"
        else
          printf "    ${CYAN}%s${RESET}" "${matches[$i]}"
        fi
      fi
    done

    # Move cursor back to input line and rewrite it
    printf '\033[3A\r\033[2K%s%s' "$prompt" "$display"
  }

  _cleanup() {
    # Clear the 3 candidate lines
    local i
    for ((i=0; i<3; i++)); do
      printf '\n\033[2K'
    done
    printf '\033[3A'
  }

  # Initial draw
  _find_matches
  printf '%s' "$prompt"
  _draw

  local char
  while IFS= read -rsn1 char; do
    case "$char" in
      '')  # Enter — accept selected candidate or typed input
        if [ $selected -ge 0 ] && [ $selected -lt ${#matches[@]} ]; then
          input="${matches[$selected]}"
        fi
        _cleanup
        printf '\r\033[2K%s%s\n' "$prompt" "$input"
        break
        ;;
      $'\177'|$'\b')  # Backspace
        if [ -n "$input" ]; then
          input="${input%?}"
          selected=-1
          _find_matches
          _draw
        fi
        ;;
      $'\x03')  # Ctrl+C
        _cleanup
        printf '\n'
        exit 130
        ;;
      $'\e')  # Escape sequence — handle arrow keys
        read -rsn2 -t 1 seq 2>/dev/null || true
        case "$seq" in
          '[A')  # Up arrow
            if [ $selected -gt 0 ]; then
              ((selected--))
            elif [ $selected -eq 0 ]; then
              selected=-1
            fi
            _draw
            ;;
          '[B')  # Down arrow
            if [ ${#matches[@]} -gt 0 ] && [ $selected -lt $((${#matches[@]} - 1)) ]; then
              ((selected++))
            fi
            _draw
            ;;
        esac
        ;;
      $'\t')  # Tab — treat as Down arrow
        if [ ${#matches[@]} -gt 0 ] && [ $selected -lt $((${#matches[@]} - 1)) ]; then
          ((selected++))
        fi
        _draw
        ;;
      *)  # Regular character — append and refresh candidates
        input+="$char"
        selected=-1
        _find_matches
        _draw
        ;;
    esac
  done

  _read_result="$input"
}

# Accept tag from CLI argument or interactive picker
if [ -n "$1" ]; then
  tag="$1"
else
  echo -e "Summarize what changed in a tag."
  echo -e "Use ${YELLOW}arrow keys${RESET} to select, ${YELLOW}Enter${RESET} to confirm."
  echo ""

  read_with_completion "Tag: "
  tag="$_read_result"
fi

if [ -z "$tag" ]; then
  echo "Error: no tag specified." >&2
  exit 1
fi

# Validate the tag exists; try prefix match if exact tag not found
if ! git rev-parse "$tag" &>/dev/null; then
  match=$(git tag --sort=-creatordate 2>/dev/null | grep "^${tag}" | head -1)
  if [ -n "$match" ]; then
    echo -e "Tag '$tag' not found, using ${CYAN}${match}${RESET}"
    tag="$match"
  else
    echo "Error: no tag matching '$tag*' found." >&2
    exit 1
  fi
fi

# Extract the series prefix (e.g. "insider-" from "insider-20260314")
series="${tag%%-*}-"

# Find the previous tag in the same series, sorted by creation date
prev_tag=$(git tag --sort=-creatordate --merged "$tag" 2>/dev/null \
  | grep "^${series}" \
  | grep -v "^${tag}$" \
  | head -1)

if [ -z "$prev_tag" ]; then
  echo "Error: no previous tag found in '${series}*' series before '$tag'." >&2
  exit 1
fi

# Date range display
prev_date=$(git log -1 --format='%cs' "$prev_tag")
tag_date=$(git log -1 --format='%cs' "$tag")
prev_epoch=$(git log -1 --format='%ct' "$prev_tag")
tag_epoch=$(git log -1 --format='%ct' "$tag")
days=$(( (tag_epoch - prev_epoch) / 86400 ))
if [ $days -lt 0 ]; then
  days=$(( -days ))
fi

if [ $days -eq 0 ]; then
  span="same day"
elif [ $days -eq 1 ]; then
  span="1 day"
elif [ $days -lt 7 ]; then
  span="$days days"
elif [ $days -lt 14 ]; then
  span="1 week"
elif [ $days -lt 30 ]; then
  span="$((days / 7)) weeks"
elif [ $days -lt 60 ]; then
  span="1 month"
else
  span="$((days / 30)) months"
fi

echo ""
echo -e "  ${CYAN}${prev_tag}${RESET} ${GREEN}${prev_date}${RESET}"
echo -e "  ${CYAN}${tag}${RESET} ${GREEN}${tag_date}${RESET}  (${YELLOW}${span}${RESET})"

# Get commits between the two tags
commits=$(git log --oneline --no-merges "${prev_tag}..${tag}")

if [ -z "$commits" ]; then
  echo ""
  echo "No commits found between '$prev_tag' and '$tag'."
  exit 0
fi

commit_count=$(echo "$commits" | wc -l | tr -d ' ')
echo ""
echo -e "Found ${GREEN}${commit_count}${RESET} commits. Generating summary..."
echo ""

# Pipe commits to claude for summarization
summary=$(echo "$commits" | claude -p \
  "You are writing a concise changelog summary from raw git commits between \`$prev_tag\` and \`$tag\`.

Rules:
- Group related commits into one bullet. Aggressively merge — aim for 5-10 bullets per section, not one per commit.
- Each bullet format: **Bold short label** — Description with specific details of what was added, changed, or fixed. Use commas to list multiple related items within one bullet.
- Tone: concise, confident, informative. Written for developers and product people, not end users. Name features, UI elements, and tools specifically. Mention issue numbers like (#123) if present in commits.
- Omit a section entirely if there are no items for it.

Output exactly these four sections in this order:

### New Features
### Improvements
### Bug Fixes
### Cleanup & Refactoring

Example style:
- **Continuity Camera** — Import photos/videos directly from iPhone into Writer
- **Article selection & navigation** — Restore last selected article on launch, auto-scroll sidebar, preserve selection after saving/moving drafts
- **Dependencies** — Replaced ENSKit with lightweight ENSDataKit, removed unused HDWalletKit, updated Sparkle to 2.9.0")

# Colorize output for terminal display
ESC=$'\033'
C_GREEN="${ESC}[0;32m"
C_CYAN="${ESC}[0;36m"
C_YELLOW="${ESC}[0;33m"
C_RESET="${ESC}[0m"
colorized=$(echo "$summary" | sed \
  -e "s/^### \(.*\)/${C_GREEN}### \1${C_RESET}/" \
  -e "s/\*\*\([^*]*\)\*\*/${C_CYAN}\1${C_RESET}/g" \
  -e "s/^- /  ${C_YELLOW}•${C_RESET} /")

# Display with pager, then reprint so output stays in scrollback
echo "$colorized" | less -R
echo "$colorized"

# Copy raw markdown (no color codes) to clipboard
echo ""
printf '%s' "$summary" | pbcopy
echo -e "${GREEN}Copied to clipboard.${RESET}"
