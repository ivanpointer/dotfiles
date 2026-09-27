import type { Plugin } from "@opencode-ai/plugin";
import { spawn } from "node:child_process";

const ALERT_SCRIPT = `${process.env.HOME}/.codex/hooks/codex-say-alert.sh`;

function notify(payload: Record<string, unknown>): void {
  const child = spawn(ALERT_SCRIPT, [], {
    env: { ...process.env, SAY_ALERT_SESSION_PREFIX: "opencode" },
    stdio: ["pipe", "ignore", "ignore"],
  });
  child.on("error", () => undefined);
  child.stdin.end(JSON.stringify(payload));
  child.unref();
}

export const server: Plugin = async ({ directory }) => ({
  event: async ({ event }) => {
    if (event.type !== "session.idle") return;
    notify({
      hook_event_name: "Stop",
      cwd: directory,
      session_id: (event as { properties?: { sessionID?: string } }).properties?.sessionID,
    });
  },
});

export default { server };
