/**
 * Scheduled scan service — reads projects with a `scheduledCron` field and
 * registers BullMQ repeatable jobs so scans run on the configured schedule.
 *
 * Call `syncScheduledScans()` at startup and after any project update that
 * changes the cron expression.
 *
 * BullMQ repeatable jobs survive server restarts (the schedule is stored in
 * Redis). Calling this function is idempotent — it updates existing jobs and
 * removes stale ones.
 */
import { Queue, QueueEventsProducer } from "bullmq";
import { prisma } from "../lib/prisma";
import { redis, SCAN_QUEUE_NAME, ScanJobData } from "../lib/queue";
import { logger } from "../lib/logger";

function getScanQueue(): Queue<ScanJobData> {
  return new Queue<ScanJobData>(SCAN_QUEUE_NAME, { connection: redis });
}

/**
 * Sync scheduled scan jobs between the database and BullMQ.
 * Should be called once at startup and whenever a project's cron changes.
 */
export async function syncScheduledScans(): Promise<void> {
  const queue = getScanQueue();

  // Fetch all current repeatable jobs from Redis
  const existing = await queue.getRepeatableJobs();
  const existingByKey = new Map(existing.map((j) => [j.key, j]));

  // Fetch all projects with a scheduled cron
  const projects = await prisma.project.findMany({
    where: { scheduledCron: { not: null } },
    select: { id: true, slug: true, scanRoot: true, scheduledCron: true },
  });

  const managedKeys = new Set<string>();

  for (const project of projects) {
    if (!project.scheduledCron) continue;

    const jobName = `scheduled:${project.id}`;

    // The key BullMQ uses is: `jobName:cron`
    const expectedKey = `${SCAN_QUEUE_NAME}:${jobName}:::${project.scheduledCron}`;

    if (!existingByKey.has(expectedKey)) {
      // Create or update the repeatable job
      await queue.add(
        jobName,
        {
          scanId:    "", // worker will create the scan record
          projectId: project.id,
          scanRoot:  project.scanRoot,
          modules:   [],
        } as ScanJobData,
        {
          repeat: { pattern: project.scheduledCron, tz: "UTC" },
          jobId: `scheduled:${project.id}`,
        }
      );
      logger.info("Scheduled scan registered", { projectId: project.id, cron: project.scheduledCron });
    }

    managedKeys.add(expectedKey);
  }

  // Remove stale repeatable jobs that no longer have a matching project
  for (const [key, job] of existingByKey) {
    if (job.name.startsWith("scheduled:") && !managedKeys.has(key)) {
      await queue.removeRepeatableByKey(key);
      logger.info("Stale scheduled scan removed", { key });
    }
  }

  logger.info("Scheduled scan sync complete", {
    active: projects.length,
    removed: [...existingByKey.keys()].filter(
      (k) => existingByKey.get(k)?.name.startsWith("scheduled:") && !managedKeys.has(k)
    ).length,
  });
}

/**
 * Enable or update the scheduled scan for a project.
 */
export async function setProjectSchedule(projectId: string, cronExpression: string | null): Promise<void> {
  await prisma.project.update({
    where: { id: projectId },
    data: { scheduledCron: cronExpression },
  });
  await syncScheduledScans();
}
