"use client"

import { Check, Circle, Loader2, X } from "lucide-react"
import { hintText, PROGRAMMING_STEPS, TAG_TYPE_LABEL, type ProgrammingError, type ProgrammingStep } from "@/lib/nfc-programming"
import type { ProgrammerState } from "@/hooks/use-nfc-programmer"
import { cn } from "@/lib/utils"

const STAGE_TO_STEP: Record<ProgrammingError["stage"], ProgrammingStep> = {
  read: "waiting",
  check: "checking",
  detect: "detecting",
  write: "writing",
  verify: "verifying",
  bind: "saving",
  lock: "locking",
}

type Status = "done" | "active" | "failed" | "pending"

/**
 * The eight steps of programming one tag, with the step in progress, the one that failed and
 * what the operator has to do right now.
 */
export function NfcProgramSteps({
  state,
  lock,
  error,
  finished,
  className,
}: {
  state: ProgrammerState
  lock: boolean
  error?: ProgrammingError | null
  finished?: boolean
  className?: string
}) {
  const steps = PROGRAMMING_STEPS.filter((s) => lock || s.step !== "locking")
  const failedStep = error ? STAGE_TO_STEP[error.stage] : null
  const currentIndex = steps.findIndex((s) => s.step === (failedStep ?? state.step))

  const status = (index: number): Status => {
    if (finished) return "done"
    if (failedStep) return index < currentIndex ? "done" : index === currentIndex ? "failed" : "pending"
    if (!state.running) return "pending"
    return index < currentIndex ? "done" : index === currentIndex ? "active" : "pending"
  }

  return (
    <div className={cn("space-y-3", className)}>
      <ol className="grid gap-1.5" aria-label="Programming steps">
        {steps.map((s, i) => {
          const st = status(i)
          return (
            <li key={s.step} className="flex items-center gap-2.5 text-sm" aria-current={st === "active" ? "step" : undefined} data-status={st}>
              <span
                className={cn(
                  "flex size-5 shrink-0 items-center justify-center rounded-full border",
                  st === "done" && "border-emerald-600 bg-emerald-600 text-white",
                  st === "active" && "border-primary text-primary",
                  st === "failed" && "border-destructive bg-destructive text-white",
                  st === "pending" && "text-muted-foreground",
                )}
              >
                {st === "done" ? (
                  <Check className="size-3" />
                ) : st === "active" ? (
                  <Loader2 className="size-3 animate-spin" />
                ) : st === "failed" ? (
                  <X className="size-3" />
                ) : (
                  <Circle className="size-2" />
                )}
              </span>
              <span className={cn(st === "pending" && "text-muted-foreground", st === "active" && "font-medium")}>
                {s.label}
                {s.step === "detecting" && state.tagType && (st === "done" || finished) ? (
                  <span className="text-muted-foreground"> · {TAG_TYPE_LABEL[state.tagType]}</span>
                ) : null}
                {s.step === "waiting" && state.uid && st !== "pending" ? <span className="text-muted-foreground font-mono text-xs"> · {state.uid}</span> : null}
              </span>
            </li>
          )
        })}
      </ol>
      {state.running && state.step ? (
        <p className="bg-primary/5 rounded-lg px-3 py-2 text-sm font-medium" role="status" aria-live="polite">
          {hintText(state.hint, state.step)}
        </p>
      ) : null}
    </div>
  )
}
