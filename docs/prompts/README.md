# Prompt pack — one prompt per implementation step

Each file here is a **complete, copy-paste prompt**. Open a **new chat per prompt**, attach the
files listed under *Attach*, paste the whole prompt, let the agent work, then paste
`90_REVIEW.md` in the same chat before committing.

## Order

| # | Prompt | Phase in `13_IMPLEMENTATION_PLAN.md` | Est. | Output |
|---|---|---|---|---|
| 01 | [Architecture review](01_ARCHITECTURE_REVIEW.md) | before code | 0.5 h | doc fixes only, no code |
| 02 | [Project setup](02_SETUP.md) | 0 | 0.75 h | gitignore, skeleton, string catalog |
| 03 | [Core networking](03_CORE_NETWORKING.md) | 1 | 1.5 h | `HTTPClient`, `Endpoint`, `AppError`, `Log` |
| 04 | [Domain & Open Library data](04_DOMAIN_AND_DATA.md) | 2 | 2.0 h | models, DTOs, catalog, fixtures |
| 05 | [Pagination engine](05_PAGINATION.md) | 3 | 0.75 h | generic `Paginator` |
| 06 | [Design system / components](06_DESIGN_SYSTEM.md) | 4a | 0.75 h | reusable UI kit, zero business logic |
| 07 | [Search feature](07_SEARCH.md) | 4b | 1.75 h | `SearchViewModel` + screen |
| 08 | [Image pipeline](08_IMAGES.md) | 5 | 1.5 h | `ImageLoader` actor, `RemoteImage` |
| 09 | [Persistence & Shelf](09_PERSISTENCE_SHELF.md) | 6 | 2.0 h | SwiftData, `ShelfStore`, tabs |
| 10 | [Details & connectivity](10_DETAILS_CONNECTIVITY.md) | 7 | 1.5 h | offline-first details |
| 11 | [Accessibility & Arabic](11_ACCESSIBILITY_L10N.md) | 8 | 1.0 h | VoiceOver, Dynamic Type, RTL |
| 12 | [Reading status (optional)](12_READING_STATUS.md) | 9 | 0.75 h | O1 feature |
| 13 | [Hardening](13_HARDENING.md) | 10 | 0.75 h | hostile self-review + fixes |
| 14 | [Deliverables](14_DELIVERABLES.md) | 11 | 1.0 h | README, AI_NOTES |

Support prompts, used repeatedly:

| Prompt | When |
|---|---|
| [90_REVIEW.md](90_REVIEW.md) | after **every** implementation prompt, same chat |
| [91_FIX.md](91_FIX.md) | whenever build or tests fail |
| [92_GRADE.md](92_GRADE.md) | at the end, in two different models, until score is stable |

Total ≈ 16 h, matching the cap. Prompts 06 and 07 are a split of Phase 4 (UI kit first, then the
screen), which is what makes the components genuinely reusable instead of extracted afterwards.

## Rules of engagement

1. **One chat per prompt.** Long chats drift and the agent starts inventing files.
2. **Always attach the listed docs.** The prompts reference them instead of repeating specs, so an
   unattached doc means guessed behaviour.
3. **Never let a prompt run twice on the same code.** If output is wrong, use `91_FIX.md`.
4. **Commit after each prompt** with the suggested message. The commit history is graded (D2).
5. **Log to AI notes as you go**: after each prompt add 2–3 bullets to `docs/AI_LOG.md` (what you
   asked, what came out, what you changed, anything the AI got wrong). `14_DELIVERABLES.md`
   turns that log into `AI_NOTES.md` — you cannot reconstruct it later.
6. **You own every line.** If you cannot explain a file, delete it and ask the agent to rewrite it
   simpler. The task grades *your* understanding, not the agent's output.

## The two blocks every prompt ends with

Both live in [`00_SHARED_RULES.md`](00_SHARED_RULES.md) and are already inlined at the bottom of
each prompt file, so you can paste a prompt without assembling anything.

- **Non-negotiables** — language mode, forbidden constructs, layering, testing, scope control.
- **Component & scalability rules** — the "separated components" contract: size limits, single
  responsibility, injection, previews, no business logic in views.
