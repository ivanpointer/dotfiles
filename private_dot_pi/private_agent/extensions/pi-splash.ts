import type {
  ExtensionAPI,
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";

const ESC = "\x1b[";
const HUE_OFFSET_RANGES = [
  [18, 55],
  [70, 115],
  [125, 155],
] as const;

function rgb(text: string, r: number, g: number, b: number): string {
  return `${ESC}38;2;${r};${g};${b}m${text}${ESC}0m`;
}

function hslToRgb(
  h: number,
  s: number,
  l: number,
): { r: number; g: number; b: number } {
  const a = s * Math.min(l, 1 - l);
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    return l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
  };
  return {
    r: Math.round(255 * f(0)),
    g: Math.round(255 * f(8)),
    b: Math.round(255 * f(4)),
  };
}

function randomHuePair(): { start: number; end: number } {
  const start = Math.random() * 360;
  const [min, max] =
    HUE_OFFSET_RANGES[Math.floor(Math.random() * HUE_OFFSET_RANGES.length)];
  const offset = min + Math.random() * (max - min);
  const direction = Math.random() < 0.5 ? -1 : 1;
  return { start, end: (start + direction * offset + 360) % 360 };
}

function hueGradient(text: string, startHue: number, endHue: number): string {
  const chars = [...text];
  const paintable = chars.filter((ch) => ch !== " ").length || 1;
  const start = hslToRgb(startHue, 0.95, 0.7);
  const end = hslToRgb(endHue, 0.95, 0.74);
  let seen = 0;
  return chars
    .map((ch) => {
      if (ch === " ") return ch;
      const t = seen++ / Math.max(1, paintable - 1);
      const r = Math.round(start.r + (end.r - start.r) * t);
      const g = Math.round(start.g + (end.g - start.g) * t);
      const b = Math.round(start.b + (end.b - start.b) * t);
      return rgb(ch, r, g, b);
    })
    .join("");
}

function stripAnsi(text: string): string {
  return text.replace(/\x1b\[[0-9;]*m/g, "");
}

function center(text: string, width: number): string {
  const visible = stripAnsi(text).length;
  const padding = Math.max(0, Math.floor((width - visible) / 2));
  return " ".repeat(padding) + text;
}

function nicePath(path: string): string {
  const home = process.env.HOME;
  return home && path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

async function getGitInfo(
  pi: ExtensionAPI,
  cwd: string,
): Promise<{ branch: string; status: string }> {
  const inside = await pi
    .exec("git", ["rev-parse", "--is-inside-work-tree"], { cwd, timeout: 1500 })
    .catch(() => undefined);
  if (!inside || inside.code !== 0 || inside.stdout.trim() !== "true") {
    return { branch: "not a git repo", status: "—" };
  }

  const [branchResult, statusResult] = await Promise.all([
    pi
      .exec("git", ["branch", "--show-current"], { cwd, timeout: 1500 })
      .catch(() => undefined),
    pi
      .exec("git", ["status", "--porcelain", "--branch"], {
        cwd,
        timeout: 1500,
      })
      .catch(() => undefined),
  ]);

  let branch = branchResult?.stdout.trim() || "detached HEAD";
  const lines = (statusResult?.stdout ?? "").trim().split("\n").filter(Boolean);
  const aheadBehind = lines[0]?.match(/\[(.+)\]/)?.[1];
  if (aheadBehind) branch += ` (${aheadBehind})`;

  const changes = lines.filter((line) => !line.startsWith("##"));
  const status =
    changes.length === 0
      ? "clean"
      : `${changes.length} change${changes.length === 1 ? "" : "s"}`;
  return { branch, status };
}

const PI_CHARS =
  "314159265358979323846264338327950288419716939937510582097494459230781640" +
  "628620899862803482534211706798214808651328230664709384460955058223172535" +
  "940812848111745028410270193852110555964462294895493038196442881097566593" +
  "344612847564823378678316527120190914564856692346034861045432664821339360" +
  "726024914127372458700660631558817488152092096282925409171536436789259036" +
  "001133053054882046652138414695194151160943305727036575959195309218611738" +
  "193261179310511854807446237996274956735188575272489122793818301194912983" +
  "367336244065664308602139494639522473719070217986094370277053921717629317" +
  "675238467481846766940513200056812714526356082778577134275778960917363717" +
  "872146844090122495343014654958537105079227968925892354201995611212902196";

function piGlyph(): string[] {
  const mask = [
    "         ###############################################  ",
    "      ################################################### ",
    "    ##################################################### ",
    "  ######################################################  ",
    " #######          ######           ########               ",
    "####              #####            ########               ",
    "###               #####            ########               ",
    "##               ######            ########               ",
    "                 ######           ########                ",
    "                ######            ########                ",
    "                ######            ########                ",
    "                ######           #########                ",
    "               #######           ########                 ",
    "              ########           ########                 ",
    "            #########            ########                 ",
    "           ##########            ########                 ",
    "         ############            #########                ",
    "        #############            ##########           ##  ",
    "      ##############              ############      ####  ",
    "     ###############              #####################   ",
    "     ##############                ###################    ",
    "     #############                  ################      ",
    "       #########                      ############        ",
  ];

  let digitIndex = 0;
  return mask.map((line) =>
    [...line]
      .map((ch) => {
        if (ch !== "#") return " ";
        const piChar = PI_CHARS[digitIndex % PI_CHARS.length];
        digitIndex += 1;
        return piChar;
      })
      .join(""),
  );
}

function makeSplash(
  theme: Theme,
  width: number,
  cwd: string,
  git: { branch: string; status: string },
  hues: { start: number; end: number },
): string[] {
  const dim = (text: string) => theme.fg("dim", text);
  const muted = (text: string) => theme.fg("muted", text);
  const accent = (text: string) => theme.fg("accent", text);
  const coloredStatus =
    git.status === "clean"
      ? theme.fg("success", git.status)
      : git.status === "—"
        ? theme.fg("dim", git.status)
        : theme.fg("warning", git.status);

  return [
    "",
    ...piGlyph().map((line) =>
      center(hueGradient(line, hues.start, hues.end), width),
    ),
    "",
    center(`${theme.bold(accent("pi"))} ${dim(`v${VERSION}`)}`, width),
    center(`${muted("path")} ${nicePath(cwd)}`, width),
    center(
      `${muted("git ")} ${git.branch} ${dim("•")} ${coloredStatus}`,
      width,
    ),
    "",
  ];
}

export default function (pi: ExtensionAPI) {
  async function installSplash(ctx: ExtensionContext) {
    if (!ctx.hasUI) return;
    const cwd = ctx.cwd;
    const hues = randomHuePair();
    let git = { branch: "loading…", status: "…" };

    ctx.ui.setHeader((_tui, theme) => ({
      render(width: number) {
        return makeSplash(theme, width, cwd, git, hues);
      },
      invalidate() {},
    }));

    git = await getGitInfo(pi, cwd);
    ctx.ui.setHeader((_tui, theme) => ({
      render(width: number) {
        return makeSplash(theme, width, cwd, git, hues);
      },
      invalidate() {},
    }));
  }

  pi.on("session_start", async (_event, ctx) => {
    await installSplash(ctx);
  });

  pi.registerCommand("splash-refresh", {
    description: "Refresh the pi splash header git/path information",
    handler: async (_args, ctx) => {
      await installSplash(ctx);
      ctx.ui.notify("Splash refreshed", "info");
    },
  });

  pi.registerCommand("builtin-header", {
    description: "Restore pi's built-in startup header",
    handler: async (_args, ctx) => {
      ctx.ui.setHeader(undefined);
      ctx.ui.notify("Built-in header restored", "info");
    },
  });
}
