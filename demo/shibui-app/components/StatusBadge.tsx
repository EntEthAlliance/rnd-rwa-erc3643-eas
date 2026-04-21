import type { ReactNode } from "react";

type Tone = "ok" | "warn" | "err" | "neutral" | "info";

const TONE_CLASS: Record<Tone, string> = {
  ok: "bg-emerald-50 text-emerald-800 border-emerald-200",
  warn: "bg-amber-50 text-amber-800 border-amber-200",
  err: "bg-red-50 text-red-800 border-red-200",
  neutral: "bg-slate-50 text-slate-700 border-slate-200",
  info: "bg-blue-50 text-blue-800 border-blue-200",
};

export function StatusBadge({
  tone = "neutral",
  children,
}: {
  tone?: Tone;
  children: ReactNode;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium ${TONE_CLASS[tone]}`}
    >
      {children}
    </span>
  );
}
