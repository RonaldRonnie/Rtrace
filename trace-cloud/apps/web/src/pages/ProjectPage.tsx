import { Link, useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Play, GitBranch, ExternalLink, Loader2, ChevronRight } from "lucide-react";
import { getProject, getScoreHistory } from "../api/projects";
import { listScans, triggerScan } from "../api/scans";
import { ScoreRing } from "../components/ScoreRing";
import { ScoreChart } from "../components/ScoreChart";
import { ScanStatusBadge } from "../components/ScanStatusBadge";
import type { ScanSummary } from "../types";
import { formatDistanceToNow, format } from "date-fns";

export function ProjectPage() {
  const { orgSlug, projectSlug } = useParams<{ orgSlug: string; projectSlug: string }>();
  const qc = useQueryClient();

  const { data: project, isLoading: projLoading } = useQuery({
    queryKey: ["project", orgSlug, projectSlug],
    queryFn: () => getProject(orgSlug!, projectSlug!),
    enabled: !!(orgSlug && projectSlug),
  });

  const { data: scansResult, isLoading: scansLoading } = useQuery({
    queryKey: ["scans", orgSlug, projectSlug],
    queryFn: () => listScans(orgSlug!, projectSlug!),
    enabled: !!(orgSlug && projectSlug),
    refetchInterval: (query) => {
      const d = query.state.data as { scans?: ScanSummary[] } | undefined;
      const hasRunning = d?.scans?.some((s) => s.status === "RUNNING" || s.status === "QUEUED");
      return hasRunning ? 3000 : false;
    },
  });
  const scans = scansResult?.scans ?? [];

  const { data: history = [] } = useQuery({
    queryKey: ["score-history", orgSlug, projectSlug],
    queryFn: () => getScoreHistory(orgSlug!, projectSlug!),
    enabled: !!(orgSlug && projectSlug),
  });

  const triggerMut = useMutation({
    mutationFn: () => triggerScan(orgSlug!, projectSlug!, { branch: project?.defaultBranch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["scans", orgSlug, projectSlug] });
      qc.invalidateQueries({ queryKey: ["score-history", orgSlug, projectSlug] });
    },
  });

  if (projLoading) {
    return <div className="p-6 text-center text-gray-400 text-sm py-12">Loading project…</div>;
  }

  if (!project) {
    return <div className="p-6 text-center text-gray-400 text-sm py-12">Project not found.</div>;
  }

  const latestScan = scans[0];

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Breadcrumb */}
      <nav className="text-sm text-gray-400 mb-5 flex items-center gap-1.5">
        <Link to={`/orgs/${orgSlug}`} className="hover:text-gray-700">{orgSlug}</Link>
        <ChevronRight size={14} />
        <span className="text-gray-700 font-medium">{project.name}</span>
      </nav>

      {/* Header */}
      <div className="flex items-start gap-5 mb-6">
        <ScoreRing score={latestScan?.overallScore} size={72} strokeWidth={6} />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold text-gray-900">{project.name}</h1>
            {project.repoUrl && (
              <a href={project.repoUrl} target="_blank" rel="noopener noreferrer"
                className="text-gray-400 hover:text-brand-500">
                <ExternalLink size={14} />
              </a>
            )}
          </div>
          {project.description && <p className="text-gray-500 mt-0.5">{project.description}</p>}
          <div className="mt-2 flex items-center gap-4 text-sm text-gray-400">
            {project.defaultBranch && (
              <span className="flex items-center gap-1.5">
                <GitBranch size={13} />{project.defaultBranch}
              </span>
            )}
            <span>{project._count?.scans ?? 0} scan{project._count?.scans !== 1 ? "s" : ""}</span>
          </div>
        </div>
        <button
          onClick={() => triggerMut.mutate()}
          disabled={triggerMut.isPending || latestScan?.status === "RUNNING" || latestScan?.status === "QUEUED"}
          className="flex items-center gap-2 bg-brand-500 hover:bg-brand-600 text-white font-medium px-4 py-2 rounded-lg text-sm transition-colors disabled:opacity-60 shrink-0"
        >
          {triggerMut.isPending ? <Loader2 size={14} className="animate-spin" /> : <Play size={14} />}
          Run scan
        </button>
      </div>

      {/* Score trend */}
      {history.length > 1 && (
        <div className="bg-white border border-gray-200 rounded-xl p-5 mb-6">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Score trend</h2>
          <ScoreChart history={history} />
        </div>
      )}

      {/* Scan history */}
      <h2 className="text-base font-semibold text-gray-800 mb-3">Scan history</h2>
      {scansLoading ? (
        <div className="py-10 text-center text-gray-400 text-sm">Loading scans…</div>
      ) : scans.length === 0 ? (
        <div className="bg-white border border-dashed border-gray-300 rounded-xl p-10 text-center">
          <p className="text-gray-500 font-medium">No scans yet</p>
          <p className="text-gray-400 text-sm mt-1">Click "Run scan" to start the first analysis.</p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-xl divide-y divide-gray-100 overflow-hidden">
          {scans.map((scan: ScanSummary) => (
            <Link
              key={scan.id}
              to={`/orgs/${orgSlug}/projects/${projectSlug}/scans/${scan.id}`}
              className="flex items-center gap-4 px-5 py-3.5 hover:bg-gray-50 transition-colors group"
            >
              <div className="w-8 h-8 shrink-0">
                {scan.overallScore != null ? (
                  <ScoreRing score={scan.overallScore} size={32} strokeWidth={3} />
                ) : (
                  <div className="w-8 h-8 rounded-full bg-gray-100" />
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <ScanStatusBadge status={scan.status} />
                  {scan.branch && (
                    <span className="text-xs text-gray-400 flex items-center gap-1">
                      <GitBranch size={11} />{scan.branch}
                    </span>
                  )}
                </div>
                <p className="text-xs text-gray-400 mt-0.5">
                  {formatDistanceToNow(new Date(scan.createdAt), { addSuffix: true })}
                  {" · "}
                  {format(new Date(scan.createdAt), "MMM d, yyyy HH:mm")}
                </p>
              </div>
              {scan.overallScore != null && (
                <span className="text-sm font-semibold text-gray-700 group-hover:text-brand-600">
                  {scan.overallScore.toFixed(1)}
                </span>
              )}
              <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-400" />
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
