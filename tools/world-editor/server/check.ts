import { spawn } from "node:child_process";
import { resolve } from "node:path";

export interface CheckResult {
  passed: boolean;
  tests: { name: string; passed: boolean }[];
  // What the failing tests said about why.
  errors: string[];
}

const COLOUR = /\u001b\[[0-9;]*m/g;

// Each test's result from a run of scripts/quality/test.sh.
export function parseTestOutput(output: string, exitCode: number): CheckResult {
  const tests: CheckResult["tests"] = [];
  const errors: string[] = [];
  for (const raw of output.split("\n")) {
    const line = raw.replace(COLOUR, "").trim();
    const pass = /^PASS: (.*)$/.exec(line);
    const fail = /^(?:ERROR: )?FAIL: (.*)$/.exec(line);
    if (pass) {
      tests.push({ name: pass[1], passed: true });
    } else if (fail) {
      tests.push({ name: fail[1], passed: false });
    } else if (line.startsWith("ERROR: ") && !/test\(s\) failed$/.test(line)) {
      errors.push(line.slice("ERROR: ".length));
    }
  }
  const passed = exitCode === 0 && tests.length > 0 && tests.every((test) => test.passed);
  return { passed, tests, errors };
}

// Runs the game's own tests, the one home of the World's rules.
export function runCheck(repo: string): Promise<CheckResult> {
  return new Promise((done) => {
    const run = spawn(resolve(repo, "scripts/quality/test.sh"), { cwd: repo });
    let output = "";
    run.stdout.on("data", (chunk) => (output += chunk));
    run.stderr.on("data", (chunk) => (output += chunk));
    run.on("close", (code) => done(parseTestOutput(output, code ?? 1)));
  });
}
