/**
 * Lightweight in-process metrics registry — Prometheus text format output.
 * Not a replacement for a full metrics client, but gives oncall a /metrics
 * endpoint with zero external dependencies.
 */

interface Counter { type: "counter"; value: number; help: string }
interface Gauge   { type: "gauge";   value: number; help: string }
type Metric = Counter | Gauge;

const registry = new Map<string, Metric>();

export function counter(name: string, help: string): { inc: (n?: number) => void } {
  if (!registry.has(name)) registry.set(name, { type: "counter", value: 0, help });
  return {
    inc: (n = 1) => {
      const m = registry.get(name) as Counter;
      m.value += n;
    },
  };
}

export function gauge(name: string, help: string): { set: (n: number) => void; get: () => number } {
  if (!registry.has(name)) registry.set(name, { type: "gauge", value: 0, help });
  return {
    set: (n: number) => { (registry.get(name) as Gauge).value = n; },
    get: () => (registry.get(name) as Gauge).value,
  };
}

/** Render all metrics as Prometheus text format. */
export function renderMetrics(): string {
  const lines: string[] = [];
  for (const [name, m] of registry) {
    lines.push(`# HELP ${name} ${m.help}`);
    lines.push(`# TYPE ${name} ${m.type}`);
    lines.push(`${name} ${m.value}`);
  }
  return lines.join("\n") + "\n";
}

// ── Pre-registered application metrics ──────────────────────────────────────

export const metrics = {
  httpRequests:    counter("trace_http_requests_total", "Total HTTP requests"),
  httpErrors:      counter("trace_http_errors_total",   "Total HTTP 4xx/5xx responses"),
  scansTriggered:  counter("trace_scans_triggered_total", "Total scan jobs enqueued"),
  scansCompleted:  counter("trace_scans_completed_total", "Total scan jobs completed"),
  scansFailed:     counter("trace_scans_failed_total",    "Total scan jobs failed"),
  activeWorkers:   gauge("trace_active_workers", "Current number of active scan workers"),
  dbPoolSize:      gauge("trace_db_pool_size",   "Prisma connection pool approximate size"),
  authErrors:      counter("trace_auth_errors_total",  "Total authentication failures"),
  webhooksReceived:counter("trace_webhooks_received_total", "Total inbound webhook events"),
};
