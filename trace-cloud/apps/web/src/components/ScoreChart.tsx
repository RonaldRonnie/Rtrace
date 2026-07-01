import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";
import { format } from "date-fns";
import type { ScoreHistoryPoint } from "../types";

interface ScoreChartProps {
  history: ScoreHistoryPoint[];
  height?: number;
}

interface ChartPoint {
  date: string;
  overall: number | null;
  [key: string]: number | null | string;
}

const MODULE_COLORS: Record<string, string> = {
  rtrace: "#3b5bdb",
  reproducibility: "#0ea5e9",
  datatrace: "#10b981",
  docstrace: "#f59e0b",
  packageqa: "#ef4444",
};

export function ScoreChart({ history, height = 240 }: ScoreChartProps) {
  if (!history || history.length === 0) {
    return (
      <div className="flex items-center justify-center h-40 text-gray-400 text-sm">
        No scan history yet. Trigger a scan to see trend data.
      </div>
    );
  }

  const points: ChartPoint[] = history.map((h) => {
    const point: ChartPoint = {
      date: format(new Date(h.createdAt), "MMM d"),
      overall: h.overallScore ?? null,
    };
    (h.moduleScores ?? []).forEach((m) => {
      point[m.moduleId] = m.score;
    });
    return point;
  });

  const modules = history.length > 0
    ? [...new Set(history.flatMap((h) => (h.moduleScores ?? []).map((m) => m.moduleId)))]
    : [];

  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={points} margin={{ top: 8, right: 16, left: 0, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis
          dataKey="date"
          tick={{ fontSize: 11, fill: "#9ca3af" }}
          tickLine={false}
          axisLine={false}
        />
        <YAxis
          domain={[0, 100]}
          tick={{ fontSize: 11, fill: "#9ca3af" }}
          tickLine={false}
          axisLine={false}
          width={28}
        />
        <Tooltip
          contentStyle={{ fontSize: 12, border: "1px solid #e5e7eb", borderRadius: 8 }}
          formatter={(v: number, name: string) => [
            `${v}/100`,
            name === "overall" ? "Overall" : name,
          ]}
        />
        <ReferenceLine y={90} stroke="#16a34a" strokeDasharray="4 4" strokeWidth={1} />
        <ReferenceLine y={75} stroke="#2563eb" strokeDasharray="4 4" strokeWidth={1} />
        <ReferenceLine y={60} stroke="#d97706" strokeDasharray="4 4" strokeWidth={1} />
        {modules.map((id) => (
          <Line
            key={id}
            type="monotone"
            dataKey={id}
            stroke={MODULE_COLORS[id] ?? "#9ca3af"}
            strokeWidth={1.5}
            dot={false}
            strokeDasharray="4 2"
            connectNulls
          />
        ))}
        <Line
          type="monotone"
          dataKey="overall"
          stroke="#0f172a"
          strokeWidth={2.5}
          dot={{ r: 3, fill: "#0f172a" }}
          connectNulls
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
