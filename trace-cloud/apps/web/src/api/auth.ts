import { api } from "./client";
import type { User, ApiKey } from "../types";

export interface LoginPayload { email: string; password: string }
export interface RegisterPayload { email: string; name: string; password: string }

export async function login(payload: LoginPayload) {
  const { data } = await api.post<{ user: User; accessToken: string }>("/auth/login", payload);
  return data;
}

export async function register(payload: RegisterPayload) {
  const { data } = await api.post<{ user: User; accessToken: string }>("/auth/register", payload);
  return data;
}

export async function logout() {
  await api.post("/auth/logout");
}

export async function getMe() {
  const { data } = await api.get<{ user: User }>("/auth/me");
  return data.user;
}

export async function listApiKeys() {
  const { data } = await api.get<{ apiKeys: ApiKey[] }>("/auth/api-keys");
  return data.apiKeys;
}

export async function createApiKey(name: string) {
  const { data } = await api.post<{ apiKey: ApiKey; key: string }>("/auth/api-keys", { name });
  return data;
}

export async function deleteApiKey(id: string) {
  await api.delete(`/auth/api-keys/${id}`);
}

export async function updateMe(payload: { name?: string }) {
  const { data } = await api.patch<{ user: User }>("/auth/me", payload);
  return data.user;
}
