interface ScoreRingProps {
  score: number | null | undefined;
  size?: number;
  strokeWidth?: number;
  label?: string;
  sublabel?: string;
  className?: string;
}

function scoreColor(score: number | null | undefined): string {
  if (score == null) return "#9ca3af";
  if (score >= 90) return "#16a34a";
  if (score >= 75) return "#2563eb";
  if (score >= 60) return "#d97706";
  if (score >= 40) return "#dc2626";
  return "#7c3aed";
}

function scoreLabel(score: number | null | undefined): string {
  if (score == null) return "—";
  if (score >= 90) return "Excellent";
  if (score >= 75) return "Good";
  if (score >= 60) return "Acceptable";
  if (score >= 40) return "Needs Attention";
  return "Critical";
}

export function ScoreRing({
  score,
  size = 80,
  strokeWidth = 7,
  label,
  sublabel,
  className = "",
}: ScoreRingProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const pct = score != null ? Math.min(100, Math.max(0, score)) / 100 : 0;
  const dash = pct * circumference;
  const color = scoreColor(score);

  return (
    <div className={`flex flex-col items-center gap-1 ${className}`}>
      <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="#e5e7eb"
          strokeWidth={strokeWidth}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeDasharray={`${dash} ${circumference - dash}`}
          strokeLinecap="round"
          style={{ transition: "stroke-dasharray 0.6s ease" }}
        />
        <text
          x="50%"
          y="50%"
          textAnchor="middle"
          dominantBaseline="central"
          style={{ transform: "rotate(90deg)", transformOrigin: "center", fontSize: size * 0.22 + "px", fontWeight: 700, fill: color }}
        >
          {score ?? "?"}
        </text>
      </svg>
      {(label ?? sublabel) && (
        <div className="text-center">
          {label && <p className="text-sm font-medium text-gray-700">{label}</p>}
          {sublabel && <p className="text-xs text-gray-400">{sublabel ?? scoreLabel(score)}</p>}
        </div>
      )}
    </div>
  );
}
