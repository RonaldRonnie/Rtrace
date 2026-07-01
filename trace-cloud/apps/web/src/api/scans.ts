import { api } from "./client";
import type { Scan, Diagnostic } from "../types";

interface PaginatedScans {
  scans: Scan[];
  pagination: { page: number; limit: number; total: number; pages: number };
}

interface PaginatedDiagnostics {
  diagnostics: Diagnostic[];
  pagination: { page: number; limit: number; total: number; pages: number };
}

export async function listScans(orgSlug: string, projectSlug: string, page = 1) {
  const { data } = await api.get<PaginatedScans>(
    `/orgs/${orgSlug}/projects/${projectSlug}/scans`,
    { params: { page, limit: 20 } }
  );
  return data;
}

export async function triggerScan(
  orgSlug: string,
  projectSlug: string,
  payload?: { branch?: string; modules?: string[] }
) {
  const { data } = await api.post<{ scan: Scan }>(
    `/orgs/${orgSlug}/projects/${projectSlug}/scans`,
    payload ?? {}
  );
  return data.scan;
}

export async function getScan(orgSlug: string, projectSlug: string, scanId: string) {
  const { data } = await api.get<{ scan: Scan }>(
    `/orgs/${orgSlug}/projects/${projectSlug}/scans/${scanId}`
  );
  return data.scan;
}

export async function listDiagnostics(
  orgSlug: string,
  projectSlug: string,
  scanId: string,
  opts?: { severity?: string; module?: string; page?: number }
) {
  const { data } = await api.get<PaginatedDiagnostics>(
    `/orgs/${orgSlug}/projects/${projectSlug}/scans/${scanId}/diagnostics`,
    { params: { ...opts, limit: 50 } }
  );
  return data;
}

export async function deleteScan(orgSlug: string, projectSlug: string, scanId: string) {
  await api.delete(`/orgs/${orgSlug}/projects/${projectSlug}/scans/${scanId}`);
}
