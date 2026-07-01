export type Plan = "FREE" | "TEAM" | "BUSINESS" | "ENTERPRISE";
export type OrgRole = "OWNER" | "ADMIN" | "MEMBER" | "VIEWER";
export type ScanStatus = "PENDING" | "RUNNING" | "SUCCEEDED" | "FAILED" | "CANCELLED";

export interface User {
  id: string;
  email: string;
  name: string;
  avatarUrl?: string | null;
  createdAt: string;
  memberships?: Array<{ role: OrgRole; org: OrgSummary }>;
}

export interface OrgSummary {
  id: string;
  name: string;
  slug: string;
  plan: Plan;
}

export interface Org extends OrgSummary {
  description?: string | null;
  avatarUrl?: string | null;
  createdAt: string;
  updatedAt: string;
  role: OrgRole;
  _count: { members: number; projects: number };
}

export interface Project {
  id: string;
  name: string;
  slug: string;
  description?: string | null;
  repoUrl?: string | null;
  scanRoot: string;
  defaultBranch: string;
  badgeToken: string;
  orgId: string;
  createdAt: string;
  updatedAt: string;
  _count?: { scans: number };
  scans?: ScanSummary[];
}

export interface ScanSummary {
  id: string;
  status: ScanStatus;
  branch?: string | null;
  overallScore?: number | null;
  overallLabel?: string | null;
  createdAt: string;
}

export interface Scan {
  id: string;
  status: ScanStatus;
  branch?: string | null;
  commitSha?: string | null;
  triggeredBy?: string | null;
  startedAt?: string | null;
  finishedAt?: string | null;
  errorMessage?: string | null;
  overallScore?: number | null;
  overallLabel?: string | null;
  createdAt: string;
  projectId: string;
  moduleScores: ModuleScore[];
  _count?: { diagnostics: number };
}

export interface ModuleScore {
  id: string;
  moduleId: string;
  moduleName: string;
  score: number;
  label: string;
  errorCount: number;
  warningCount: number;
  infoCount: number;
}

export interface Diagnostic {
  id: string;
  ruleId: string;
  severity: "error" | "warning" | "info";
  file: string;
  line?: number | null;
  column?: number | null;
  message: string;
  suggestion?: string | null;
  moduleId: string;
}

export interface ScoreHistoryPoint {
  id: string;
  overallScore?: number | null;
  overallLabel?: string | null;
  createdAt: string;
  branch?: string | null;
  moduleScores: Array<{ moduleId: string; score: number; label: string }>;
}

export interface ApiKey {
  id: string;
  name: string;
  keyPrefix: string;
  lastUsedAt?: string | null;
  expiresAt?: string | null;
  createdAt: string;
}
