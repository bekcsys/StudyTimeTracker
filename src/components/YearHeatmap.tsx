"use client";

import { useMemo } from "react";
import {
  buildYearHeatmapCells,
  YEAR_HEATMAP_COLUMNS,
  YEAR_HEATMAP_ROWS,
} from "@/lib/stats";

type YearHeatmapProps = {
  year: number;
  yearDaySeconds: Record<string, number>;
  todayKey: string;
  onSelectDay?: (dayKey: string) => void;
};

export default function YearHeatmap({
  year,
  yearDaySeconds,
  todayKey,
  onSelectDay,
}: YearHeatmapProps) {
  const cells = useMemo(
    () => buildYearHeatmapCells(year, yearDaySeconds, todayKey),
    [year, yearDaySeconds, todayKey],
  );

  return (
    <section className="year-heatmap" aria-label={`${year} study days`}>
      <div className="year-heatmap-header">
        <h2>{year}</h2>
        <p className="year-heatmap-hint">Each cell is one day</p>
      </div>
      <div
        className="year-heatmap-grid"
        style={{
          gridTemplateRows: `repeat(${YEAR_HEATMAP_ROWS}, 1fr)`,
          gridTemplateColumns: `repeat(${YEAR_HEATMAP_COLUMNS}, 1fr)`,
        }}
        role="img"
        aria-label={`Year heatmap for ${year}`}
      >
        {cells.map((cell) => {
          if (cell.dateKey === null) {
            return (
              <span
                key={cell.key}
                className="year-heatmap-cell empty"
                aria-hidden
              />
            );
          }

          const label =
            cell.kind === "studied"
              ? `${cell.dateKey}: studied`
              : cell.kind === "future"
                ? `${cell.dateKey}: future`
                : `${cell.dateKey}: no study`;

          if (!onSelectDay) {
            return (
              <span
                key={cell.key}
                className={`year-heatmap-cell ${cell.kind}`}
                title={label}
                aria-label={label}
              />
            );
          }

          return (
            <button
              key={cell.key}
              type="button"
              className={`year-heatmap-cell ${cell.kind}`}
              title={label}
              aria-label={label}
              onClick={() => onSelectDay(cell.dateKey!)}
            />
          );
        })}
      </div>
    </section>
  );
}
