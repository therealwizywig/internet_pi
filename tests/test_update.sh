#!/bin/bash
set -e

echo "Basic update.sh test"

# 1. Check that update.sh can contact the repo and get a commit hash
REPO_OWNER="therealwizywig"
REPO_NAME="internet-pi"
BRANCH="master"

LATEST_COMMIT=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/$BRANCH" | grep -m 1 '"sha":' | cut -d'"' -f4)

if [[ -z "$LATEST_COMMIT" ]]; then
  echo "FAILED: Could not fetch latest commit hash from GitHub"
  exit 1
else
  echo "SUCCESS: Fetched latest commit hash: $LATEST_COMMIT"
fi

# 2. Check that ansible-playbook is available and executable
if command -v ansible-playbook >/dev/null 2>&1; then
  echo "SUCCESS: ansible-playbook is available"
else
  echo "FAILED: ansible-playbook is not available"
  exit 1
fi

echo "Basic tests passed." 
