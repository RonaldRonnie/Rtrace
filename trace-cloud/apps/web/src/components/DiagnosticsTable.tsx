import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertCircle, AlertTriangle, Info, ChevronLeft, ChevronRight } from "lucide-react";
import { listDiagnostics } from "../api/scans";
import type { Diagnostic } from "../types";

interface DiagnosticsTableProps {
  orgSlug: string;
  projectSlug: string;
  scanId: string;
}

const SEV_ICON: Record<string, React.ReactNode> = {
  error:   <AlertCircle size={14} className="text-red-500 shrink-0" />,
  warning: <AlertTriangle size={14} className="text-amber-500 shrink-0" />,
  info:    <Info size={14} className="text-blue-400 shrink-0" />,
};

const SEV_BADGE: Record<string, string> = {
  error:   "bg-red-50 text-red-700 ring-red-200",
  warning: "bg-amber-50 text-amber-700 ring-amber-200",
  info:    "bg-blue-50 text-blue-700 ring-blue-200",
};

const MODULE_NAMES: Record<string, string> = {
  rtrace: "Architecture",
  reproducibility: "Reproducibility",
  datatrace: "Data Quality",
  docstrace: "Documentation",
  packageqa: "Package QA",
};

export function DiagnosticsTable({ orgSlug, projectSlug, scanId }: DiagnosticsTableProps) {
  const [page, setPage] = useState(1);
  const [severity, setSeverity] = useState<string>("");
  const [module, setModule] = useState<string>("");

  const { data, isLoading, isError } = useQuery({
    queryKey: ["diagnostics", orgSlug, projectSlug, scanId, page, severity, module],
    queryFn: () =>
      listDiagnostics(orgSlug, projectSlug, scanId, {
        page,
        ...(severity ? { severity } : {}),
        ...(module ? { module } : {}),
      }),
  });

  if (isLoading) return <div className="py-8 text-center text-gray-400 text-sm">Loading diagnostics…</div>;
  if (isError) return <div className="py-8 text-center text-red-500 text-sm">Failed to load diagnostics.</div>;

  const { diagnostics = [], pagination } = data ?? {};

  return (
    <div className="space-y-3">
      {/* Filters */}
      <div className="flex gap-2 flex-wrap">
        <select
          value={severity}
          onChange={(e) => { setSeverity(e.target.value); setPage(1); }}
          className="text-sm border border-gray-200 rounded-md px-2 py-1 bg-white text-gray-700"
        >
          <option value="">All severities</option>
          <option value="error">Errors</option>
          <option value="warning">Warnings</option>
          <option value="info">Info</option>
        </select>
        <select
          value={module}
          onChange={(e) => { setModule(e.target.value); setPage(1); }}
          className="text-sm border border-gray-200 rounded-md px-2 py-1 bg-white text-gray-700"
        >
          <option value="">All modules</option>
          {Object.entries(MODULE_NAMES).map(([id, name]) => (
            <option key={id} value={id}>{name}</option>
          ))}
        </select>
        {pagination && (
          <span className="text-sm text-gray-400 ml-auto self-center">
            {pagination.total} diagnostic{pagination.total !== 1 ? "s" : ""}
          </span>
        )}
      </div>

      {/* Table */}
      {diagnostics.length === 0 ? (
        <div className="py-8 text-center text-gray-400 text-sm border border-dashed border-gray-200 rounded-lg">
          {severity || module ? "No diagnostics match the selected filters." : "No diagnostics found for this scan."}
        </div>
      ) : (
        <div className="border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide w-20">Sev.</th>
                <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">File / Rule</th>
                <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide w-32">Module</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {diagnostics.map((d: Diagnostic) => (
                <tr key={d.id} className="hover:bg-gray-50">
                  <td className="px-3 py-2">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium ring-1 ${SEV_BADGE[d.severity] ?? SEV_BADGE.info}`}>
                      {SEV_ICON[d.severity]}
                      {d.severity}
                    </span>
                  </td>
                  <td className="px-3 py-2 max-w-0">
                    <div className="flex items-start gap-2">
                      <div className="min-w-0 flex-1">
                        <p className="font-mono text-xs text-gray-500 truncate">
                          {d.file}{d.line ? `:${d.line}` : ""}
                        </p>
                        <p className="text-gray-800 mt-0.5 leading-snug">{d.message}</p>
                        {d.suggestion && (
                          <p className="text-gray-400 text-xs mt-0.5 italic">{d.suggestion}</p>
                        )}
                        <span className="mt-1 inline-block font-mono text-xs text-gray-400">{d.ruleId}</span>
                      </div>
                    </div>
                  </td>
                  <td className="px-3 py-2 text-xs text-gray-500 whitespace-nowrap">
                    {MODULE_NAMES[d.moduleId] ?? d.moduleId}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination */}
      {pagination && pagination.pages > 1 && (
        <div className="flex items-center justify-between text-sm text-gray-500">
          <span>Page {pagination.page} of {pagination.pages}</span>
          <div className="flex gap-1">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="p-1 rounded hover:bg-gray-100 disabled:opacity-40"
            >
              <ChevronLeft size={16} />
            </button>
            <button
              onClick={() => setPage((p) => Math.min(pagination.pages, p + 1))}
              disabled={page === pagination.pages}
              className="p-1 rounded hover:bg-gray-100 disabled:opacity-40"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
