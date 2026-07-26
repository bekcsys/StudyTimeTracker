"use client";

import { useId, useMemo } from "react";
import { formatMinutes } from "@/lib/formatDuration";
import type { WeekDay } from "@/lib/stats";

type WeekChartProps = {
  week: WeekDay[];
};

function smoothPath(points: Array<{ x: number; y: number }>): string {
  if (points.length === 0) {
    return "";
  }
  if (points.length === 1) {
    return `M ${points[0].x} ${points[0].y}`;
  }

  let path = `M ${points[0].x} ${points[0].y}`;
  for (let index = 0; index < points.length - 1; index += 1) {
    const current = points[index];
    const next = points[index + 1];
    const previous = points[index - 1] ?? current;
    const after = points[index + 2] ?? next;
    const control1x = current.x + (next.x - previous.x) / 6;
    const control1y = current.y + (next.y - previous.y) / 6;
    const control2x = next.x - (after.x - current.x) / 6;
    const control2y = next.y - (after.y - current.y) / 6;
    path += ` C ${control1x} ${control1y}, ${control2x} ${control2y}, ${next.x} ${next.y}`;
  }
  return path;
}

export default function WeekChart({ week }: WeekChartProps) {
  const gradientId = useId().replace(/:/g, "");

  const chart = useMemo(() => {
    const width = 260;
    const height = 132;
    const padLeft = 28;
    const padRight = 8;
    const padTop = 18;
    const padBottom = 24;
    const plotWidth = width - padLeft - padRight;
    const plotHeight = height - padTop - padBottom;
    const maxMinutes = Math.max(1, ...week.map((day) => day.minutes));

    const points = week.map((day, index) => {
      const x =
        padLeft +
        (week.length === 1 ? plotWidth / 2 : (index / (week.length - 1)) * plotWidth);
      const y = padTop + plotHeight * (1 - day.minutes / maxMinutes);
      return { x, y, day };
    });

    const line = smoothPath(points.map(({ x, y }) => ({ x, y })));
    const area =
      points.length === 0
        ? ""
        : `${line} L ${points[points.length - 1].x} ${padTop + plotHeight} L ${points[0].x} ${padTop + plotHeight} Z`;

    const yTicks = [0, Math.round(maxMinutes / 2), maxMinutes];

    return {
      width,
      height,
      padLeft,
      padTop,
      plotHeight,
      points,
      line,
      area,
      yTicks,
      maxMinutes,
    };
  }, [week]);

  return (
    <section className="week-chart" aria-label="Weekly study minutes">
      <div className="label">This week</div>
      <div className="week-chart-frame">
        <svg
          className="week-chart-svg"
          viewBox={`0 0 ${chart.width} ${chart.height}`}
          role="img"
        >
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--fg)" stopOpacity="0.28" />
              <stop offset="100%" stopColor="var(--fg)" stopOpacity="0.02" />
            </linearGradient>
          </defs>

          {chart.yTicks.map((tick) => {
            const y =
              chart.padTop + chart.plotHeight * (1 - tick / chart.maxMinutes);
            return (
              <g key={`y-${tick}`}>
                <line
                  className="week-chart-grid"
                  x1={chart.padLeft}
                  x2={chart.width - 8}
                  y1={y}
                  y2={y}
                />
                <text
                  className="week-chart-axis"
                  x={chart.padLeft - 6}
                  y={y + 3}
                  textAnchor="end"
                >
                  {tick}
                </text>
              </g>
            );
          })}

          {chart.area && (
            <path
              className="week-chart-area"
              d={chart.area}
              fill={`url(#${gradientId})`}
            />
          )}
          {chart.line && <path className="week-chart-line" d={chart.line} />}

          {chart.points.map((point) => {
            const labelY = Math.max(9, point.y - 8);
            return (
              <g key={point.day.date}>
                <circle
                  className="week-chart-dot"
                  cx={point.x}
                  cy={point.y}
                  r={2.75}
                />
                <text
                  className="week-chart-point-label"
                  x={point.x}
                  y={labelY}
                  textAnchor="middle"
                >
                  {formatMinutes(point.day.seconds)}
                </text>
                <text
                  className="week-chart-axis"
                  x={point.x}
                  y={chart.height - 6}
                  textAnchor="middle"
                >
                  {point.day.label}
                </text>
              </g>
            );
          })}
        </svg>
      </div>
    </section>
  );
}
