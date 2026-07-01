import { Loader2, CheckCircle2, XCircle, Clock, Ban } from "lucide-react";
import type { ScanStatus } from "../types";
import clsx from "clsx";

interface ScanStatusBadgeProps {
  status: ScanStatus;
  size?: "sm" | "md";
}

const STATUS_CONFIG: Record<ScanStatus, { icon: React.ReactNode; label: string; className: string }> = {
  PENDING:   { icon: <Clock size={12} />,         label: "Pending",   className: "bg-gray-100 text-gray-600 ring-gray-200" },
  RUNNING:   { icon: <Loader2 size={12} className="animate-spin" />, label: "Running", className: "bg-blue-50 text-blue-700 ring-blue-200" },
  SUCCEEDED: { icon: <CheckCircle2 size={12} />,  label: "Passed",    className: "bg-green-50 text-green-700 ring-green-200" },
  FAILED:    { icon: <XCircle size={12} />,       label: "Failed",    className: "bg-red-50 text-red-700 ring-red-200" },
  CANCELLED: { icon: <Ban size={12} />,           label: "Cancelled", className: "bg-gray-100 text-gray-500 ring-gray-200" },
};

export function ScanStatusBadge({ status, size = "md" }: ScanStatusBadgeProps) {
  const { icon, label, className } = STATUS_CONFIG[status] ?? STATUS_CONFIG.PENDING;
  return (
    <span className={clsx(
      "inline-flex items-center gap-1 rounded-full font-medium ring-1",
      size === "sm" ? "px-2 py-0.5 text-xs" : "px-2.5 py-1 text-sm",
      className
    )}>
      {icon}
      {label}
    </span>
  );
}
