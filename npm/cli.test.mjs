import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("./cli.mjs", import.meta.url));

test("help documents the stable command surface", () => {
  const result = spawnSync(process.execPath, [cli, "--help"], { encoding: "utf8" });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /doctor \[--json\]/);
  assert.match(result.stdout, /mcp install/);
  assert.match(result.stdout, /uninstall/);
});

test("doctor emits parseable JSON without credentials", () => {
  const result = spawnSync(process.execPath, [cli, "doctor", "--json"], { encoding: "utf8" });
  assert.ok(result.status === 0 || result.status === 1);
  const output = JSON.parse(result.stdout);
  assert.equal(output.command, "doctor");
  assert.equal(Array.isArray(output.requirements), true);
  assert.equal(result.stdout.includes("ANTHROPIC_AUTH_TOKEN"), false);
});

test("unknown commands return structured errors", () => {
  const result = spawnSync(process.execPath, [cli, "unknown", "--json"], { encoding: "utf8" });
  assert.equal(result.status, 1);
  const output = JSON.parse(result.stdout);
  assert.equal(output.ok, false);
  assert.match(output.error.message, /unknown command/);
});

test("uninstall skips unrelated same-name artifacts", () => {
  const home = mkdtempSync(join(tmpdir(), "claude-gpt-uninstall-test-"));
  const app = join(home, "Applications", "Claude GPT.app");
  const helper = join(home, ".local", "bin", "claude-gpt");
  mkdirSync(join(app, "Contents"), { recursive: true });
  mkdirSync(join(home, ".local", "bin"), { recursive: true });
  writeFileSync(join(app, "Contents", "Info.plist"), "not our app");
  writeFileSync(helper, "#!/bin/sh\necho unrelated\n");

  try {
    const result = spawnSync(process.execPath, [cli, "uninstall", "--json"], {
      encoding: "utf8",
      env: { ...process.env, HOME: home },
    });
    assert.equal(result.status, 0);
    const output = JSON.parse(result.stdout);
    assert.equal(output.skipped.length, 2);
    assert.equal(existsSync(app), true);
    assert.equal(existsSync(helper), true);
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
});

test("backend installer refuses an unrelated existing helper", () => {
  const home = mkdtempSync(join(tmpdir(), "claude-gpt-install-test-"));
  const helper = join(home, ".local", "bin", "claude-gpt");
  mkdirSync(join(home, ".local", "bin"), { recursive: true });
  writeFileSync(helper, "#!/bin/sh\necho unrelated\n");

  try {
    const installer = fileURLToPath(new URL("../script/install_backend.sh", import.meta.url));
    const result = spawnSync("/bin/bash", [installer], {
      encoding: "utf8",
      env: { ...process.env, HOME: home },
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Refusing to overwrite unrelated file/);
    assert.equal(readFileSync(helper, "utf8"), "#!/bin/sh\necho unrelated\n");
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
});
