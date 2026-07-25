"use client";

import { formatMinutes } from "@/lib/formatDuration";
import type { DayStats } from "@/lib/stats";

const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const QUALIFYING_SECONDS = 5 * 60;

type StudyCalendarProps = {
  year: number;
  month: number;
  days: Record<string, DayStats>;
  todayKey: string;
  trackingStartDate: string | null;
  selectedTopicId?: string;
  showAllTopics?: boolean;
  canGoPrev: boolean;
  onPrev: () => void;
  onToday: () => void;
  onNext: () => void;
};

function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

function mondayBasedWeekday(year: number, month: number, day: number): number {
  const jsDay = new Date(year, month - 1, day).getDay();
  return jsDay === 0 ? 6 : jsDay - 1;
}

export default function StudyCalendar({
  year,
  month,
  days,
  todayKey,
  trackingStartDate,
  selectedTopicId = "",
  showAllTopics = false,
  canGoPrev,
  onPrev,
  onToday,
  onNext,
}: StudyCalendarProps) {
  const totalDays = daysInMonth(year, month);
  const offset = mondayBasedWeekday(year, month, 1);
  const monthLabel = new Date(year, month - 1, 1).toLocaleString("en-US", {
    month: "long",
    year: "numeric",
  });

  const cells: Array<{ day: number | null; key: string }> = [];

  for (let i = 0; i < offset; i += 1) {
    cells.push({ day: null, key: `pad-${i}` });
  }

  for (let day = 1; day <= totalDays; day += 1) {
    const key = `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    cells.push({ day, key });
  }

  return (
    <section className="calendar">
      <div className="calendar-header">
        <h2>{monthLabel}</h2>
        <div className="calendar-nav">
          <button
            type="button"
            className="calendar-nav-arrow"
            onClick={onPrev}
            disabled={!canGoPrev}
            aria-label="Previous month"
            title="Previous"
          >
            ←
          </button>
          <button
            type="button"
            className="calendar-nav-arrow"
            onClick={onToday}
            aria-label="Today"
            title="Today"
          >
            🎁
          </button>
          <button
            type="button"
            className="calendar-nav-arrow"
            onClick={onNext}
            aria-label="Next month"
            title="Next"
          >
            →
          </button>
        </div>
      </div>

      <div className="calendar-grid" role="grid" aria-label={monthLabel}>
        {WEEKDAYS.map((label) => (
          <div key={label} className="calendar-weekday">
            {label}
          </div>
        ))}

        {cells.map((cell) => {
          if (cell.day === null) {
            return <div key={cell.key} className="calendar-cell empty" />;
          }

          const dayStats = days[cell.key];
          const visibleTopics = showAllTopics
            ? (dayStats?.topics ?? [])
            : (dayStats?.topics.filter((topic) => topic.id === selectedTopicId) ??
              []);
          const visibleSeconds = showAllTopics
            ? (dayStats?.totalSeconds ?? 0)
            : (visibleTopics[0]?.seconds ?? 0);
          const hasStudy = visibleSeconds > 0;
          const hasQualifyingStudy = visibleSeconds > QUALIFYING_SECONDS;
          const isToday = cell.key === todayKey;
          const isTrackable =
            trackingStartDate !== null &&
            cell.key >= trackingStartDate &&
            cell.key <= todayKey;

          return (
            <div
              key={cell.key}
              className={`calendar-cell${isToday ? " today" : ""}`}
            >
              <div className="calendar-day">
                <span>{cell.day}</span>
                {isTrackable && (
                  <span
                    className={
                      hasQualifyingStudy ? "day-mark studied" : "day-mark missed"
                    }
                    aria-label={
                      hasQualifyingStudy ? "Studied" : "No qualifying study"
                    }
                  >
                    {hasQualifyingStudy ? "✓" : "✗"}
                  </span>
                )}
              </div>

              {hasStudy && (
                <ul className="calendar-topics">
                  {visibleTopics.map((topic) => (
                    <li
                      key={`${cell.key}-${topic.id ?? topic.name}`}
                      className="calendar-topic"
                    >
                      <span
                        className="topic-dot"
                        style={{ backgroundColor: topic.color }}
                        aria-hidden
                      />
                      <span>{formatMinutes(topic.seconds)}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          );
        })}
      </div>
    </section>
  );
}
