# 14 — Prompt workflow (overview)

The prompts themselves live in **[`docs/prompts/`](prompts/README.md)** — one file per
implementation step, each fully self-contained so you can paste it without assembling anything.
This page is only the map; `prompts/README.md` is the operating manual.

## The loop

```
new chat  ─▶  attach the docs the prompt lists  ─▶  paste prompts/NN_*.md
          ─▶  agent implements + runs build/tests/grep
          ─▶  paste prompts/90_REVIEW.md in the SAME chat
          ─▶  fix (prompts/91_FIX.md if anything fails)
          ─▶  you read the diff and commit
          ─▶  2 minutes writing to docs/AI_LOG.md
```

Repeat for each step, then finish with the hardening pass, independent grading, the delivery
documents and the video.

## Step map

| Prompt | Builds | Requirements it carries |
|---|---|---|
| [01 Architecture review](prompts/01_ARCHITECTURE_REVIEW.md) | nothing (findings only) | catches design flaws while they are free |
| [02 Setup](prompts/02_SETUP.md) | gitignore, skeleton, theme, string catalog | X6 (builds unmodified) |
| [03 Core networking](prompts/03_CORE_NETWORKING.md) | `HTTPClient`, `Endpoint`, `AppError` | Q2, Q4 |
| [04 Domain & data](prompts/04_DOMAIN_AND_DATA.md) | models, DTOs, catalog, fixtures | Q3-c, Q4 |
| [05 Pagination](prompts/05_PAGINATION.md) | generic `Paginator` | R2.2–R2.4, Q3-b |
| [06 Design system](prompts/06_DESIGN_SYSTEM.md) | app-agnostic component kit | Q6, reuse |
| [07 Search](prompts/07_SEARCH.md) | `SearchViewModel` + screen | R1.1–R1.5, R2.1, Q3-a |
| [08 Images](prompts/08_IMAGES.md) | `ImageLoader` actor, `RemoteImage` | R5.1, R5.2, Q5 |
| [09 Persistence & shelf](prompts/09_PERSISTENCE_SHELF.md) | SwiftData, `ShelfStore`, tabs | R4.1–R4.4 |
| [10 Details & connectivity](prompts/10_DETAILS_CONNECTIVITY.md) | offline-first details | R3.1, R3.2, R4.3 |
| [11 Accessibility & Arabic](prompts/11_ACCESSIBILITY_L10N.md) | audit + fixes | Q6, O3, O4 |
| [12 Reading status](prompts/12_READING_STATUS.md) | optional feature | O1 |
| [13 Hardening](prompts/13_HARDENING.md) | hostile review + manual QA | evaluator criterion 4 |
| [14 Deliverables](prompts/14_DELIVERABLES.md) | README, AI_NOTES | D3, D4 |

Support prompts: [90 review](prompts/90_REVIEW.md) after every step,
[91 fix](prompts/91_FIX.md) when something breaks,
[92 grade](prompts/92_GRADE.md) at the end in two different models.

## Why the prompts are shaped this way

- **One chat per step.** Long chats drift; the agent starts editing files from three phases ago.
- **Explicit file lists.** Naming every file up front is what prevents invented abstractions and
  keeps each phase inside its hour estimate.
- **The same two rule blocks in every prompt** (`prompts/00_SHARED_RULES.md`). Consistency across
  chats is what makes the codebase look like one engineer wrote it, not twelve.
- **The design system comes before the screens.** Components extracted after the fact are shaped
  by the first screen that needed them; components built first stay reusable.
- **Every prompt ends with verification commands.** The agent must paste real build, test and
  grep output — not a claim that it "should work".
- **A review prompt after every step.** Most deductions in this task are for discipline
  (labels, localization, layering, test quality), and those are cheapest to fix immediately.
- **Grading by a different model.** A model reviewing its own output is a weak reviewer.

## The one rule that matters most

The task's only condition on AI use is that you **understand every line and can explain and
modify it**. If a file makes you hesitate, run the third block in
[91_FIX.md](prompts/91_FIX.md) ("explain this as if I have to defend it tomorrow") and simplify
until you can. Shipping code you cannot defend fails the interview even if it works.
