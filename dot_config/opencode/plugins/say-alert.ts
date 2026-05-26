import type { Plugin } from "@opencode-ai/plugin"
import { spawn } from "node:child_process"

const ALERT_SCRIPT = "/Users/ivanpointer/.codex/hooks/codex-say-alert.sh"

function textFromContent(value: unknown): string {
  if (value === undefined || value === null) return ""
  if (typeof value === "string") return value
  if (Array.isArray(value)) {
    return value
      .map((item) => textFromContent(item))
      .filter(Boolean)
      .join(" ")
      .trim()
  }
  if (typeof value === "object") {
    const record = value as Record<string, unknown>
    return ["text", "content", "message", "prompt"]
      .map((key) => textFromContent(record[key]))
      .filter(Boolean)
      .join(" ")
      .trim()
  }
  return ""
}

function runAlert(payload: Record<string, unknown>): Promise<void> {
  return new Promise((resolve) => {
    const child = spawn(ALERT_SCRIPT, ["agent-ready"], {
      stdio: ["pipe", "ignore", "ignore"],
    })
    child.on("error", () => resolve())
    child.on("close", () => resolve())
    child.stdin.end(JSON.stringify(payload))
  })
}

export const server: Plugin = async ({ directory }) => {
  let firstUserMessage: string | undefined
  let firstUserMessageID: string | undefined

  return {
    event: async ({ event }) => {
      if (event.type === "message.updated" && firstUserMessage === undefined && firstUserMessageID === undefined) {
        const info = (event as any).properties?.info ?? {}
        if (info.role === "user") {
          firstUserMessageID = info.id
          const text = textFromContent(
            info.content ?? info.parts ?? info.message ?? info.text,
          )
          if (text) firstUserMessage = text
        }
      }

      if (event.type === "message.part.updated" && firstUserMessage === undefined) {
        const part = (event as any).properties?.part ?? {}
        if (part.messageID === firstUserMessageID && part.type === "text") {
          const text = textFromContent(part.text)
          if (text) firstUserMessage = text
        }
      }

      if (event.type !== "session.idle") return

      const payload: Record<string, unknown> = {
        hook_event_name: "Stop",
        cwd: directory,
        session_id: (event as any).properties?.sessionID,
      }
      if (firstUserMessage) payload.first_user_message = firstUserMessage
      await runAlert(payload)
    },
  }
}

export default { server }
