"use client";

import { useCallback, useEffect, useState } from "react";
import StudyCalendar from "@/components/StudyCalendar";
import StudyTimer, { type Topic } from "@/components/StudyTimer";
import ThemeToggle from "@/components/ThemeToggle";
import TopicHours from "@/components/TopicHours";
import {
  canGoToPreviousMonth,
  chicagoTodayParts,
  type Stats,
} from "@/lib/stats";

async function fetchTopics(): Promise<Topic[]> {
  const response = await fetch("/api/topics", { cache: "no-store" });
  if (!response.ok) {
    return [];
  }
  const data = (await response.json()) as { topics: Topic[] };
  return data.topics;
}

export default function HomePage() {
  const initial = chicagoTodayParts();
  const [year, setYear] = useState(initial.year);
  const [month, setMonth] = useState(initial.month);
  const [todayKey, setTodayKey] = useState(initial.todayKey);
  const [stats, setStats] = useState<Stats>({
    todaySeconds: 0,
    totalSeconds: 0,
    days: {},
    topics: [],
    trackingStartDate: null,
    calendarEpoch: "2026-07-01",
  });
  const [topics, setTopics] = useState<Topic[]>([]);
  const [selectedTopicId, setSelectedTopicId] = useState("");
  const [newTopicName, setNewTopicName] = useState("");
  const [busyTopic, setBusyTopic] = useState(false);
  const [topicError, setTopicError] = useState<string | null>(null);

  const loadStats = useCallback(async (y: number, m: number) => {
    const response = await fetch(`/api/stats?year=${y}&month=${m}`, {
      cache: "no-store",
    });
    if (!response.ok) {
      return;
    }
    setStats((await response.json()) as Stats);
  }, []);

  const loadTopics = useCallback(async () => {
    const rows = await fetchTopics();
    setTopics(rows);
    setSelectedTopicId((current) => current || rows[0]?.id || "");
  }, []);

  const refresh = useCallback(async () => {
    await Promise.all([loadStats(year, month), loadTopics()]);
  }, [loadStats, loadTopics, year, month]);

  useEffect(() => {
    const today = chicagoTodayParts();
    setTodayKey(today.todayKey);
    void refresh();
  }, [year, month, refresh]);

  useEffect(() => {
    const id = window.setInterval(() => {
      void loadStats(year, month);
    }, 2000);
    return () => window.clearInterval(id);
  }, [year, month, loadStats]);

  const goPrev = () => {
    if (!canGoToPreviousMonth(year, month)) {
      return;
    }
    if (month === 1) {
      setYear((value) => value - 1);
      setMonth(12);
      return;
    }
    setMonth((value) => value - 1);
  };

  const goNext = () => {
    if (month === 12) {
      setYear((value) => value + 1);
      setMonth(1);
      return;
    }
    setMonth((value) => value + 1);
  };

  const goToday = () => {
    const today = chicagoTodayParts();
    setYear(today.year);
    setMonth(today.month);
    setTodayKey(today.todayKey);
  };

  const handleAddTopic = async () => {
    const name = newTopicName.trim();
    if (!name) {
      return;
    }
    setBusyTopic(true);
    setTopicError(null);
    try {
      const response = await fetch("/api/topics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name }),
      });
      const data = await response.json();
      if (!response.ok) {
        setTopicError(data.error ?? "Could not add topic");
        return;
      }
      setNewTopicName("");
      await loadTopics();
      setSelectedTopicId(data.id);
      await loadStats(year, month);
    } finally {
      setBusyTopic(false);
    }
  };

  const handleRenameTopic = async (topicId: string, name: string) => {
    setTopicError(null);
    const response = await fetch(`/api/topics/${topicId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    const data = await response.json();
    if (!response.ok) {
      setTopicError(data.error ?? "Could not rename topic");
      throw new Error(data.error ?? "Could not rename topic");
    }
    await refresh();
  };

  return (
    <main className="page">
      <header className="page-header">
        <h1>Study Time Tracker</h1>
        <ThemeToggle />
      </header>

      <div className="layout">
        <div className="main-panel">
          <StudyTimer
            topics={topics}
            selectedTopicId={selectedTopicId}
            onSelectedTopicIdChange={setSelectedTopicId}
            onChange={() => void refresh()}
          />

          <StudyCalendar
            year={year}
            month={month}
            days={stats.days}
            todayKey={todayKey}
            trackingStartDate={stats.trackingStartDate}
            selectedTopicId={selectedTopicId}
            canGoPrev={canGoToPreviousMonth(year, month)}
            onPrev={goPrev}
            onToday={goToday}
            onNext={goNext}
          />
        </div>

        <TopicHours
          totalSeconds={stats.totalSeconds}
          todaySeconds={stats.todaySeconds}
          topics={stats.topics}
          newTopicName={newTopicName}
          busy={busyTopic}
          error={topicError}
          onNewTopicNameChange={(value) => {
            setTopicError(null);
            setNewTopicName(value);
          }}
          onAddTopic={() => void handleAddTopic()}
          onRenameTopic={handleRenameTopic}
        />
      </div>
    </main>
  );
}
