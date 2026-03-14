#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo -e "Today: ${CYAN}$(date '+%Y-%m-%d %I:%M:%S %p %Z')${RESET}"
echo ""
echo "Last 5 tags:"
git tag -l --sort=-creatordate --format='%(creatordate:short)|%(refname:short)|%(contents:subject)' | head -5 | while IFS='|' read -r date_part tag_part msg_part; do
  echo -e "  ${GREEN}${date_part}${RESET}  ${CYAN}${tag_part}${RESET}  ${YELLOW}${msg_part}${RESET}"
done
echo ""

read -rp "Tag name: " tag_name
if [ -z "$tag_name" ]; then
  echo "Tag name cannot be empty."
  exit 1
fi

read -rp "Tag message: " tag_message
if [ -z "$tag_message" ]; then
  echo "Tag message cannot be empty."
  exit 1
fi

echo ""
echo -e "New tag:     ${CYAN}${tag_name}${RESET}"
echo -e "Message:     ${YELLOW}${tag_message}${RESET}"
echo ""

read -rp "Confirm? [y/N] " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
  git tag -a "$tag_name" -m "$tag_message"
  echo "Tag '$tag_name' created."
else
  echo "Cancelled."
fi
