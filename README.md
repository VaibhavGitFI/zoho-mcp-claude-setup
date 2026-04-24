# Zoho MCP × Claude — Setup Guide

Connect Zoho CRM, Mail, and Cliq to Claude using the official Zoho MCP servers. This guide walks you through everything from prerequisites to a working connection in both **Claude Code (CLI)** and **Claude Desktop**.

---

## Quickstart (Recommended)

If you're on macOS or Linux, the setup script handles everything automatically:

```bash
git clone https://github.com/VaibhavGitFi/zoho-mcp-claude-setup.git
cd zoho-mcp-claude-setup
bash setup.sh
```

The script will:
- Detect your Node.js installation (including nvm)
- Ask for your Zoho MCP URLs
- Update both Claude Desktop config and Claude Code CLI
- Walk you through the OAuth authentication flow

> For Windows or manual setup, follow the step-by-step guide below.

---

## Table of Contents

1. [What Is MCP?](#what-is-mcp)
2. [Prerequisites](#prerequisites)
3. [Step 1 — Generate Your Zoho MCP URLs](#step-1--generate-your-zoho-mcp-urls)
4. [Step 2 — Set Up Claude Code (CLI)](#step-2--set-up-claude-code-cli)
5. [Step 3 — Set Up Claude Desktop](#step-3--set-up-claude-desktop)
6. [Step 4 — Authenticate Each Server](#step-4--authenticate-each-server)
7. [Verifying the Connection](#verifying-the-connection)
8. [Troubleshooting](#troubleshooting)
9. [Tool Selection Guide](#tool-selection-guide)
10. [Architecture Overview](#architecture-overview)

---

## What Is MCP?

**Model Context Protocol (MCP)** is an open standard that lets AI models like Claude connect directly to external services and data sources. Instead of copy-pasting data into the chat, Claude can read and write to your Zoho account in real time.

Zoho hosts official MCP servers at `mcp.zoho.in` (India DC) / `mcp.zoho.com` (US DC) for CRM, Mail, Cliq, and more. Each server exposes a set of tools (API operations) that Claude can call during a conversation.

---

## Prerequisites

### Accounts

| Requirement | Notes |
|---|---|
| Zoho account | CRM, Mail, or Cliq subscription required for respective servers |
| Claude account | Claude Pro, Team, or API access |
| Claude Code CLI | Install via `npm install -g @anthropic-ai/claude-code` |
| Claude Desktop | Download from [claude.ai/download](https://claude.ai/download) — required for Desktop setup |

### Software

| Software | Version | Install |
|---|---|---|
| Node.js | v20+ recommended (v18 minimum) | [nodejs.org](https://nodejs.org) or via nvm |
| npm | Comes with Node.js | — |
| nvm (optional) | Manage multiple Node versions | `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh \| bash` |

> **Important for nvm users:** Claude Desktop does not inherit your shell's `nvm` environment. You must use the **absolute path** to the Node binary. Find it with:
> ```bash
> nvm which 20   # or whichever version you use
> # e.g. /Users/yourname/.nvm/versions/node/v20.x.x/bin/node
> ```

### Zoho DC (Data Center)

Your Zoho account lives in one data center. Use the matching MCP domain:

| Data Center | MCP Domain |
|---|---|
| India | `mcp.zoho.in` |
| US | `mcp.zoho.com` |
| EU | `mcp.zoho.eu` |
| Australia | `mcp.zoho.com.au` |

---

## Step 1 — Generate Your Zoho MCP URLs

Each Zoho product (CRM, Mail, Cliq) has its own MCP server URL. You generate these from the Zoho MCP console.

1. Go to **[mcp.zoho.in](https://mcp.zoho.in)** (replace `.in` with your DC domain)
2. Sign in with your Zoho account
3. Click **Create MCP Server** or open an existing one
4. Choose the product: **CRM**, **Mail**, or **Cliq**
5. Select the tools you want to expose (see [Tool Selection Guide](#tool-selection-guide))
6. Copy the generated **Message URL** — it looks like:
   ```
   https://crm-data-metadata-<orgid>.zohomcp.in/mcp/<token>/message
   ```

> **Each time you change tool selections, a new URL is generated.** You will need to re-authenticate when this happens.

---

## Step 2 — Set Up Claude Code (CLI)

Claude Code supports HTTP MCP servers natively — no extra packages needed.

```bash
# Add each server (replace URLs with your generated ones)
claude mcp add --transport http zoho-crm "https://crm-data-metadata-<orgid>.zohomcp.in/mcp/<token>/message"
claude mcp add --transport http zoho-mail "https://mail-sending-replies-<orgid>.zohomcp.in/mcp/<token>/message"
claude mcp add --transport http zoho-cliq "https://cliq-messaging-<orgid>.zohomcp.in/mcp/<token>/message"

# Verify servers are listed
claude mcp list
```

Authentication happens automatically when you first use a tool — Claude will prompt you to complete OAuth in your browser.

To update a URL later:

```bash
claude mcp remove zoho-crm
claude mcp add --transport http zoho-crm "https://crm-data-metadata-<orgid>.zohomcp.in/mcp/<new-token>/message"
```

---

## Step 3 — Set Up Claude Desktop

Claude Desktop uses `stdio` transport, so it cannot connect to HTTP MCP servers directly. The bridge is **`mcp-remote`**, an npm package that proxies HTTP MCP servers over stdio.

### 3.1 — Locate the config file

| OS | Path |
|---|---|
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |

### 3.2 — Edit the config

Open the file and add your servers under `mcpServers`. Replace the Node path and MCP URLs with your own values:

```json
{
  "mcpServers": {
    "zoho-crm": {
      "command": "/Users/yourname/.nvm/versions/node/v20.x.x/bin/node",
      "args": [
        "/Users/yourname/.nvm/versions/node/v20.x.x/bin/npx",
        "-y",
        "mcp-remote@latest",
        "https://crm-data-metadata-<orgid>.zohomcp.in/mcp/<token>/message"
      ],
      "env": {
        "PATH": "/Users/yourname/.nvm/versions/node/v20.x.x/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
      }
    },
    "zoho-mail": {
      "command": "/Users/yourname/.nvm/versions/node/v20.x.x/bin/node",
      "args": [
        "/Users/yourname/.nvm/versions/node/v20.x.x/bin/npx",
        "-y",
        "mcp-remote@latest",
        "https://mail-sending-replies-<orgid>.zohomcp.in/mcp/<token>/message"
      ],
      "env": {
        "PATH": "/Users/yourname/.nvm/versions/node/v20.x.x/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
      }
    },
    "zoho-cliq": {
      "command": "/Users/yourname/.nvm/versions/node/v20.x.x/bin/node",
      "args": [
        "/Users/yourname/.nvm/versions/node/v20.x.x/bin/npx",
        "-y",
        "mcp-remote@latest",
        "https://cliq-messaging-<orgid>.zohomcp.in/mcp/<token>/message"
      ],
      "env": {
        "PATH": "/Users/yourname/.nvm/versions/node/v20.x.x/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
      }
    }
  }
}
```

> **Why absolute paths?** Claude Desktop launches `node` as a subprocess outside your shell session, so `PATH` and `nvm` are not available. Hardcoding the full binary path guarantees the correct Node version is used.

### 3.3 — Restart Claude Desktop

Fully quit (Cmd+Q on Mac, not just close the window) and reopen. The servers will appear in the MCP panel.

---

## Step 4 — Authenticate Each Server

Zoho MCP uses OAuth 2.0 with PKCE. Each server must be authorized once (per URL). `mcp-remote` handles this for Claude Desktop.

### For Claude Code

Authentication is triggered automatically. When you run a Zoho tool for the first time, Claude will show you an auth URL — open it, log in, and you're done.

You can also pre-authenticate manually:

```bash
# Run this for each server URL
/path/to/node /path/to/npx mcp-remote@latest "https://your-mcp-url/message"
# Opens a browser URL — complete login — then Ctrl+C
```

### For Claude Desktop (mcp-remote)

Run this in your terminal **before** opening Claude Desktop:

```bash
# Clear any stale auth sessions first
rm -rf ~/.mcp-auth/

# Run mcp-remote for the server you want to authenticate
/Users/yourname/.nvm/versions/node/v20.x.x/bin/npx mcp-remote@latest \
  "https://crm-data-metadata-<orgid>.zohomcp.in/mcp/<token>/message"
```

1. Copy the auth URL printed in the terminal
2. Open it in a **private/incognito browser window** (avoids OAuth state mismatch errors)
3. Log in with your Zoho account and grant access
4. Once you see a success message, press **Ctrl+C**
5. Repeat for Mail and Cliq URLs if needed
6. Open Claude Desktop — all servers should connect

---

## Verifying the Connection

### Claude Code

```bash
claude mcp list
# Should show all three servers with their URLs

# Start a session and test
claude
> Get me the list of CRM modules
```

### Claude Desktop

Open Claude Desktop and look for the MCP indicator (hammer icon or server count) in the chat interface. You can then type:

```
Get me all the leads from Zoho CRM
Send a test message to the #general channel in Cliq
```

---

## Troubleshooting

### "Failed to connect" on CRM in Claude Desktop

The URL changed (you modified tool selections in the Zoho MCP console). Each new URL needs fresh OAuth:

```bash
rm -rf ~/.mcp-auth/
/path/to/npx mcp-remote@latest "https://your-new-crm-url/message"
# Complete browser auth, then reopen Claude Desktop
```

### "Bad request" / HTTP 400 on OAuth callback

Caused by a state mismatch — your browser reused a cached or expired auth session. Fix:

1. Clear `~/.mcp-auth/` (see above)
2. Use a **fresh incognito/private window** for the auth URL
3. Do not reuse a URL from a previous terminal session

### Node version errors (e.g. "Unsupported engine")

Claude Desktop is picking up the wrong Node version. Check your config:

```bash
# Find the correct absolute path
nvm which 20  # or your version
# Use this full path in claude_desktop_config.json for both "command" and first "args" entry
```

### "MORE_THAN_MAX_LENGTH" on OAuth URL

You've selected too many tools in the Zoho MCP console. The generated scope string is too long for Zoho's OAuth endpoint. Reduce your tool selection (see [Tool Selection Guide](#tool-selection-guide)) to generate a shorter URL.

### Stale npx cache after switching Node versions

```bash
# Find and delete the stale mcp-remote cache
ls ~/.npm/_npx/
rm -rf ~/.npm/_npx/<cache-folder-for-mcp-remote>
```

### Mail or Cliq not connecting

Check that the server URL in your config matches exactly what was generated in the Zoho MCP console. Mail and Cliq URLs do not change unless you explicitly regenerate them.

---

## Tool Selection Guide

When creating your MCP server in the Zoho console, choose tools based on your use case. Selecting too many tools generates an OAuth URL that exceeds Zoho's character limit.

### Recommended CRM Tools (demo / learning)

| Category | Tools to Include |
|---|---|
| Leads | Get, GetList, Create, Update, Delete, Search, Convert, Clone |
| Deals | Get, GetList, Create, Update, Delete, Clone, Upsert |
| Contacts / Accounts | Get, GetList, Update |
| Generic Records | GetRecord, GetRecords, SearchRecords, MassUpdate |
| Notes | Get, GetList, Create, Update, Delete |
| Workflow Rules | Get, GetList, GetById, Create, Update, Delete, GetConfigurations, GetCount, GetUsage |
| Field Updates | Get, GetList, Create, Update, Delete |
| Email Notifications | Get, GetList, Create, Update |
| Email Templates | Get, GetList, Create, Update |
| Modules & Fields | GetModules, GetFields, GetLayouts, GetLayoutById |

### What to Avoid (for a lean setup)

Skip these unless you specifically need them — they add many scopes without adding demo value:

- Inventory templates, Mail merge templates
- Scoring rules, Sharing rules, Layout rules
- Custom buttons, Custom links, Custom views
- Automation functions, Webhooks
- Audit logs, Record locking
- Recycle bin, Territories, Holidays
- Blueprint transitions, Query actions

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                   Claude (AI)                    │
└────────────┬────────────────────────┬────────────┘
             │                        │
    Claude Code CLI           Claude Desktop App
    (HTTP transport)          (stdio transport)
             │                        │
             │                   mcp-remote
             │                (npm bridge package)
             │                        │
             └──────────┬─────────────┘
                        │ HTTPS + OAuth 2.0 PKCE
          ┌─────────────▼──────────────────────┐
          │        Zoho MCP Servers             │
          │  crm-data-metadata.zohomcp.in       │
          │  mail-sending-replies.zohomcp.in    │
          │  cliq-messaging.zohomcp.in          │
          └─────────────┬──────────────────────┘
                        │
          ┌─────────────▼──────────────────────┐
          │         Zoho APIs (India DC)        │
          │  zohoapis.in  ·  accounts.zoho.in   │
          └────────────────────────────────────┘
```

### How authentication works

1. `mcp-remote` (or Claude Code) generates a PKCE challenge and opens a Zoho OAuth URL
2. You log in and grant access in the browser
3. Zoho redirects to `localhost:PORT/oauth/callback` with an auth code
4. `mcp-remote` exchanges the code for an access token and stores it in `~/.mcp-auth/`
5. All subsequent tool calls use that token — no re-auth needed until the URL changes

---

## Quick Reference

```bash
# Add server (Claude Code)
claude mcp add --transport http zoho-crm "<url>"

# Remove server (Claude Code)
claude mcp remove zoho-crm

# List servers (Claude Code)
claude mcp list

# Re-authenticate (Claude Desktop)
rm -rf ~/.mcp-auth/
/path/to/npx mcp-remote@latest "<url>"
# → open auth URL in incognito → complete login → Ctrl+C → reopen Claude Desktop

# Find Node absolute path (nvm users)
nvm which 20
```

---

## Resources

- [Zoho MCP Console](https://mcp.zoho.in)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [MCP Specification](https://modelcontextprotocol.io)
- [mcp-remote on npm](https://www.npmjs.com/package/mcp-remote)
- [Zoho CRM API Scopes Reference](https://www.zoho.com/crm/developer/docs/api/v7/scopes.html)
