import { useState, FormEvent } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Key, Plus, Trash2, Copy, Check } from "lucide-react";
import { useAuthStore } from "../stores/auth.store";
import { updateMe, listApiKeys, createApiKey, deleteApiKey } from "../api/auth";
import type { ApiKey } from "../types";
import { format } from "date-fns";

export function SettingsPage() {
  const storedUser = useAuthStore((s) => s.user);
  const setAuth = useAuthStore((s) => s.setAuth);
  const accessToken = useAuthStore((s) => s.accessToken);
  const qc = useQueryClient();

  // Profile
  const [name, setName] = useState(storedUser?.name ?? "");
  const [profileSaved, setProfileSaved] = useState(false);
  const [profileError, setProfileError] = useState("");

  async function handleProfileSave(e: FormEvent) {
    e.preventDefault();
    setProfileError("");
    try {
      const updated = await updateMe({ name });
      if (accessToken) setAuth(updated, accessToken);
      else setAuth(updated, "");
      setProfileSaved(true);
      setTimeout(() => setProfileSaved(false), 2000);
    } catch {
      setProfileError("Failed to save profile.");
    }
  }

  // API keys
  const { data: keys = [] } = useQuery({ queryKey: ["api-keys"], queryFn: listApiKeys });
  const [showNew, setShowNew] = useState(false);
  const [newKeyName, setNewKeyName] = useState("");
  const [createdKey, setCreatedKey] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const createMut = useMutation({
    mutationFn: (n: string) => createApiKey(n),
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ["api-keys"] });
      setCreatedKey(data.key);
      setNewKeyName("");
      setShowNew(false);
    },
  });

  const deleteMut = useMutation({
    mutationFn: (id: string) => deleteApiKey(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["api-keys"] }),
  });

  function copyKey() {
    if (!createdKey) return;
    navigator.clipboard.writeText(createdKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <div className="p-6 max-w-2xl mx-auto space-y-8">
      <h1 className="text-xl font-bold text-gray-900">Settings</h1>

      {/* Profile */}
      <section className="bg-white border border-gray-200 rounded-xl p-6">
        <h2 className="text-base font-semibold text-gray-800 mb-4">Profile</h2>
        <form onSubmit={handleProfileSave} className="space-y-4">
          {profileError && (
            <div className="text-red-600 text-sm">{profileError}</div>
          )}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input
              value={storedUser?.email ?? ""}
              disabled
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm bg-gray-50 text-gray-400"
            />
          </div>
          <button
            type="submit"
            className="bg-brand-500 hover:bg-brand-600 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
          >
            {profileSaved ? "Saved!" : "Save profile"}
          </button>
        </form>
      </section>

      {/* API Keys */}
      <section className="bg-white border border-gray-200 rounded-xl p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-base font-semibold text-gray-800">API keys</h2>
            <p className="text-sm text-gray-400 mt-0.5">Use API keys to authenticate with the Trace Cloud REST API.</p>
          </div>
          <button
            onClick={() => setShowNew(true)}
            className="flex items-center gap-1.5 text-sm font-medium text-brand-500 hover:text-brand-700"
          >
            <Plus size={14} /> New key
          </button>
        </div>

        {createdKey && (
          <div className="mb-4 bg-green-50 border border-green-200 rounded-lg p-4">
            <p className="text-sm font-medium text-green-800 mb-1">Save this key — it won't be shown again.</p>
            <div className="flex items-center gap-2">
              <code className="flex-1 text-sm font-mono bg-white border border-green-200 px-3 py-1.5 rounded truncate">
                {createdKey}
              </code>
              <button
                onClick={copyKey}
                className="text-green-600 hover:text-green-800 p-1.5"
                title="Copy"
              >
                {copied ? <Check size={14} /> : <Copy size={14} />}
              </button>
            </div>
            <button onClick={() => setCreatedKey(null)} className="text-xs text-green-600 mt-2 hover:underline">
              Done
            </button>
          </div>
        )}

        {showNew && (
          <form
            onSubmit={(e) => { e.preventDefault(); createMut.mutate(newKeyName); }}
            className="mb-4 flex gap-2"
          >
            <input
              value={newKeyName}
              onChange={(e) => setNewKeyName(e.target.value)}
              placeholder="Key name (e.g. CI/CD)"
              required
              autoFocus
              className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <button type="submit" disabled={createMut.isPending}
              className="bg-brand-500 text-white px-4 py-2 rounded-lg text-sm font-medium disabled:opacity-60">
              {createMut.isPending ? "Creating…" : "Create"}
            </button>
            <button type="button" onClick={() => setShowNew(false)} className="text-gray-400 hover:text-gray-600 px-2 text-sm">
              Cancel
            </button>
          </form>
        )}

        {keys.length === 0 ? (
          <div className="text-center py-8 border border-dashed border-gray-200 rounded-lg text-gray-400 text-sm">
            No API keys yet.
          </div>
        ) : (
          <div className="space-y-2">
            {keys.map((key: ApiKey) => (
              <div key={key.id} className="flex items-center gap-3 px-3 py-2.5 bg-gray-50 rounded-lg">
                <Key size={14} className="text-gray-400 shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-800">{key.name}</p>
                  <p className="text-xs text-gray-400 font-mono">{key.keyPrefix}…</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-xs text-gray-400">Created {format(new Date(key.createdAt), "MMM d, yyyy")}</p>
                  {key.lastUsedAt && (
                    <p className="text-xs text-gray-400">Last used {format(new Date(key.lastUsedAt), "MMM d")}</p>
                  )}
                </div>
                <button
                  onClick={() => { if (confirm(`Delete key "${key.name}"?`)) deleteMut.mutate(key.id); }}
                  disabled={deleteMut.isPending}
                  className="text-gray-300 hover:text-red-500 p-1 transition-colors"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
