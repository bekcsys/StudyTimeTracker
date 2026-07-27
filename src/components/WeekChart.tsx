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

function buildYTicks(axisMax: number): number[] {
  const steps = 3;
  const ticks: number[] = [];
  for (let step = 0; step <= steps; step += 1) {
    const value = (axisMax * step) / steps;
    ticks.push(Number(value.toFixed(4)));
  }
  return [...new Set(ticks)];
}

function formatAxisHours(hours: number): string {
  if (hours === 0) {
    return "0";
  }
  const rounded = Number(hours.toFixed(2));
  if (Number.isInteger(rounded)) {
    return `${rounded}h`;
  }
  return `${rounded}h`;
}

export default function WeekChart({ week }: WeekChartProps) {
  const gradientId = useId().replace(/:/g, "");

  const chart = useMemo(() => {
    const width = 260;
    const height = 132;
    const padLeft = 34;
    const padRight = 10;
    const padTop = 18;
    const padBottom = 24;
    const plotWidth = width - padLeft - padRight;
    const plotHeight = height - padTop - padBottom;
    const peakHours = Math.max(0, ...week.map((day) => day.seconds / 3600));
    const axisMax = peakHours + 1;

    const points = week.map((day, index) => {
      const hours = day.seconds / 3600;
      const x =
        padLeft +
        (week.length === 1 ? plotWidth / 2 : (index / (week.length - 1)) * plotWidth);
      const y = padTop + plotHeight * (1 - hours / axisMax);
      return { x, y, day };
    });

    const line = smoothPath(points.map(({ x, y }) => ({ x, y })));
    const area =
      points.length === 0
        ? ""
        : `${line} L ${points[points.length - 1].x} ${padTop + plotHeight} L ${points[0].x} ${padTop + plotHeight} Z`;

    const yTicks = buildYTicks(axisMax);

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
      axisMax,
    };
  }, [week]);

  return (
    <section className="week-chart" aria-label="Weekly study hours">
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
              chart.padTop + chart.plotHeight * (1 - tick / chart.axisMax);
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
                  {formatAxisHours(tick)}
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
