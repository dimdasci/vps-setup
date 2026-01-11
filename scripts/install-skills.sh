#!/bin/bash
# Install Claude Code skills on VPS
# Run this locally to transfer skills to your VPS
#
# Usage: ./install-skills.sh VPS_HOST [SKILLS_SOURCE]
# Example: ./install-skills.sh app@123.45.67.89
#          ./install-skills.sh vps
#          ./install-skills.sh vps ./skills_src

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$1" ]; then
    echo "Usage: $0 VPS_HOST [SKILLS_SOURCE]"
    echo "Example: $0 app@123.45.67.89"
    echo "         $0 vps"
    echo "         $0 vps ./skills_src"
    exit 1
fi

VPS_HOST="$1"

# Use project .claude/skills if available, otherwise ~/.claude/skills
if [ -n "$2" ]; then
    SKILLS_DIR="$2"
elif [ -d "$PROJECT_DIR/.claude/skills" ]; then
    SKILLS_DIR="$PROJECT_DIR/.claude/skills"
else
    SKILLS_DIR="$HOME/.claude/skills"
fi

echo "Skills source: $SKILLS_DIR"

echo "Installing skills to $VPS_HOST..."
echo ""

# Create skills directory on remote
ssh "$VPS_HOST" "mkdir -p ~/.claude/skills"

# Find and transfer skill packages
SKILL_FILES=$(find "$SKILLS_DIR" -name "*.skill" -type f 2>/dev/null)

if [ -z "$SKILL_FILES" ]; then
    echo "No .skill packages found in $SKILLS_DIR"
    echo "Looking for skill directories instead..."

    # Transfer directories directly
    for skill_dir in "$SKILLS_DIR"/*/; do
        if [ -d "$skill_dir" ] && [ -f "${skill_dir}SKILL.md" ]; then
            skill_name=$(basename "$skill_dir")
            echo "Transferring $skill_name..."
            rsync -av --exclude='.git' "$skill_dir" "$VPS_HOST:~/.claude/skills/"
        fi
    done
else
    # Transfer .skill packages and extract
    for skill_file in $SKILL_FILES; do
        skill_name=$(basename "$skill_file" .skill)
        echo "Transferring $skill_name.skill..."
        scp "$skill_file" "$VPS_HOST:~/tmp_skill.zip"
        ssh "$VPS_HOST" "cd ~/.claude/skills && unzip -o ~/tmp_skill.zip && rm ~/tmp_skill.zip"
    done
fi

echo ""
echo "Installed skills:"
ssh "$VPS_HOST" "ls -la ~/.claude/skills/"

echo ""
echo "Done! Skills are ready to use with Claude Code on $VPS_HOST"
