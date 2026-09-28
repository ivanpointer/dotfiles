/** Machine-wide Graft tool-result attribution for OpenCode's V1 plugin API. */
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

let runtime;

async function graftRuntime() {
  const claudeDir = execFileSync('/run/current-system/sw/bin/graft-claude-dir', [], {
    encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 2000,
  }).trim();
  if (!claudeDir) return null;
  const path = join(claudeDir, '..', 'hosts', 'native-attribution.js');
  return import(pathToFileURL(path).href);
}

function currentRuntime() {
  return runtime ??= graftRuntime().catch(() => {
    runtime = undefined; // A later nix-darwin switch may install the module.
    return null;
  });
}

export const GraftAttribution = async ({ directory }) => ({
  'tool.execute.after': async (input, output) => {
    try {
      const module = await currentRuntime();
      if (module) await module.observeOpenCodeAfterTool(input, output, directory);
    } catch {
      // Usage reporting must never change a tool result.
    }
  },
});
