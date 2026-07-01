/**
 * Structured logger — production uses JSON (pino-compatible shape),
 * development uses human-readable format. Zero hard dependencies: we use
 * Node's built-in process.stdout so the file compiles without installing pino.
 *
 * Replace the emit() implementation with pino.child() if you add pino to deps.
 */

type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | "fatal";

const LEVEL_NUMS: Record<LogLevel, number> = {
  trace: 10, debug: 20, info: 30, warn: 40, error: 50, fatal: 60,
};

const IS_PROD = process.env.NODE_ENV === "production";
const MIN_LEVEL = (process.env.LOG_LEVEL ?? (IS_PROD ? "info" : "debug")) as LogLevel;
const MIN_NUM = LEVEL_NUMS[MIN_LEVEL] ?? 30;

function emit(level: LogLevel, msg: string, extra?: Record<string, unknown>): void {
  if (LEVEL_NUMS[level] < MIN_NUM) return;

  if (IS_PROD) {
    const line = JSON.stringify({
      time: Date.now(),
      level: LEVEL_NUMS[level],
      msg,
      ...extra,
    });
    process.stdout.write(line + "\n");
  } else {
    const ts = new Date().toISOString().substring(11, 23);
    const prefix = `[${ts}] ${level.toUpperCase().padEnd(5)}`;
    const extras = extra && Object.keys(extra).length > 0
      ? " " + JSON.stringify(extra)
      : "";
    process.stdout.write(`${prefix} ${msg}${extras}\n`);
  }
}

export const logger = {
  trace: (msg: string, extra?: Record<string, unknown>) => emit("trace", msg, extra),
  debug: (msg: string, extra?: Record<string, unknown>) => emit("debug", msg, extra),
  info:  (msg: string, extra?: Record<string, unknown>) => emit("info",  msg, extra),
  warn:  (msg: string, extra?: Record<string, unknown>) => emit("warn",  msg, extra),
  error: (msg: string, extra?: Record<string, unknown>) => emit("error", msg, extra),
  fatal: (msg: string, extra?: Record<string, unknown>) => emit("fatal", msg, extra),
  child: (bindings: Record<string, unknown>) => ({
    trace: (msg: string, extra?: Record<string, unknown>) => emit("trace", msg, { ...bindings, ...extra }),
    debug: (msg: string, extra?: Record<string, unknown>) => emit("debug", msg, { ...bindings, ...extra }),
    info:  (msg: string, extra?: Record<string, unknown>) => emit("info",  msg, { ...bindings, ...extra }),
    warn:  (msg: string, extra?: Record<string, unknown>) => emit("warn",  msg, { ...bindings, ...extra }),
    error: (msg: string, extra?: Record<string, unknown>) => emit("error", msg, { ...bindings, ...extra }),
    fatal: (msg: string, extra?: Record<string, unknown>) => emit("fatal", msg, { ...bindings, ...extra }),
  }),
};
