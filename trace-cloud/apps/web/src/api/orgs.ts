import { api } from "./client";
import type { Org } from "../types";

export async function listOrgs() {
  const { data } = await api.get<{ orgs: Org[] }>("/orgs");
  return data.orgs;
}

export async function createOrg(payload: { name: string; description?: string }) {
  const { data } = await api.post<{ org: Org }>("/orgs", payload);
  return data.org;
}

export async function getOrg(slug: string) {
  const { data } = await api.get<{ org: Org }>(`/orgs/${slug}`);
  return data.org;
}

export async function updateOrg(slug: string, payload: { name?: string; description?: string }) {
  const { data } = await api.patch<{ org: Org }>(`/orgs/${slug}`, payload);
  return data.org;
}

export async function listOrgMembers(orgSlug: string) {
  const { data } = await api.get(`/orgs/${orgSlug}/members`);
  return data.members;
}

export async function inviteMember(orgSlug: string, email: string, role = "MEMBER") {
  const { data } = await api.post(`/orgs/${orgSlug}/members`, { email, role });
  return data.member;
}
