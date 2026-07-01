import { Link, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ChevronRight, ExternalLink, Loader2, GitBranch } from "lucide-react";
import { getScan } from "../api/scans";
import { ScoreRing } from "../components/ScoreRing";
import { DiagnosticsTable } from "../components/DiagnosticsTable";
import { ScanStatusBadge } from "../components/ScanStatusBadge";
import type { ModuleScore } from "../types";
import { format } from "date-fns";

const MODULE_LABELS: Record<string, string> = {
  documentation: "Documentation",
  testing: "Testing",
  reproducibility: "Reproducibility",
  packageqa: "Package QA",
  datatrace: "Data Trace",
};

export function ScanPage() {
  const { orgSlug, projectSlug, scanId } = useParams<{
    orgSlug: string;
    projectSlug: string;
    scanId: string;
  }>();

  const { data: scan, isLoading } = useQuery({
    queryKey: ["scan", scanId],
    queryFn: () => getScan(orgSlug!, projectSlug!, scanId!),
    enabled: !!(orgSlug && projectSlug && scanId),
    refetchInterval: (query) => {
      const s = query.state.data as { status?: string } | undefined;
      return s?.status === "RUNNING" || s?.status === "QUEUED" ? 3000 : false;
    },
  });

  function openReport() {
    window.open(`/api/orgs/${orgSlug}/projects/${projectSlug}/scans/${scanId}/report`, "_blank");
  }

  if (isLoading) {
    return <div className="p-6 py-12 text-center text-gray-400 text-sm">Loading scan…</div>;
  }

  if (!scan) {
    return <div className="p-6 py-12 text-center text-gray-400 text-sm">Scan not found.</div>;
  }

  const running = scan.status === "RUNNING" || scan.status === "QUEUED";

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Breadcrumb */}
      <nav className="text-sm text-gray-400 mb-5 flex items-center gap-1.5">
        <Link to={`/orgs/${orgSlug}`} className="hover:text-gray-700">{orgSlug}</Link>
        <ChevronRight size={14} />
        <Link to={`/orgs/${orgSlug}/projects/${projectSlug}`} className="hover:text-gray-700">{projectSlug}</Link>
        <ChevronRight size={14} />
        <span className="text-gray-700 font-medium">Scan</span>
      </nav>

      {/* Header */}
      <div className="flex items-start gap-5 mb-6">
        {running ? (
          <div className="w-16 h-16 flex items-center justify-center">
            <Loader2 size={32} className="text-brand-400 animate-spin" />
          </div>
        ) : (
          <ScoreRing score={scan.overallScore} size={72} strokeWidth={6} />
        )}
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <ScanStatusBadge status={scan.status} />
            {scan.branch && (
              <span className="text-sm text-gray-400 flex items-center gap-1.5">
                <GitBranch size={13} />{scan.branch}
              </span>
            )}
          </div>
          <p className="text-xs text-gray-400 mt-1">
            {format(new Date(scan.createdAt), "EEEE, MMMM d, yyyy 'at' HH:mm")}
          </p>
          {scan.overallLabel && (
            <p className="text-sm font-medium text-gray-600 mt-1">{scan.overallLabel}</p>
          )}
          {scan.errorMessage && (
            <p className="text-sm text-red-600 mt-1 font-mono">{scan.errorMessage}</p>
          )}
        </div>
        {scan.status === "SUCCEEDED" && (
          <button
            onClick={openReport}
            className="flex items-center gap-2 text-sm font-medium text-brand-500 hover:text-brand-700 border border-brand-200 hover:border-brand-400 px-3 py-1.5 rounded-lg transition-colors shrink-0"
          >
            <ExternalLink size={14} /> Full report
          </button>
        )}
      </div>

      {/* Module scores */}
      {scan.moduleScores && scan.moduleScores.length > 0 && (
        <div className="mb-6">
          <h2 className="text-base font-semibold text-gray-800 mb-3">Module scores</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3">
            {scan.moduleScores.map((ms: ModuleScore) => (
              <div key={ms.moduleId} className="bg-white border border-gray-200 rounded-xl p-4 flex flex-col items-center gap-2">
                <ScoreRing score={ms.score} size={56} strokeWidth={5} />
                <p className="text-xs font-medium text-gray-600 text-center">
                  {MODULE_LABELS[ms.moduleId] ?? ms.moduleName ?? ms.moduleId}
                </p>
                <p className="text-xs text-gray-400">{ms.label}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Diagnostics */}
      {scan.status === "SUCCEEDED" && (
        <div>
          <h2 className="text-base font-semibold text-gray-800 mb-3">Diagnostics</h2>
          <DiagnosticsTable
            orgSlug={orgSlug!}
            projectSlug={projectSlug!}
            scanId={scanId!}
          />
        </div>
      )}

      {running && (
        <div className="bg-blue-50 border border-blue-200 rounded-xl p-6 text-center">
          <Loader2 size={20} className="text-blue-400 animate-spin mx-auto mb-2" />
          <p className="text-sm text-blue-700 font-medium">Scan in progress…</p>
          <p className="text-xs text-blue-500 mt-0.5">This page will update automatically.</p>
        </div>
      )}
    </div>
  );
}
