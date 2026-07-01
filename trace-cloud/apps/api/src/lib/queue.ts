import { Queue, Worker, Job } from "bullmq";
import { Redis } from "ioredis";
import { config } from "../config";

export const redis = new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });

export const SCAN_QUEUE_NAME = "scan-jobs";

export interface ScanJobData {
  scanId: string;
  projectId: string;
  scanRoot: string;
  modules: string[];
}

export function getScanQueue(): Queue<ScanJobData> {
  return new Queue<ScanJobData>(SCAN_QUEUE_NAME, { connection: redis });
}

export async function enqueueScan(data: ScanJobData): Promise<Job<ScanJobData>> {
  const queue = getScanQueue();
  return queue.add("scan", data, {
    attempts: 2,
    backoff: { type: "fixed", delay: 5000 },
    removeOnComplete: { count: 500 },
    removeOnFail: { count: 100 },
  });
}
