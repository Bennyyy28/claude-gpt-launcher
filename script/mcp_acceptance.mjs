#!/usr/bin/env node
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const binary = process.argv[2];
if (!binary) {
  console.error("usage: mcp_acceptance.mjs /path/to/ClaudeGPTMCP");
  process.exit(2);
}

const child = spawn(binary, [], { stdio: ["pipe", "pipe", "inherit"] });
const lines = createInterface({ input: child.stdout });
const pending = new Map();
let nextId = 1;

lines.on("line", (line) => {
  const message = JSON.parse(line);
  const waiter = pending.get(message.id);
  if (waiter) {
    pending.delete(message.id);
    waiter.resolve(message);
  }
});

function request(method, params = {}) {
  const id = nextId++;
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`timeout waiting for ${method}`));
    }, 120_000);
    pending.set(id, {
      resolve(message) {
        clearTimeout(timer);
        resolve(message);
      },
    });
  });
}

function notify(method, params = {}) {
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
}

try {
  const initialized = await request("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "claude-gpt-acceptance", version: "1.0.0" },
  });
  if (initialized.result?.serverInfo?.name !== "claude-gpt-harness") {
    throw new Error("unexpected initialize response");
  }

  notify("notifications/initialized");
  const listed = await request("tools/list");
  const names = listed.result?.tools?.map((tool) => tool.name) ?? [];
  if (!names.includes("claude_code_plan") || !names.includes("claude_code_edit")) {
    throw new Error(`missing tools: ${names.join(", ")}`);
  }

  const called = await request("tools/call", {
    name: "claude_code_plan",
    arguments: {
      projectPath: projectRoot,
      prompt: "Read Package.swift and state the two executable product names in one concise sentence.",
      model: "gpt-5.6-luna",
    },
  });
  const result = called.result;
  if (result?.isError || result?.structuredContent?.status !== "completed") {
    throw new Error(`tool failed: ${JSON.stringify(result)}`);
  }
  if (result.structuredContent.mode !== "plan" || result.structuredContent.model !== "gpt-5.6-luna") {
    throw new Error("structured content lost mode or model");
  }

  console.log(JSON.stringify({
    initialized: initialized.result.serverInfo,
    tools: names,
    call: {
      status: result.structuredContent.status,
      mode: result.structuredContent.mode,
      model: result.structuredContent.model,
      projectPath: result.structuredContent.projectPath,
    },
  }, null, 2));
} finally {
  child.stdin.end();
  child.kill("SIGTERM");
}
