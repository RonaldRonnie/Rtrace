import { execFile } from "child_process";
import { promisify } from "util";
import { config } from "../config";

const execFileAsync = promisify(execFile);

export interface ScanResult {
  modules: string[];
  scores: Record<string, { score: number; label: string }>;
  summary: { error: number; warning: number; info: number };
  diagnostics: Array<{
    rule_id: string;
    severity: string;
    file: string;
    line: number | null;
    column: number | null;
    message: string;
    suggestion: string | null;
    module_id: string;
  }>;
}

/**
 * Run a full Trace Platform scan against a project root.
 * Tries the plumber HTTP API first (fast, no process spawn overhead);
 * falls back to Rscript subprocess if the API is unavailable.
 */
export async function runScan(root: string, modules: string[]): Promise<ScanResult> {
  if (config.RTRACE_API_URL) {
    try {
      return await scanViaApi(root, config.RTRACE_API_URL);
    } catch (err) {
      console.warn("[scanner] plumber API unavailable, falling back to Rscript subprocess:", (err as Error).message);
    }
  }
  return scanViaSubprocess(root, modules);
}

async function scanViaApi(root: string, apiUrl: string): Promise<ScanResult> {
  const resp = await fetch(`${apiUrl}/scan/full`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ root }),
    signal: AbortSignal.timeout(300_000), // 5 min
  });

  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`RTrace API error ${resp.status}: ${body}`);
  }

  const raw = (await resp.json()) as {
    modules: string[];
    scores: Record<string, { score: number; label: string }>;
    summary: { error: number; warning: number; info: number };
  };

  // The /scan/full endpoint doesn't return diagnostics directly.
  // Fetch them separately.
  const diagResp = await fetch(`${apiUrl}/scan`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ root, format: "json" }),
    signal: AbortSignal.timeout(300_000),
  });
  const diagRaw = (await diagResp.json()) as {
    diagnostics: Array<{
      rule_id: string; severity: string; file: string; line: number | null;
      column: number | null; message: string; suggestion: string | null;
    }> | null;
  };

  const diagnostics = (diagRaw.diagnostics ?? []).map((d) => ({
    ...d,
    module_id: inferModuleId(d.rule_id),
  }));

  return { ...raw, diagnostics };
}

async function scanViaSubprocess(root: string, modules: string[]): Promise<ScanResult> {
  const modulesJson = JSON.stringify(modules);
  const rScript = `
    suppressMessages(library(RTrace))
    root <- "${root.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"
    result <- platform_scan(root, use_cache = FALSE)
    diags  <- result$all_diagnostics$diagnostics
    diag_df <- if (length(diags) == 0) {
      data.frame(rule_id=character(), severity=character(), file=character(),
                 line=integer(), column=integer(), message=character(),
                 suggestion=character(), module_id=character(), stringsAsFactors=FALSE)
    } else {
      do.call(rbind, lapply(diags, function(d) {
        data.frame(
          rule_id    = d$rule_id %||% NA_character_,
          severity   = d$severity %||% NA_character_,
          file       = d$file %||% NA_character_,
          line       = if (is.null(d$line)) NA_integer_ else as.integer(d$line),
          column     = if (is.null(d$column)) NA_integer_ else as.integer(d$column),
          message    = d$message %||% NA_character_,
          suggestion = d$suggestion %||% NA_character_,
          module_id  = d$module_id %||% NA_character_,
          stringsAsFactors = FALSE
        )
      }))
    }
    out <- list(
      modules  = result$modules,
      scores   = lapply(result$scores, function(s) list(score=s$score, label=s$label)),
      summary  = as.list(summary(result$all_diagnostics)),
      diagnostics = lapply(seq_len(nrow(diag_df)), function(i) as.list(diag_df[i,]))
    )
    cat(jsonlite::toJSON(out, auto_unbox=TRUE, na='null'))
  `;

  const { stdout, stderr } = await execFileAsync(
    "Rscript",
    ["--vanilla", "-e", rScript],
    { timeout: 300_000, maxBuffer: 50 * 1024 * 1024 }
  );

  if (stderr && stderr.includes("Error")) {
    throw new Error(`Rscript error: ${stderr.slice(0, 2000)}`);
  }

  return JSON.parse(stdout) as ScanResult;
}

function inferModuleId(ruleId: string): string {
  if (ruleId.startsWith("reproducibility.")) return "reproducibility";
  if (ruleId.startsWith("datatrace.")) return "datatrace";
  if (ruleId.startsWith("docstrace.")) return "docstrace";
  if (ruleId.startsWith("packageqa.")) return "packageqa";
  return "rtrace";
}
