"use client";

import { formatMinutes } from "@/lib/formatDuration";
import type { DayStats, WeekDay } from "@/lib/stats";

type WeekTopicGridProps = {
  week: WeekDay[];
  days: Record<string, DayStats>;
};

type TopicRow = {
  id: string;
  name: string;
  color: string;
  byDay: number[];
  totalSeconds: number;
};

function collectTopicRows(
  week: WeekDay[],
  days: Record<string, DayStats>,
): TopicRow[] {
  const map = new Map<string, TopicRow>();

  week.forEach((day, dayIndex) => {
    const topics = days[day.date]?.topics ?? [];
    for (const topic of topics) {
      const id = topic.id ?? topic.name;
      let row = map.get(id);
      if (!row) {
        row = {
          id,
          name: topic.name,
          color: topic.color,
          byDay: Array.from({ length: week.length }, () => 0),
          totalSeconds: 0,
        };
        map.set(id, row);
      }
      row.byDay[dayIndex] += topic.seconds;
      row.totalSeconds += topic.seconds;
    }
  });

  return [...map.values()].sort((a, b) => {
    if (b.totalSeconds !== a.totalSeconds) {
      return b.totalSeconds - a.totalSeconds;
    }
    return a.name.localeCompare(b.name, undefined, { sensitivity: "base" });
  });
}

function shortDayLabel(label: string): string {
  return label.slice(0, 2);
}

function tinyMinutes(seconds: number): string {
  if (seconds <= 0) {
    return "";
  }
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) {
    return `${minutes}`;
  }
  const hours = minutes / 60;
  return Number.isInteger(hours) ? `${hours}h` : `${hours.toFixed(1)}h`;
}

export default function WeekTopicGrid({ week, days }: WeekTopicGridProps) {
  const rows = collectTopicRows(week, days);

  if (week.length === 0 || rows.length === 0) {
    return null;
  }

  return (
    <section className="week-topic-grid" aria-label="Week topic breakdown">
      <div className="week-topic-grid-label">Topics this week</div>
      <table className="week-topic-table">
        <thead>
          <tr>
            <th scope="col" className="week-topic-name-col">
              <span className="sr-only">Topic</span>
            </th>
            {week.map((day) => (
              <th key={day.date} scope="col" title={day.date}>
                {shortDayLabel(day.label)}
              </th>
            ))}
            <th scope="col">Σ</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id}>
              <th scope="row" className="week-topic-name-col" title={row.name}>
                <span
                  className="topic-dot week-topic-dot"
                  style={{ backgroundColor: row.color }}
                  aria-label={row.name}
                />
              </th>
              {row.byDay.map((seconds, index) => {
                const day = week[index];
                const value = tinyMinutes(seconds);
                return (
                  <td
                    key={`${row.id}-${day?.date ?? index}`}
                    className={value ? "has-time" : "empty-time"}
                    title={
                      value
                        ? `${row.name} · ${day?.label}: ${formatMinutes(seconds)}`
                        : undefined
                    }
                  >
                    {value}
                  </td>
                );
              })}
              <td className="week-topic-total" title={formatMinutes(row.totalSeconds)}>
                {tinyMinutes(row.totalSeconds)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
