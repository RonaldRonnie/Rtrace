import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Plus, Building2, FolderOpen, Activity } from "lucide-react";
import { useState } from "react";
import { useAuthStore } from "../stores/auth.store";
import { listOrgs, createOrg } from "../api/orgs";
import { ScoreRing } from "../components/ScoreRing";
import type { Org } from "../types";

export function DashboardPage() {
  const user = useAuthStore((s) => s.user);
  const [showNewOrg, setShowNewOrg] = useState(false);
  const [newOrgName, setNewOrgName] = useState("");
  const [creating, setCreating] = useState(false);

  const { data: orgs = [], refetch } = useQuery({ queryKey: ["orgs"], queryFn: listOrgs });

  async function handleCreateOrg(e: React.FormEvent) {
    e.preventDefault();
    setCreating(true);
    try {
      await createOrg({ name: newOrgName });
      setNewOrgName("");
      setShowNewOrg(false);
      refetch();
    } finally {
      setCreating(false);
    }
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Good morning, {user?.name?.split(" ")[0]}</h1>
        <p className="text-gray-500 mt-1">Here's an overview of your organizations and projects.</p>
      </div>

      {/* Stats strip */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        {[
          { icon: <Building2 size={18} className="text-brand-500" />, label: "Organizations", value: orgs.length },
          { icon: <FolderOpen size={18} className="text-green-500" />, label: "Projects", value: orgs.reduce((s, o) => s + (o._count?.projects ?? 0), 0) },
          { icon: <Activity size={18} className="text-amber-500" />, label: "Total members", value: orgs.reduce((s, o) => s + (o._count?.members ?? 0), 0) },
        ].map((stat) => (
          <div key={stat.label} className="bg-white border border-gray-200 rounded-xl px-5 py-4 flex items-center gap-4">
            <div className="p-2.5 bg-gray-50 rounded-lg">{stat.icon}</div>
            <div>
              <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
              <p className="text-sm text-gray-500">{stat.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Organizations */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-gray-800">Organizations</h2>
        <button
          onClick={() => setShowNewOrg(true)}
          className="flex items-center gap-1.5 text-sm font-medium text-brand-500 hover:text-brand-700"
        >
          <Plus size={14} />
          New organization
        </button>
      </div>

      {showNewOrg && (
        <form onSubmit={handleCreateOrg} className="bg-white border border-brand-200 rounded-xl p-4 mb-4 flex gap-2">
          <input
            value={newOrgName}
            onChange={(e) => setNewOrgName(e.target.value)}
            placeholder="Organization name"
            required
            autoFocus
            className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
          <button type="submit" disabled={creating}
            className="bg-brand-500 text-white px-4 py-2 rounded-lg text-sm font-medium disabled:opacity-60">
            {creating ? "Creating…" : "Create"}
          </button>
          <button type="button" onClick={() => setShowNewOrg(false)}
            className="text-gray-400 hover:text-gray-600 px-2">
            Cancel
          </button>
        </form>
      )}

      {orgs.length === 0 ? (
        <div className="bg-white border border-dashed border-gray-300 rounded-xl p-12 text-center">
          <Building2 size={32} className="text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500 font-medium">No organizations yet</p>
          <p className="text-gray-400 text-sm mt-1">Create one to start tracking project quality.</p>
          <button onClick={() => setShowNewOrg(true)}
            className="mt-4 bg-brand-500 text-white px-4 py-2 rounded-lg text-sm font-medium">
            Create your first organization
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {orgs.map((org: Org) => (
            <Link
              key={org.id}
              to={`/orgs/${org.slug}`}
              className="bg-white border border-gray-200 rounded-xl p-5 hover:border-brand-300 hover:shadow-sm transition-all group"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-brand-50 flex items-center justify-center text-brand-600 font-bold text-lg">
                    {org.name[0].toUpperCase()}
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900 group-hover:text-brand-600 transition-colors">{org.name}</h3>
                    <p className="text-xs text-gray-400">@{org.slug}</p>
                  </div>
                </div>
                <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full capitalize">{org.role?.toLowerCase()}</span>
              </div>
              <div className="mt-4 flex gap-4 text-sm text-gray-500">
                <span>{org._count?.projects ?? 0} project{org._count?.projects !== 1 ? "s" : ""}</span>
                <span>{org._count?.members ?? 0} member{org._count?.members !== 1 ? "s" : ""}</span>
                <span className="capitalize">{org.plan?.toLowerCase()}</span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
