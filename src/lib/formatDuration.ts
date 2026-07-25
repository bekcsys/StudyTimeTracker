export function formatHours(totalSeconds: number): string {
  const seconds = Math.max(0, Math.floor(totalSeconds));
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (minutes > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${hours}h`;
}

export function formatMinutes(totalSeconds: number): string {
  const minutes = Math.max(0, Math.floor(totalSeconds / 60));
  return `${minutes}m`;
}

export function formatTimerParts(totalMicroseconds: number): {
  hours: string;
  minutes: string;
  seconds: string;
  micros: string;
} {
  const total = Math.max(0, Math.floor(totalMicroseconds));
  const hours = Math.floor(total / 3_600_000_000);
  const minutes = Math.floor((total % 3_600_000_000) / 60_000_000);
  const secs = Math.floor((total % 60_000_000) / 1_000_000);
  const micros = Math.floor((total % 1_000_000) / 10_000);

  return {
    hours: String(hours).padStart(2, "0"),
    minutes: String(minutes).padStart(2, "0"),
    seconds: String(secs).padStart(2, "0"),
    micros: String(micros).padStart(2, "0"),
  };
}
