export type DayTopic = {
  id: string | null;
  name: string;
  color: string;
  seconds: number;
};

export type DayStats = {
  totalSeconds: number;
  topics: DayTopic[];
};

export type TopicStat = {
  id: string;
  name: string;
  color: string;
  totalSeconds: number;
};

export type WeekDay = {
  date: string;
  label: string;
  seconds: number;
  minutes: number;
};

export type Stats = {
  todaySeconds: number;
  totalSeconds: number;
  days: Record<string, DayStats>;
  week: WeekDay[];
  /** Day totals for the stats request year (YYYY-MM-DD → seconds). */
  yearDaySeconds: Record<string, number>;
  topics: TopicStat[];
  trackingStartDate: string | null;
  calendarEpoch: string;
};

export type YearHeatmapCell = {
  key: string;
  dateKey: string | null;
  kind: "empty" | "studied" | "past" | "future";
};

export const YEAR_HEATMAP_COLUMNS = 53;
export const YEAR_HEATMAP_ROWS = 7;
/** Match iOS year heatmap: studied if more than 1 minute. */
export const YEAR_HEATMAP_QUALIFYING_SECONDS = 60;

export const CALENDAR_EPOCH = { year: 2026, month: 7 };

export function isBeforeCalendarEpoch(year: number, month: number): boolean {
  return (
    year < CALENDAR_EPOCH.year ||
    (year === CALENDAR_EPOCH.year && month < CALENDAR_EPOCH.month)
  );
}

export function canGoToPreviousMonth(year: number, month: number): boolean {
  if (month === 1) {
    return !isBeforeCalendarEpoch(year - 1, 12);
  }
  return !isBeforeCalendarEpoch(year, month - 1);
}

export function chicagoTodayParts(): {
  year: number;
  month: number;
  todayKey: string;
} {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Chicago",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());

  const get = (type: string) =>
    parts.find((part) => part.type === type)?.value ?? "";

  return {
    year: Number(get("year")),
    month: Number(get("month")),
    todayKey: `${get("year")}-${get("month")}-${get("day")}`,
  };
}

/** Focus date for the week chart when viewing a calendar month. */
export function weekFocusForMonth(
  year: number,
  month: number,
  todayKey: string,
): string {
  const today = chicagoTodayParts();
  if (year === today.year && month === today.month) {
    return todayKey;
  }
  const lastDay = new Date(year, month, 0).getDate();
  const key = `${year}-${String(month).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
  return key > todayKey ? todayKey : key;
}

export function formatWeekRangeLabel(week: WeekDay[]): string {
  if (week.length === 0) {
    return "Week";
  }
  const start = week[0]?.date;
  const end = week[week.length - 1]?.date;
  if (!start || !end) {
    return "Week";
  }
  const startDate = new Date(`${start}T12:00:00`);
  const endDate = new Date(`${end}T12:00:00`);
  const startText = startDate.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
  const endText = endDate.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
  return `${startText} – ${endText}`;
}

function parseDateKey(dateKey: string): Date {
  const [year, month, day] = dateKey.split("-").map(Number);
  return new Date(year, month - 1, day, 12, 0, 0);
}

export function addDaysToDateKey(dateKey: string, days: number): string {
  const date = parseDateKey(dateKey);
  date.setDate(date.getDate() + days);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

/** Monday-based weekday: Mon=0 … Sun=6 (matches iOS year grid). */
export function mondayBasedWeekdayForKey(dateKey: string): number {
  const jsDay = parseDateKey(dateKey).getDay();
  return jsDay === 0 ? 6 : jsDay - 1;
}

export function weekStartKeyMonday(dateKey: string): string {
  return addDaysToDateKey(dateKey, -mondayBasedWeekdayForKey(dateKey));
}

export function buildYearHeatmapCells(
  year: number,
  yearDaySeconds: Record<string, number>,
  todayKey: string,
  qualifyingSeconds = YEAR_HEATMAP_QUALIFYING_SECONDS,
): YearHeatmapCell[] {
  const jan1 = `${year}-01-01`;
  const start = weekStartKeyMonday(jan1);
  const cells: YearHeatmapCell[] = [];

  for (let column = 0; column < YEAR_HEATMAP_COLUMNS; column += 1) {
    for (let row = 0; row < YEAR_HEATMAP_ROWS; row += 1) {
      const dateKey = addDaysToDateKey(start, column * YEAR_HEATMAP_ROWS + row);
      const keyYear = Number(dateKey.slice(0, 4));
      if (keyYear !== year) {
        cells.push({ key: `pad-${column}-${row}`, dateKey: null, kind: "empty" });
        continue;
      }
      const seconds = yearDaySeconds[dateKey] ?? 0;
      let kind: YearHeatmapCell["kind"] = "past";
      if (seconds > qualifyingSeconds) {
        kind = "studied";
      } else if (dateKey > todayKey) {
        kind = "future";
      }
      cells.push({ key: dateKey, dateKey, kind });
    }
  }

  return cells;
}
