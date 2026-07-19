# Vikzar Product Principles

These principles are mandatory. They apply to every product, design, and engineering decision made on Vikzar, from architecture through to individual UI copy.

Before designing or building a new feature, screen, or flow, it must be checked against this document. If a proposal conflicts with a principle here, the principle wins unless a decision to change the principle itself is explicitly recorded in [DECISIONS.md](DECISIONS.md).

This document should be referenced, not restated — future specs and ADR entries should link back here rather than re-deriving these rules.

---

## 1. Simplicity Over Feature Bloat

Vikzar should do a small number of things extremely well rather than accumulate features. Every addition to scope has an ongoing cost in complexity, maintenance, and cognitive load for players and coaches. New features must justify their existence, not merely be justified by being possible.

## 2. Player Safety Comes Before Engagement

Vikzar is a safety product first. Where a decision must choose between what is best for player welfare and what is best for engagement, retention, or growth metrics, player welfare wins. Vikzar does not gamify injury risk.

## 3. Live Team Monitoring Is an MVP Feature

The ability for a coach to observe their team's live sensor data during a session is not a future enhancement — it is core to the MVP. Architecture and planning must treat live monitoring as first-class from the outset, not retrofitted later.

## 4. Every Feature Must Provide Clear Value to Players, Coaches, or Clinicians

If a feature cannot be tied to a concrete benefit for one of Vikzar's actual users — players, coaches, or (in future) clinicians — it does not belong in the product. Value must be to the user, not merely to internal metrics or roadmap symmetry.

## 5. Keep Onboarding as Short and Frictionless as Possible

Every step added between install and first meaningful use is a point of drop-off. Onboarding flows should be scrutinized for anything that can be deferred, defaulted, or removed entirely.

## 6. Prefer Expanding Existing Screens Over Creating Unnecessary New Screens

Navigation complexity compounds. Before adding a new screen, consider whether the same value can be delivered by extending an existing one. This keeps the application legible, especially for coaches operating on larger displays where more can reasonably live on one screen.

## 7. Build for Long-Term Scalability Without Overengineering the MVP

The architecture must not paint the product into a corner, but the MVP must not be delayed or bloated by speculative infrastructure for problems that do not yet exist. Scalability is a constraint on architecture; it is not a license to build features early.

## 8. The Application Should Feel Premium, Calm, Modern, and Trustworthy

Vikzar handles data related to player health and physical risk. The application's tone, visual design, and interaction design must earn and reflect trust: calm rather than alarming, precise rather than gimmicky, modern without being trend-chasing.

## 9. Decisions Made During Development Should Be Documented

No significant decision is "just implemented." Product, UX, architecture, and engineering decisions of consequence are recorded in [DECISIONS.md](DECISIONS.md), with reasoning and alternatives considered, at the time they are made.

## 10. The Project Should Remain Maintainable for Years

Vikzar is being built as durable infrastructure for player safety, not a short-lived MVP to be rewritten. Code, architecture, and documentation decisions should be made with a multi-year maintenance horizon in mind.

---

## How to Use This Document

- Before proposing a new feature, check it against Principles 1, 4, 5, and 6.
- Before making a tradeoff between safety and any growth or engagement mechanic, Principle 2 is decisive.
- Before adding infrastructure or abstraction, check it against Principle 7.
- When a decision is made that touches any of these principles, record it in [DECISIONS.md](DECISIONS.md) and reference the relevant principle number(s).
