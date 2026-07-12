#!/usr/bin/env node

import { existsSync, readFileSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const packageRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const appPath = join(homedir(), "Applications", "Claude GPT.app");
const backendPath = join(homedir(), ".local", "bin", "claude-gpt");
const mcpPath = join(appPath, "Contents", "Resources", "mcp-bin", "claude-gpt-mcp");
const args = process.argv.slice(2);
const json = args.includes("--json");
const positional = args.filter((argument) => argument !== "--json");

function run(command, commandArgs = [], options = {}) {
  return spawnSync(command, commandArgs, {
    cwd: options.cwd ?? packageRoot,
    encoding: "utf8",
    stdio: options.inherit ? "inherit" : "pipe",
    env: process.env,
  });
}

function commandPath(name) {
  const result = run("/usr/bin/which", [name]);
  return result.status === 0 ? result.stdout.trim() : null;
}

function emit(value, human) {
  if (json) {
    process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
  } else {
    process.stdout.write(`${human}\n`);
  }
}

function fail(message, details = {}) {
  if (json) {
    process.stdout.write(`${JSON.stringify({ ok: false, error: { message, ...details } }, null, 2)}\n`);
  } else {
    process.stderr.write(`claude-gpt-launcher: ${message}\n`);
  }
  process.exit(1);
}

function help() {
  process.stdout.write(`Claude GPT Launcher

Usage:
  claude-gpt-launcher doctor [--json]
  claude-gpt-launcher install [--json]
  claude-gpt-launcher open [--json]
  claude-gpt-launcher mcp install [--enable-edits] [--protected-remotes value] [--json]
  claude-gpt-launcher mcp status [--json]
  claude-gpt-launcher mcp remove [--json]
  claude-gpt-launcher uninstall [--json]

Commands:
  doctor     Check macOS, dependencies, application, backend, and MCP status.
  install    Build and install the backend helper and macOS application.
  open       Open the installed macOS application.
  mcp        Install, inspect, or remove the global Codex MCP registration.
  uninstall  Remove the MCP registration, application, and backend helper.

No credentials are accepted as command-line flags or stored by this CLI.
`);
}

function doctor() {
  const names = ["swift", "git", "curl", "claude", "claude-code-proxy"];
  const requirements = names.map((name) => {
    const path = commandPath(name);
    return { name, found: path !== null, path };
  });
  const codex = commandPath("codex");
  const mcp = codex ? run(codex, ["mcp", "get", "claude-gpt-harness"]) : null;
  const result = {
    ok: process.platform === "darwin" && process.arch === "arm64" && requirements.every((item) => item.found),
    command: "doctor",
    platform: { os: process.platform, arch: process.arch, supported: process.platform === "darwin" && process.arch === "arm64" },
    requirements,
    installation: {
      app: { installed: existsSync(appPath), path: appPath },
      backend: { installed: existsSync(backendPath), path: backendPath },
      mcp: { registered: mcp?.status === 0, path: mcpPath },
    },
  };
  const missing = requirements.filter((item) => !item.found).map((item) => item.name);
  emit(result, result.ok ? "System is ready." : `System is not ready. Missing: ${missing.join(", ") || "supported macOS hardware"}`);
  if (!result.ok) process.exitCode = 1;
}

function install() {
  if (process.platform !== "darwin" || process.arch !== "arm64") {
    fail("installation requires an Apple silicon Mac");
  }
  const required = ["swift", "git", "curl", "claude", "claude-code-proxy"];
  const missing = required.filter((name) => !commandPath(name));
  if (missing.length > 0) fail("missing required commands", { missing });

  const backend = run("/bin/bash", [join(packageRoot, "script", "install_backend.sh")], { inherit: !json });
  if (backend.status !== 0) fail("backend installation failed", { exitCode: backend.status });
  const app = run("/bin/bash", [join(packageRoot, "script", "build_and_run.sh"), "--install"], { inherit: !json });
  if (app.status !== 0) fail("application installation failed", { exitCode: app.status });
  emit({ ok: true, command: "install", appPath, backendPath }, `Installed Claude GPT at ${appPath}`);
}

function openApp() {
  if (!existsSync(appPath)) fail("application is not installed; run install first");
  const result = run("/usr/bin/open", [appPath]);
  if (result.status !== 0) fail("could not open application", { detail: result.stderr.trim() });
  emit({ ok: true, command: "open", appPath }, `Opened ${appPath}`);
}

function protectedRemotes() {
  const index = positional.indexOf("--protected-remotes");
  if (index === -1) return null;
  const value = positional[index + 1];
  if (!value || value.startsWith("--")) fail("--protected-remotes requires a comma-separated value");
  return value;
}

function ownsMcpRegistration(output) {
  return output.includes(`command: ${mcpPath}`);
}

function installedBundleIdentifier() {
  if (!existsSync(appPath)) return null;
  const result = run("/usr/libexec/PlistBuddy", ["-c", "Print :CFBundleIdentifier", join(appPath, "Contents", "Info.plist")]);
  return result.status === 0 ? result.stdout.trim() : null;
}

function ownsBackend() {
  if (!existsSync(backendPath)) return false;
  try {
    return readFileSync(backendPath, "utf8").includes("# Installed by claude-gpt-launcher");
  } catch {
    return false;
  }
}

function mcp(action) {
  const codex = commandPath("codex");
  if (!codex) fail("Codex CLI is not installed");
  if (action === "status") {
    const result = run(codex, ["mcp", "get", "claude-gpt-harness"]);
    emit(
      { ok: result.status === 0, command: "mcp status", registered: result.status === 0, output: result.stdout.trim() },
      result.status === 0 ? result.stdout.trim() : "MCP is not registered."
    );
    if (result.status !== 0) process.exitCode = 1;
    return;
  }
  if (action === "remove") {
    const current = run(codex, ["mcp", "get", "claude-gpt-harness"]);
    if (current.status === 0) {
      if (!ownsMcpRegistration(current.stdout)) fail("refusing to remove an unrelated MCP registration with the same name");
      const result = run(codex, ["mcp", "remove", "claude-gpt-harness"]);
      if (result.status !== 0) fail("could not remove MCP registration", { detail: result.stderr.trim() });
    }
    emit({ ok: true, command: "mcp remove", registered: false }, "Removed claude-gpt-harness MCP registration.");
    return;
  }
  if (action === "install") {
    if (!existsSync(mcpPath)) fail("MCP binary is missing; run install first");
    const current = run(codex, ["mcp", "get", "claude-gpt-harness"]);
    if (current.status === 0) {
      if (!ownsMcpRegistration(current.stdout)) fail("an unrelated MCP registration already uses claude-gpt-harness");
      run(codex, ["mcp", "remove", "claude-gpt-harness"]);
    }
    const commandArgs = ["mcp", "add"];
    const patterns = protectedRemotes();
    if (patterns) commandArgs.push("--env", `CLAUDE_GPT_PROTECTED_REMOTES=${patterns}`);
    const editsEnabled = positional.includes("--enable-edits");
    if (editsEnabled) commandArgs.push("--env", "CLAUDE_GPT_ENABLE_MCP_EDITS=1");
    commandArgs.push("claude-gpt-harness", "--", mcpPath);
    const result = run(codex, commandArgs);
    if (result.status !== 0) fail("could not register MCP", { detail: result.stderr.trim() });
    emit({ ok: true, command: "mcp install", registered: true, editsEnabled, protectedRemotesConfigured: patterns !== null }, "Registered claude-gpt-harness MCP.");
    return;
  }
  fail("mcp requires install, status, or remove");
}

function uninstall() {
  const removed = [];
  const skipped = [];
  const codex = commandPath("codex");
  if (codex) {
    const current = run(codex, ["mcp", "get", "claude-gpt-harness"]);
    if (current.status === 0) {
      if (ownsMcpRegistration(current.stdout)) {
        run(codex, ["mcp", "remove", "claude-gpt-harness"]);
        removed.push("claude-gpt-harness MCP");
      } else {
        skipped.push("unrelated claude-gpt-harness MCP");
      }
    }
  }
  if (existsSync(appPath)) {
    if (installedBundleIdentifier() === "app.claudegpt.launcher") {
      rmSync(appPath, { recursive: true, force: true });
      removed.push(appPath);
    } else {
      skipped.push(`unrelated app at ${appPath}`);
    }
  }
  if (existsSync(backendPath)) {
    if (ownsBackend()) {
      rmSync(backendPath, { force: true });
      removed.push(backendPath);
    } else {
      skipped.push(`unrelated helper at ${backendPath}`);
    }
  }
  emit({ ok: true, command: "uninstall", removed, skipped }, `Uninstall complete. Removed ${removed.length} owned item(s); skipped ${skipped.length} unrelated item(s).`);
}

const [command, subcommand] = positional;
switch (command) {
  case undefined:
  case "help":
  case "--help":
  case "-h": help(); break;
  case "doctor": doctor(); break;
  case "install": install(); break;
  case "open": openApp(); break;
  case "mcp": mcp(subcommand); break;
  case "uninstall": uninstall(); break;
  default: fail(`unknown command: ${command}`);
}
