import { api } from "./client";
import type { Project, ScoreHistoryPoint } from "../types";

export async function listProjects(orgSlug: string) {
  const { data } = await api.get<{ projects: Project[] }>(`/orgs/${orgSlug}/projects`);
  return data.projects;
}

export async function createProject(
  orgSlug: string,
  payload: { name: string; description?: string; repoUrl?: string; scanRoot?: string; defaultBranch?: string }
) {
  const { data } = await api.post<{ project: Project }>(`/orgs/${orgSlug}/projects`, payload);
  return data.project;
}

export async function getProject(orgSlug: string, projectSlug: string) {
  const { data } = await api.get<{ project: Project }>(`/orgs/${orgSlug}/projects/${projectSlug}`);
  return data.project;
}

export async function updateProject(orgSlug: string, projectSlug: string, payload: Partial<Project>) {
  const { data } = await api.patch<{ project: Project }>(`/orgs/${orgSlug}/projects/${projectSlug}`, payload);
  return data.project;
}

export async function deleteProject(orgSlug: string, projectSlug: string) {
  await api.delete(`/orgs/${orgSlug}/projects/${projectSlug}`);
}

export async function getScoreHistory(orgSlug: string, projectSlug: string, limit = 30) {
  const { data } = await api.get<{ history: ScoreHistoryPoint[] }>(
    `/orgs/${orgSlug}/projects/${projectSlug}/score-history`,
    { params: { limit } }
  );
  return data.history;
}
