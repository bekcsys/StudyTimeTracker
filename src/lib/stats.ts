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
  topics: TopicStat[];
  trackingStartDate: string | null;
  calendarEpoch: string;
};

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
