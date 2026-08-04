"use client";

import type { DayStats } from "@/lib/stats";

const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const QUALIFYING_SECONDS = 10 * 60;

type StudyCalendarProps = {
  year: number;
  month: number;
  days: Record<string, DayStats>;
  todayKey: string;
  weekFocusKey: string;
  trackingStartDate: string | null;
  canGoPrev: boolean;
  onPrev: () => void;
  onToday: () => void;
  onNext: () => void;
  onSelectDay: (dayKey: string) => void;
};

function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

function mondayBasedWeekday(year: number, month: number, day: number): number {
  const jsDay = new Date(year, month - 1, day).getDay();
  return jsDay === 0 ? 6 : jsDay - 1;
}

/** Sunday-start week keys for the week containing dayKey (Chicago date key). */
function sundayWeekKeys(dayKey: string): Set<string> {
  const [y, m, d] = dayKey.split("-").map(Number);
  const current = new Date(y, m - 1, d);
  const daysSinceSunday = current.getDay();
  const sunday = new Date(y, m - 1, d - daysSinceSunday);
  const keys = new Set<string>();
  for (let offset = 0; offset < 7; offset += 1) {
    const day = new Date(
      sunday.getFullYear(),
      sunday.getMonth(),
      sunday.getDate() + offset,
    );
    const key = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, "0")}-${String(day.getDate()).padStart(2, "0")}`;
    keys.add(key);
  }
  return keys;
}

export default function StudyCalendar({
  year,
  month,
  days,
  todayKey,
  weekFocusKey,
  trackingStartDate,
  canGoPrev,
  onPrev,
  onToday,
  onNext,
  onSelectDay,
}: StudyCalendarProps) {
  const totalDays = daysInMonth(year, month);
  const offset = mondayBasedWeekday(year, month, 1);
  const monthLabel = new Date(year, month - 1, 1).toLocaleString("en-US", {
    month: "long",
    year: "numeric",
  });
  const focusedWeek = sundayWeekKeys(weekFocusKey);

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
          const daySeconds = dayStats?.totalSeconds ?? 0;
          const hasStudy = (dayStats?.topics.length ?? 0) > 0;
          const hasQualifyingStudy = daySeconds > QUALIFYING_SECONDS;
          const isToday = cell.key === todayKey;
          const isFuture = cell.key > todayKey;
          const inFocusedWeek = focusedWeek.has(cell.key);
          const isTrackable =
            trackingStartDate !== null &&
            cell.key >= trackingStartDate &&
            cell.key <= todayKey;

          return (
            <button
              type="button"
              key={cell.key}
              className={[
                "calendar-cell",
                "calendar-cell-button",
                isToday ? "today" : "",
                isFuture ? "future" : "",
                isTrackable ? "trackable" : "",
                hasQualifyingStudy ? "studied" : "",
                isTrackable && !hasQualifyingStudy ? "missed" : "",
                hasStudy ? "has-study" : "",
                inFocusedWeek ? "week-focus" : "",
              ]
                .filter(Boolean)
                .join(" ")}
              onClick={() => onSelectDay(cell.key)}
              aria-label={`Show week containing ${cell.key}`}
              aria-pressed={inFocusedWeek}
            >
              <div className="calendar-day">
                <span>{cell.day}</span>
                {isTrackable && (
                  <span
                    className={
                      hasQualifyingStudy ? "day-mark studied" : "day-mark missed"
                    }
                    aria-label={
                      hasQualifyingStudy
                        ? "Studied more than 10 minutes"
                        : "Studied 10 minutes or less"
                    }
                  >
                    {hasQualifyingStudy ? "✓" : "✗"}
                  </span>
                )}
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}
