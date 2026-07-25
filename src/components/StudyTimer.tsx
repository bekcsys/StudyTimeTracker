"use client";

import { useCallback, useEffect, useState } from "react";
import { formatTimerParts } from "@/lib/formatDuration";

type TimerStatus = "idle" | "active" | "paused";

export type Topic = {
  id: string;
  name: string;
  color?: string;
};

type TimerState = {
  status: TimerStatus;
  sessionId: string | null;
  elapsedSeconds: number;
  startedAt: string | null;
  topicId: string | null;
  topicName: string | null;
};

type StudyTimerProps = {
  topics: Topic[];
  selectedTopicId: string;
  onSelectedTopicIdChange: (topicId: string) => void;
  onChange?: () => void;
};

async function readTimer(): Promise<TimerState> {
  const response = await fetch("/api/timer", { cache: "no-store" });
  if (!response.ok) {
    throw new Error("Failed to load timer");
  }
  return response.json();
}

async function postTimer(
  path: string,
  body?: Record<string, string>,
): Promise<TimerState> {
  const response = await fetch(path, {
    method: "POST",
    headers: body ? { "Content-Type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error ?? "Timer action failed");
  }
  return data;
}

export default function StudyTimer({
  topics,
  selectedTopicId,
  onSelectedTopicIdChange,
  onChange,
}: StudyTimerProps) {
  const [status, setStatus] = useState<TimerStatus>("idle");
  const [baseElapsedSeconds, setBaseElapsedSeconds] = useState(0);
  const [syncedAtMs, setSyncedAtMs] = useState<number | null>(null);
  const [displayMicros, setDisplayMicros] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const applyState = useCallback(
    (state: TimerState) => {
      setStatus(state.status);
      setBaseElapsedSeconds(state.elapsedSeconds);
      setSyncedAtMs(Date.now());
      if (state.topicId) {
        onSelectedTopicIdChange(state.topicId);
      }
      setDisplayMicros((prev) => {
        if (state.status === "idle" && state.elapsedSeconds === 0) {
          return 0;
        }
        if (state.status === "active") {
          return state.elapsedSeconds * 1_000_000;
        }
        const whole = state.elapsedSeconds * 1_000_000;
        return whole + (prev % 1_000_000);
      });
      setError(null);
    },
    [onSelectedTopicIdChange],
  );

  const sync = useCallback(async () => {
    try {
      const state = await readTimer();
      applyState(state);
    } catch {
      setError("Could not load timer");
    }
  }, [applyState]);

  useEffect(() => {
    void sync();
  }, [sync]);

  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === "visible") {
        void sync();
      }
    };

    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("focus", onVisible);
    return () => {
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("focus", onVisible);
    };
  }, [sync]);

  useEffect(() => {
    if (status !== "active" || syncedAtMs === null) {
      return;
    }

    let frame = 0;

    const tick = () => {
      const extraMicros = Math.max(0, (Date.now() - syncedAtMs) * 1000);
      setDisplayMicros(baseElapsedSeconds * 1_000_000 + extraMicros);
      frame = window.requestAnimationFrame(tick);
    };

    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, [status, baseElapsedSeconds, syncedAtMs]);

  const runAction = async (
    path: string,
    body?: Record<string, string>,
  ) => {
    setBusy(true);
    setError(null);
    try {
      const state = await postTimer(path, body);
      applyState(state);
      onChange?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Action failed");
      await sync();
    } finally {
      setBusy(false);
    }
  };

  const { hours, minutes, seconds, micros } = formatTimerParts(displayMicros);
  const canStart = status === "idle" && Boolean(selectedTopicId);
  const selectedTopic = topics.find((topic) => topic.id === selectedTopicId);

  return (
    <section className="timer">
      <div className="timer-display" aria-live="polite">
        <span className="timer-hm">
          {hours}
          <span className="timer-sep">:</span>
          {minutes}
        </span>
        <span className="timer-sec">
          <span className="timer-sep">:</span>
          {seconds}
        </span>
        <span className="timer-micros">.{micros}</span>
      </div>

      <div className="timer-actions">
        <div
          className={`topic-select-wrap${status !== "idle" ? " topic-select-wrap-running" : ""}`}
        >
          {selectedTopic?.color && (
            <span
              className="topic-dot topic-select-dot"
              style={{ backgroundColor: selectedTopic.color }}
              aria-hidden
            />
          )}
          <select
            id="topic-select"
            className={`topic-select topic-select-inline${status !== "idle" ? " topic-select-running" : ""}`}
            aria-label="Topic"
            value={selectedTopicId}
            disabled={busy || topics.length === 0 || status !== "idle"}
            onChange={(event) => onSelectedTopicIdChange(event.target.value)}
          >
            {topics.length === 0 ? (
              <option value="">No topics yet</option>
            ) : (
              topics.map((topic) => (
                <option key={topic.id} value={topic.id}>
                  {topic.name}
                </option>
              ))
            )}
          </select>
        </div>

        {status === "idle" && (
          <button
            type="button"
            className="btn btn-timer-main"
            disabled={busy || !canStart}
            onClick={() =>
              void runAction("/api/timer/start", { topicId: selectedTopicId })
            }
          >
            Start
          </button>
        )}

        {status === "active" && (
          <button
            type="button"
            className="btn btn-timer-main"
            disabled={busy}
            onClick={() => void runAction("/api/timer/pause")}
          >
            Pause
          </button>
        )}

        {status === "paused" && (
          <button
            type="button"
            className="btn btn-timer-main"
            disabled={busy}
            onClick={() => void runAction("/api/timer/resume")}
          >
            Resume
          </button>
        )}

        <button
          type="button"
          className="btn"
          disabled={busy || status === "idle"}
          onClick={() => void runAction("/api/timer/stop")}
        >
          Stop
        </button>
      </div>

      {error && <p className="error">{error}</p>}
    </section>
  );
}
