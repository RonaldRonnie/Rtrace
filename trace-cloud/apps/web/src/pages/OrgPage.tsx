import { Link, useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Plus, FolderOpen, Play, CheckCircle2, AlertCircle } from "lucide-react";
import { useState } from "react";
import { getOrg } from "../api/orgs";
import { listProjects, createProject } from "../api/projects";
import { ScoreRing } from "../components/ScoreRing";
import type { Project } from "../types";
import { formatDistanceToNow } from "date-fns";

export function OrgPage() {
  const { orgSlug } = useParams<{ orgSlug: string }>();
  const qc = useQueryClient();
  const [showNew, setShowNew] = useState(false);
  const [form, setForm] = useState({ name: "", description: "", repoUrl: "", scanRoot: "." });

  const { data: org } = useQuery({
    queryKey: ["org", orgSlug],
    queryFn: () => getOrg(orgSlug!),
    enabled: !!orgSlug,
  });

  const { data: projects = [], isLoading } = useQuery({
    queryKey: ["projects", orgSlug],
    queryFn: () => listProjects(orgSlug!),
    enabled: !!orgSlug,
  });

  const createMut = useMutation({
    mutationFn: (p: typeof form) => createProject(orgSlug!, p),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["projects", orgSlug] });
      setShowNew(false);
      setForm({ name: "", description: "", repoUrl: "", scanRoot: "." });
    },
  });

  if (!orgSlug) return null;

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-brand-50 flex items-center justify-center text-brand-600 font-bold text-lg">
            {org?.name[0]?.toUpperCase() ?? "?"}
          </div>
          <div>
            <h1 className="text-xl font-bold text-gray-900">{org?.name ?? orgSlug}</h1>
            <p className="text-sm text-gray-400">@{orgSlug} &middot; {org?._count?.members ?? 0} members</p>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-gray-800">Projects</h2>
        <button onClick={() => setShowNew(true)}
          className="flex items-center gap-1.5 text-sm font-medium bg-brand-500 text-white px-3 py-1.5 rounded-lg hover:bg-brand-600">
          <Plus size={14} /> New project
        </button>
      </div>

      {showNew && (
        <form
          onSubmit={(e) => { e.preventDefault(); createMut.mutate(form); }}
          className="bg-white border border-brand-200 rounded-xl p-5 mb-4 space-y-3"
        >
          <h3 className="font-semibold text-gray-800">New project</h3>
          {[
            { label: "Name *", key: "name", placeholder: "my-r-package", required: true },
            { label: "Description", key: "description", placeholder: "Optional description" },
            { label: "Repository URL", key: "repoUrl", placeholder: "https://github.com/org/repo" },
            { label: "Scan root", key: "scanRoot", placeholder: "." },
          ].map(({ label, key, placeholder, required }) => (
            <div key={key}>
              <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
              <input
                value={(form as Record<string, string>)[key]}
                onChange={(e) => setForm((f) => ({ ...f, [key]: e.target.value }))}
                placeholder={placeholder}
                required={required}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
          ))}
          <div className="flex gap-2 pt-1">
            <button type="submit" disabled={createMut.isPending}
              className="bg-brand-500 text-white px-4 py-2 rounded-lg text-sm font-medium disabled:opacity-60">
              {createMut.isPending ? "Creating…" : "Create project"}
            </button>
            <button type="button" onClick={() => setShowNew(false)} className="text-gray-500 hover:text-gray-700 px-3 py-2 text-sm">
              Cancel
            </button>
          </div>
        </form>
      )}

      {isLoading ? (
        <div className="py-12 text-center text-gray-400 text-sm">Loading projects…</div>
      ) : projects.length === 0 ? (
        <div className="bg-white border border-dashed border-gray-300 rounded-xl p-12 text-center">
          <FolderOpen size={32} className="text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500 font-medium">No projects yet</p>
          <p className="text-gray-400 text-sm mt-1">Create a project to start running quality scans.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {projects.map((p: Project) => {
            const latestScan = p.scans?.[0];
            return (
              <Link
                key={p.id}
                to={`/orgs/${orgSlug}/projects/${p.slug}`}
                className="bg-white border border-gray-200 rounded-xl p-5 flex items-center gap-5 hover:border-brand-300 hover:shadow-sm transition-all group"
              >
                <ScoreRing score={latestScan?.overallScore} size={56} strokeWidth={5} />
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold text-gray-900 group-hover:text-brand-600 transition-colors">{p.name}</h3>
                  {p.description && <p className="text-sm text-gray-400 truncate">{p.description}</p>}
                  <div className="mt-1 flex gap-3 text-xs text-gray-400">
                    <span>{p._count?.scans ?? 0} scan{p._count?.scans !== 1 ? "s" : ""}</span>
                    {latestScan && (
                      <span>Last: {formatDistanceToNow(new Date(latestScan.createdAt), { addSuffix: true })}</span>
                    )}
                  </div>
                </div>
                {latestScan?.overallLabel && (
                  <span className="text-sm font-medium text-gray-500 shrink-0">
                    {latestScan.overallLabel}
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
