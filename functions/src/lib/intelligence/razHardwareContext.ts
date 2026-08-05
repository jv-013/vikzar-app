import { AwarenessLevel, AwarenessSource, HardwareAwareness, RazAudience } from "./types";

/**
 * RazHardwareContext — RAZ's awareness levels. The core philosophy,
 * enforced structurally here rather than left to prose: **hardware
 * upgrades RAZ, it never activates it.** Level 0 (no hardware at all) is
 * a fully-served, permanent tier — every player and coach gets real
 * reasoning from profile, training history, wellness, calendar, and
 * memory alone. Connecting a Pod or an EMG band only ever adds sources
 * on top; nothing here is ever gated behind hardware.
 *
 * - **L0 — always on.** Training history, wellness, calendar, coach
 *   instructions, conversation/memory.
 * - **L1 — Pods connected.** Adds movement, impacts, load, asymmetry.
 *   `podConnected` genuinely reflects whether a device-pairing pipeline
 *   exists for this account — see `PlayerContext`'s own doc comment: no
 *   such pipeline is wired yet, so this is honestly `false` today, not
 *   a placeholder pretending otherwise.
 * - **L2 — EMG connected.** Adds muscle activation, fatigue,
 *   neuromuscular readiness. No EMG signal exists anywhere in this
 *   schema yet; `emgConnected` is always `false` until one does.
 * - **L3 — future.** GPS, weather, additional Vikzar wearables, external
 *   integrations. A documented extension point only — this level is
 *   never actually reached today, and nothing in this file pretends it
 *   can be.
 */

const L0_PLAYER_SOURCES: Omit<AwarenessSource, "active">[] = [
  { key: "player_data", label: "Player Data" },
  { key: "training_history", label: "Training History" },
  { key: "wellness", label: "Wellness" },
  { key: "calendar", label: "Calendar" },
];

const L0_COACH_SOURCES: Omit<AwarenessSource, "active">[] = [
  { key: "team_data", label: "Team Data" },
  { key: "training_history", label: "Training History" },
  { key: "calendar", label: "Calendar" },
];

interface DeriveAwarenessInput {
  audience: RazAudience;
  /** Real signal, not a placeholder — see this file's own doc comment. */
  podConnected: boolean;
  /** Always false until an EMG pipeline exists; kept as an explicit
   *  parameter (not hardcoded inline) so wiring a real signal in later
   *  is a one-line change at the call site, not a rewrite of this
   *  function. */
  emgConnected?: boolean;
}

export function deriveAwareness(input: DeriveAwarenessInput): HardwareAwareness {
  const l0 = input.audience === "player" ? L0_PLAYER_SOURCES : L0_COACH_SOURCES;
  const emgConnected = input.emgConnected ?? false;

  const sources: AwarenessSource[] = [
    ...l0.map((source) => ({ ...source, active: true })),
    { key: "pods", label: "Pods", active: input.podConnected },
    { key: "emg", label: "EMG", active: emgConnected },
    // L3 extension points — always inactive today, listed so the
    // Awareness UI has a stable, known set of future rows rather than
    // needing a redesign when one of these ships.
    { key: "gps", label: "GPS", active: false },
    { key: "weather", label: "Weather", active: false },
  ];

  let level: AwarenessLevel = 0;
  if (emgConnected) level = 2;
  else if (input.podConnected) level = 1;

  return { level, sources };
}
