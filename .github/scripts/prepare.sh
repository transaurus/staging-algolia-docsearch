#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/algolia/docsearch"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# --- Node version ---
# .nvmrc specifies 22.15.0; Docusaurus 3.9.2 requires Node 20+
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -f "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm use 22
fi

# --- Package manager: Yarn 4.6.0 via corepack ---
corepack enable
corepack prepare yarn@4.6.0 --activate

# --- Install all dependencies from monorepo root ---
yarn install

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

# --- Pre-build: build all workspace packages (required before docusaurus commands) ---
# The website depends on @docsearch/core, @docsearch/css, @docsearch/react,
# @docsearch/docusaurus-adapter, @docsearch/sidepanel — all workspace packages
# that must be compiled before Docusaurus can use them.
yarn build

echo "[DONE] Repository is ready for docusaurus commands."
