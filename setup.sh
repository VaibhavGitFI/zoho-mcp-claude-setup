#!/usr/bin/env bash
# Zoho MCP × Claude — One-command setup script
# Usage: bash setup.sh

set -e

# ─── Colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✔ $1${RESET}"; }
info() { echo -e "${BLUE}ℹ $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $1${RESET}"; }
err()  { echo -e "${RED}✖ $1${RESET}"; }
step() { echo -e "\n${BOLD}${CYAN}── $1 ──${RESET}"; }

# ─── Banner ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Zoho MCP × Claude  —  Setup Wizard    ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"

# ─── Detect OS ──────────────────────────────────────────────────────────────
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
elif [[ "$OS" == "Linux" ]]; then
  DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
else
  err "Windows detected. Please follow the manual steps in README.md."
  exit 1
fi

# ─── Step 1: Find Node.js ────────────────────────────────────────────────────
step "1/5  Detecting Node.js"

NODE_BIN=""

# Check nvm first (most common for devs)
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  source "$HOME/.nvm/nvm.sh" 2>/dev/null
  NVM_NODE=$(nvm which current 2>/dev/null || true)
  if [ -f "$NVM_NODE" ]; then
    NODE_BIN="$NVM_NODE"
    info "Found nvm Node: $NODE_BIN"
  fi
fi

# Fallback: which node
if [ -z "$NODE_BIN" ]; then
  NODE_BIN=$(which node 2>/dev/null || true)
fi

# Fallback: common brew/system paths
if [ -z "$NODE_BIN" ]; then
  for candidate in /opt/homebrew/bin/node /usr/local/bin/node /usr/bin/node; do
    if [ -f "$candidate" ]; then
      NODE_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "$NODE_BIN" ]; then
  err "Node.js not found. Install it from https://nodejs.org or via nvm."
  exit 1
fi

NODE_VERSION=$("$NODE_BIN" --version 2>/dev/null)
NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')

if [ "$NODE_MAJOR" -lt 18 ]; then
  err "Node.js $NODE_VERSION is too old. Version 18+ required."
  err "Run: nvm install 20 && nvm use 20"
  exit 1
fi

ok "Node.js $NODE_VERSION at $NODE_BIN"
NPX_BIN="$(dirname "$NODE_BIN")/npx"
NODE_DIR="$(dirname "$NODE_BIN")"

# ─── Step 2: Check Claude Code CLI ──────────────────────────────────────────
step "2/5  Checking Claude Code CLI"

CLAUDE_CLI=$(which claude 2>/dev/null || true)
if [ -z "$CLAUDE_CLI" ]; then
  warn "Claude CLI not found. Skipping Claude Code setup."
  warn "Install with: npm install -g @anthropic-ai/claude-code"
  HAS_CLAUDE_CLI=false
else
  ok "Claude CLI found at $CLAUDE_CLI"
  HAS_CLAUDE_CLI=true
fi

# ─── Step 3: Collect MCP URLs ────────────────────────────────────────────────
step "3/5  Zoho MCP URLs"

echo ""
echo -e "${BOLD}Where to get your URLs:${RESET}"
echo "  1. Go to https://mcp.zoho.in  (change .in to your DC: .com / .eu / .com.au)"
echo "  2. Create or open an MCP server for each product"
echo "  3. Select your tools and copy the Message URL"
echo ""
echo -e "${YELLOW}Leave a URL blank to skip that server.${RESET}"
echo ""

read -rp "  Zoho CRM URL  : " CRM_URL
read -rp "  Zoho Mail URL : " MAIL_URL
read -rp "  Zoho Cliq URL : " CLIQ_URL

if [ -z "$CRM_URL" ] && [ -z "$MAIL_URL" ] && [ -z "$CLIQ_URL" ]; then
  err "No URLs provided. Nothing to set up."
  exit 1
fi

# ─── Step 4: Update Claude Desktop config ───────────────────────────────────
step "4/5  Configuring Claude Desktop"

# Create config dir if missing
CONFIG_DIR="$(dirname "$DESKTOP_CONFIG")"
mkdir -p "$CONFIG_DIR"

# Read existing config or start fresh
if [ -f "$DESKTOP_CONFIG" ]; then
  EXISTING=$(cat "$DESKTOP_CONFIG")
  # Back up
  cp "$DESKTOP_CONFIG" "${DESKTOP_CONFIG}.bak"
  info "Backed up existing config to claude_desktop_config.json.bak"
else
  EXISTING='{"mcpServers":{}}'
fi

# Build the mcp-remote args array for a given URL
mcp_server_block() {
  local url="$1"
  cat <<JSON
{
      "command": "$NODE_BIN",
      "args": [
        "$NPX_BIN",
        "-y",
        "mcp-remote@latest",
        "$url"
      ],
      "env": {
        "PATH": "$NODE_DIR:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
      }
    }
JSON
}

# Use python3 to safely merge into existing JSON
python3 - <<PYEOF
import json, sys

config_path = """$DESKTOP_CONFIG"""
existing_raw = """$EXISTING"""

try:
    config = json.loads(existing_raw)
except json.JSONDecodeError:
    config = {}

if "mcpServers" not in config:
    config["mcpServers"] = {}

crm_url  = """$CRM_URL""".strip()
mail_url = """$MAIL_URL""".strip()
cliq_url = """$CLIQ_URL""".strip()
node_bin = """$NODE_BIN"""
npx_bin  = """$NPX_BIN"""
node_dir = """$NODE_DIR"""

def server_entry(url):
    return {
        "command": node_bin,
        "args": [npx_bin, "-y", "mcp-remote@latest", url],
        "env": {"PATH": f"{node_dir}:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"}
    }

if crm_url:
    config["mcpServers"]["zoho-crm"] = server_entry(crm_url)
if mail_url:
    config["mcpServers"]["zoho-mail"] = server_entry(mail_url)
if cliq_url:
    config["mcpServers"]["zoho-cliq"] = server_entry(cliq_url)

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print("ok")
PYEOF

ok "Claude Desktop config updated"

# ─── Step 4b: Update Claude Code CLI ────────────────────────────────────────
if [ "$HAS_CLAUDE_CLI" = true ]; then
  info "Updating Claude Code CLI..."
  if [ -n "$CRM_URL" ]; then
    claude mcp remove zoho-crm 2>/dev/null || true
    claude mcp add --transport http zoho-crm "$CRM_URL"
    ok "zoho-crm added to Claude Code"
  fi
  if [ -n "$MAIL_URL" ]; then
    claude mcp remove zoho-mail 2>/dev/null || true
    claude mcp add --transport http zoho-mail "$MAIL_URL"
    ok "zoho-mail added to Claude Code"
  fi
  if [ -n "$CLIQ_URL" ]; then
    claude mcp remove zoho-cliq 2>/dev/null || true
    claude mcp add --transport http zoho-cliq "$CLIQ_URL"
    ok "zoho-cliq added to Claude Code"
  fi
fi

# ─── Step 5: Authenticate (mcp-remote) ──────────────────────────────────────
step "5/5  Authentication"

echo ""
echo -e "${BOLD}We'll now authenticate each server.${RESET}"
echo "  • A URL will be printed in the terminal"
echo "  • Open it in an INCOGNITO/PRIVATE browser window"
echo "  • Log in with your Zoho account and grant access"
echo "  • Return here and press Enter to continue"
echo ""

# Clear stale auth sessions
rm -rf ~/.mcp-auth/
info "Cleared stale auth cache"

auth_server() {
  local name="$1"
  local url="$2"
  echo ""
  echo -e "${BOLD}Authenticating $name...${RESET}"
  echo -e "${YELLOW}Starting mcp-remote — copy the auth URL below and open it in incognito.${RESET}"
  echo -e "${YELLOW}Press Ctrl+C here once the browser shows a success page.${RESET}"
  echo ""
  "$NPX_BIN" mcp-remote@latest "$url" &
  MCP_PID=$!
  read -rp "  Press Enter after completing browser auth... "
  kill $MCP_PID 2>/dev/null || true
  wait $MCP_PID 2>/dev/null || true
  ok "$name authenticated"
}

read -rp "  Authenticate servers now? [Y/n]: " DO_AUTH
DO_AUTH="${DO_AUTH:-Y}"

if [[ "$DO_AUTH" =~ ^[Yy] ]]; then
  [ -n "$CRM_URL"  ] && auth_server "Zoho CRM"  "$CRM_URL"
  [ -n "$MAIL_URL" ] && auth_server "Zoho Mail" "$MAIL_URL"
  [ -n "$CLIQ_URL" ] && auth_server "Zoho Cliq" "$CLIQ_URL"
else
  echo ""
  warn "Skipped authentication. Run manually when ready:"
  [ -n "$CRM_URL"  ] && echo "  $NPX_BIN mcp-remote@latest \"$CRM_URL\""
  [ -n "$MAIL_URL" ] && echo "  $NPX_BIN mcp-remote@latest \"$MAIL_URL\""
  [ -n "$CLIQ_URL" ] && echo "  $NPX_BIN mcp-remote@latest \"$CLIQ_URL\""
fi

# ─── Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║           Setup Complete!               ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  ${BOLD}Next steps:${RESET}"
echo "  1. Quit Claude Desktop fully (Cmd+Q) and reopen it"
echo "  2. Look for the MCP server indicator in the chat interface"
echo "  3. Try: 'Get me all leads from Zoho CRM'"
echo ""
echo -e "  ${BOLD}To update a URL later, just re-run:${RESET}  bash setup.sh"
echo ""
