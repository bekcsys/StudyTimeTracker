"use client";

import { useState } from "react";
import { formatHours, formatMinutes } from "@/lib/formatDuration";
import type { TopicStat, WeekDay } from "@/lib/stats";
import WeekChart from "@/components/WeekChart";

type TopicHoursProps = {
  totalSeconds: number;
  todaySeconds: number;
  topics: TopicStat[];
  week?: WeekDay[];
  readOnly?: boolean;
  newTopicName?: string;
  busy?: boolean;
  error?: string | null;
  onNewTopicNameChange?: (value: string) => void;
  onAddTopic?: () => void;
  onRenameTopic?: (topicId: string, name: string) => Promise<void>;
};

export default function TopicHours({
  totalSeconds,
  todaySeconds,
  topics,
  week = [],
  readOnly = false,
  newTopicName = "",
  busy = false,
  error = null,
  onNewTopicNameChange,
  onAddTopic,
  onRenameTopic,
}: TopicHoursProps) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draftName, setDraftName] = useState("");
  const [saving, setSaving] = useState(false);

  const startEdit = (topic: TopicStat) => {
    setEditingId(topic.id);
    setDraftName(topic.name);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setDraftName("");
  };

  const saveEdit = async () => {
    if (!editingId || !draftName.trim() || !onRenameTopic) {
      return;
    }
    setSaving(true);
    try {
      await onRenameTopic(editingId, draftName.trim());
      cancelEdit();
    } catch {
      // Parent surfaces the error message.
    } finally {
      setSaving(false);
    }
  };

  return (
    <aside className="side-panel">
      <section className="totals">
        <div>
          <div className="label">Total</div>
          <div className="value">{formatHours(totalSeconds)}</div>
        </div>
        <div>
          <div className="label">Today</div>
          <div className="value">{formatMinutes(todaySeconds)}</div>
        </div>
      </section>

      <section className="topics">
        <h2>Break down</h2>
        {topics.length === 0 ? (
          <p className="topics-empty">No study time logged yet.</p>
        ) : (
          <ul className="topic-list">
            {topics.map((topic) => (
              <li key={topic.id} className="topic-row">
                {!readOnly && editingId === topic.id ? (
                  <div className="topic-edit">
                    <span className="topic-times">
                      {formatMinutes(topic.totalSeconds)}
                    </span>
                    <span
                      className="topic-dot"
                      style={{ backgroundColor: topic.color }}
                      aria-hidden
                    />
                    <input
                      className="topic-input"
                      type="text"
                      value={draftName}
                      disabled={saving || busy}
                      autoFocus
                      onChange={(event) => setDraftName(event.target.value)}
                      onKeyDown={(event) => {
                        if (event.key === "Enter") {
                          event.preventDefault();
                          void saveEdit();
                        }
                        if (event.key === "Escape") {
                          event.preventDefault();
                          cancelEdit();
                        }
                      }}
                    />
                    <button
                      type="button"
                      className="btn btn-small"
                      disabled={saving || busy || !draftName.trim()}
                      onClick={() => void saveEdit()}
                    >
                      Save
                    </button>
                    <button
                      type="button"
                      className="btn btn-small"
                      disabled={saving || busy}
                      onClick={cancelEdit}
                    >
                      Cancel
                    </button>
                  </div>
                ) : (
                  <>
                    <span className="topic-times">
                      {formatMinutes(topic.totalSeconds)}
                    </span>
                    <span
                      className="topic-dot"
                      style={{ backgroundColor: topic.color }}
                      aria-hidden
                    />
                    <span className="topic-title">{topic.name}</span>
                    {!readOnly && (
                      <button
                        type="button"
                        className="topic-edit-btn"
                        disabled={busy || saving}
                        onClick={() => startEdit(topic)}
                        aria-label={`Edit ${topic.name}`}
                        title="Edit"
                      >
                        ✎
                      </button>
                    )}
                  </>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      {!readOnly && (
        <section className="topic-add-panel">
          <label className="label" htmlFor="new-topic">
            Add topic
          </label>
          <div className="topic-add">
            <input
              id="new-topic"
              className="topic-input"
              type="text"
              placeholder="Security+, AWS-SAP, CISSP"
              value={newTopicName}
              disabled={busy}
              onChange={(event) => onNewTopicNameChange?.(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  onAddTopic?.();
                }
              }}
            />
            <button
              type="button"
              className="btn btn-small"
              disabled={busy || !newTopicName.trim()}
              onClick={onAddTopic}
            >
              Add
            </button>
          </div>
          {error && <p className="error">{error}</p>}
        </section>
      )}

      {week.length === 7 && <WeekChart week={week} />}
    </aside>
  );
}
