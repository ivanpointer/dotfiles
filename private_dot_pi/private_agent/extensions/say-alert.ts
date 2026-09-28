import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ALERT_SCRIPT = `${process.env.HOME}/.local/bin/agent-completion-alert`;

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", (_event, ctx) => {
    const child = spawn(ALERT_SCRIPT, [], {
      env: { ...process.env, SAY_ALERT_SESSION_PREFIX: "pi" },
      stdio: ["pipe", "ignore", "ignore"],
    });
    child.on("error", () => undefined);
    child.stdin.end(JSON.stringify({
      hook_event_name: "Stop",
      cwd: ctx.cwd,
      session_id: ctx.sessionManager.getSessionId(),
    }));
    child.unref();
  });
}
