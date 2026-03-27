#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for algolia/docsearch
# Runs from packages/website in the existing source tree.
# Installs deps, builds workspace packages, then builds the Docusaurus site.

# --- Node version ---
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -f "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm use 22
fi

# --- Package manager: Yarn 4.6.0 via corepack ---
corepack enable
corepack prepare yarn@4.6.0 --activate

CURRENT_DIR="$(pwd)"

# --- Install and build workspace packages ---
# Check if full monorepo is present (two levels up: packages/website -> root)
if [ -f "../../package.json" ] && node -e "const p=require('../../package.json'); process.exit(p.workspaces ? 0 : 1)" 2>/dev/null; then
    # Full monorepo context: install from root and build all workspace packages
    echo "[INFO] Monorepo detected, building from root..."
    cd ../..
    yarn install
    yarn build
    cd "$CURRENT_DIR"
else
    # No monorepo context: clone source, build workspace packages, copy artifacts
    echo "[INFO] No monorepo context, cloning source for workspace dependencies..."
    TEMP_DIR="/tmp/docsearch-workspace-$$"
    git clone --depth 1 https://github.com/algolia/docsearch "$TEMP_DIR"
    cd "$TEMP_DIR"
    corepack prepare yarn@4.6.0 --activate
    yarn install
    yarn build

    # Copy built dist artifacts from workspace packages into current node_modules
    cd "$CURRENT_DIR"
    for pkg_dir in "$TEMP_DIR/packages" "$TEMP_DIR/adapters"; do
        if [ -d "$pkg_dir" ]; then
            for pkg in "$pkg_dir"/*/; do
                if [ -f "$pkg/package.json" ] && [ -d "$pkg/dist" ]; then
                    pkg_name=$(node -e "console.log(require('$pkg/package.json').name)")
                    target_dir="node_modules/$pkg_name"
                    if [ -d "$target_dir" ]; then
                        cp -r "$pkg/dist" "$target_dir/"
                        echo "[INFO] Copied dist for $pkg_name"
                    fi
                fi
            done
        fi
    done
    rm -rf "$TEMP_DIR"

    # Install website deps
    yarn install
fi

# --- Build the Docusaurus site ---
yarn build

echo "[DONE] Build complete."
