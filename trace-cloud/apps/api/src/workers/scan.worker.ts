/**
 * Scan worker — picks up jobs from the BullMQ "scan-jobs" queue and
 * runs the RTrace engine, persisting results to PostgreSQL.
 */
import "dotenv/config";
import { Worker, Job } from "bullmq";
import { Redis } from "ioredis";
import { prisma } from "../lib/prisma";
import { SCAN_QUEUE_NAME, ScanJobData } from "../lib/queue";
import { runScan } from "../services/scanner";
import { config } from "../config";
import { logger } from "../lib/logger";
import { metrics } from "../lib/metrics";

const connection = new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });

async function processScanJob(job: Job<ScanJobData>): Promise<void> {
  let { scanId, projectId, scanRoot, modules } = job.data;

  // Scheduled jobs have an empty scanId — create the scan record now
  if (!scanId && projectId) {
    const newScan = await prisma.scan.create({
      data: { projectId, status: "PENDING", triggeredBy: "scheduled" },
    });
    scanId = newScan.id;
  }

  logger.info("Scan started", { scanId, scanRoot, jobId: job.id });

  await prisma.scan.update({
    where: { id: scanId },
    data: { status: "RUNNING", startedAt: new Date() },
  });

  try {
    const result = await runScan(scanRoot, modules);

    // Upsert module scores
    const moduleScoreData = Object.entries(result.scores).map(([moduleId, sc]) => {
      const moduleDiags = result.diagnostics.filter((d) => d.module_id === moduleId);
      return {
        scanId,
        moduleId,
        moduleName: moduleIdToName(moduleId),
        score: sc.score,
        label: sc.label,
        errorCount: moduleDiags.filter((d) => d.severity === "error").length,
        warningCount: moduleDiags.filter((d) => d.severity === "warning").length,
        infoCount: moduleDiags.filter((d) => d.severity === "info").length,
      };
    });

    // Compute overall score (weighted average)
    const scores = Object.values(result.scores).map((s) => s.score);
    const overallScore = scores.length > 0 ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : null;
    const overallLabel = overallScore !== null ? scoreLabel(overallScore) : null;

    // Persist everything in a transaction
    await prisma.$transaction([
      prisma.scanModuleScore.createMany({ data: moduleScoreData }),
      prisma.diagnostic.createMany({
        data: result.diagnostics.map((d) => ({
          scanId,
          ruleId: d.rule_id,
          severity: d.severity,
          file: d.file,
          line: d.line ?? null,
          column: d.column ?? null,
          message: d.message,
          suggestion: d.suggestion ?? null,
          moduleId: d.module_id,
        })),
      }),
      prisma.scan.update({
        where: { id: scanId },
        data: {
          status: "SUCCEEDED",
          finishedAt: new Date(),
          overallScore,
          overallLabel,
        },
      }),
    ]);

    metrics.scansCompleted.inc();
    logger.info("Scan succeeded", { scanId, overallScore, overallLabel });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    metrics.scansFailed.inc();
    logger.error("Scan failed", { scanId, error: message });
    await prisma.scan.update({
      where: { id: scanId },
      data: { status: "FAILED", finishedAt: new Date(), errorMessage: message.slice(0, 2000) },
    });
    throw err;
  }
}

function moduleIdToName(id: string): string {
  const names: Record<string, string> = {
    rtrace: "Architecture Governance",
    reproducibility: "Reproducibility",
    datatrace: "Data Quality",
    docstrace: "Documentation",
    packageqa: "Package QA",
  };
  return names[id] ?? id;
}

function scoreLabel(score: number): string {
  if (score >= 90) return "Excellent";
  if (score >= 75) return "Good";
  if (score >= 60) return "Acceptable";
  if (score >= 40) return "Needs Attention";
  return "Critical";
}

const worker = new Worker<ScanJobData>(SCAN_QUEUE_NAME, processScanJob, {
  connection,
  concurrency: 2,
});

worker.on("completed", (job) => {
  logger.info("Job completed", { jobId: job.id });
});

worker.on("failed", (job, err) => {
  logger.error("Job failed", { jobId: job?.id, error: err.message });
});

worker.on("error", (err) => {
  logger.error("Worker error", { error: err.message });
});

async function gracefulShutdown() {
  logger.info("Worker shutting down...");
  await worker.close();
  await prisma.$disconnect();
  process.exit(0);
}

process.on("SIGTERM", gracefulShutdown);
process.on("SIGINT",  gracefulShutdown);

logger.info("Scan worker started", { queue: SCAN_QUEUE_NAME, concurrency: 2 });
