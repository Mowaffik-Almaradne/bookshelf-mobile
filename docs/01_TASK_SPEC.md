# 01 — Task Specification (clean English version with requirement IDs)

> Source: `docs/مهمة-عملية-iOS.md` (PDF → Markdown conversion; word order is garbled per line).
> This file is the **authoritative, readable** version of the task. Every requirement has an ID
> (`R-*` core, `Q-*` quality, `O-*` optional, `D-*` delivery, `X-*` rules) so that code, tests,
> commits and the final README can reference them.

## Summary

Build **"The Shelf" (الرف)** — a small native iOS app for a neighbourhood library. Patrons can
**search** any book (Open Library), see **details**, and **save** books they intend to read to a
personal **Shelf** that works **fully offline**.

| Item | Value |
|---|---|
| Effort cap | **16 hours** of work, max |
| Deadline | 2 days from receiving the task |
| Platform | iOS 17+, Xcode, Swift (SwiftUI or UIKit) |
| AI usage | Allowed and encouraged — but you must understand and be able to explain/modify every line |
| Libraries | **Apple frameworks only** (URLSession, Codable, SwiftData/Core Data/FileManager, XCTest/Swift Testing) |

The reviewers explicitly say: *a small, clean, understandable app with every state covered beats a
large half-working one.* The app is intentionally small.

## Data source — Open Library (free, no API key)

| Purpose | Request |
|---|---|
| Search | `GET https://openlibrary.org/search.json?q={text}&page={n}&limit=20` (`fields=` allowed to shrink payload) |
| Work details | `GET https://openlibrary.org{key}.json` where `key` comes from a search result, e.g. `/works/OL45804W` |
| Cover image | `https://covers.openlibrary.org/b/id/{cover_i}-{S|M|L}.jpg` |

The API is **real**: sometimes slow, fields may be missing, and some fields arrive in **more than one
shape**. Handling that is part of the task. See `03_OPEN_LIBRARY_API_AND_DECODING.md`.

---

## Core requirements

### R1 — Search
| ID | Requirement |
|---|---|
| R1.1 | A search field. The request fires when the user **stops typing** (debounce), not per keystroke. |
| R1.2 | Search only from **3 characters** and up. |
| R1.3 | If the user types a new query before the old one returns, the **old result must never appear** (stale-result protection). |
| R1.4 | Each result shows: **cover** (or a placeholder when none), **title**, **author**, **first publish year**. |
| R1.5 | All states are clear to the user: **before search**, **loading**, **results**, **no results**, **error with a "Retry" button**. |

### R2 — Incremental loading (pagination)
| ID | Requirement |
|---|---|
| R2.1 | When the user reaches the end of the list, the **next page loads automatically**. |
| R2.2 | **No duplicate results.** |
| R2.3 | **No two requests for the same page** even when scrolling fast (in-flight guard). |
| R2.4 | The app **knows when results are exhausted** (stops requesting). |

### R3 — Details screen
| ID | Requirement |
|---|---|
| R3.1 | Larger cover, title, authors, description, subjects (when present). |
| R3.2 | A button to **save the book to the Shelf or remove it** from the Shelf. |

### R4 — The Shelf (reading list)
| ID | Requirement |
|---|---|
| R4.1 | A **separate tab** listing saved books; the user can **delete** from it. |
| R4.2 | **Persistent**: fully quit and relaunch → the Shelf is still there. |
| R4.3 | The Shelf **and the details of saved books** work **fully offline** (airplane mode). |
| R4.4 | Save state is **synchronised between screens**: save from details → return to search → the row shows it is saved. |

### R5 — Images
| ID | Requirement |
|---|---|
| R5.1 | Images load **without blocking the UI**, with a **placeholder** until they arrive. |
| R5.2 | During fast scrolling, **one book's image must never appear on another book** (cell reuse / async race). |

---

## Quality requirements (also core — graded)

| ID | Requirement |
|---|---|
| Q1 | **Separation of concerns**: the UI never talks to the network directly. MVVM or any pattern, **explain why in README**. |
| Q2 | **Testability**: the network layer sits **behind a protocol** so it can be tested offline. |
| Q3 | **Unit tests for at least three things**: (a) search screen states, (b) pagination logic incl. no-duplication, (c) decoding the details response in its different shapes. |
| Q4 | **No crash**: **no force unwrap** on data coming from the network. |
| Q5 | **UI never freezes**: heavy work off the main thread; UI updates on the main thread. |
| Q6 | **Accessibility**: important buttons have meaningful **VoiceOver** labels; works with **Dynamic Type** (large text) and **Dark Mode**. |

---

## Optional additions (only after core is complete; one done well > four half-done; no penalty for none)

| ID | Feature |
|---|---|
| O1 | Reading status per shelf book (**want to read / reading / finished**) with filtering. |
| O2 | Show **last search results when offline**, clearly marked as stale. |
| O3 | **Arabic + RTL** support. Covers of **saved books visible offline**. |
| O4 | An iPad-appropriate layout. |

Our plan: implement **O3 (offline covers for saved books)** as part of the core offline story, then
**O1** as the one polished extra. O2/O4 only if time remains. See `13_IMPLEMENTATION_PLAN.md`.

---

## Rules

| ID | Rule |
|---|---|
| X1 | **Native only**: Swift + SwiftUI/UIKit (mix allowed if explained). No Flutter/RN/KMP. |
| X2 | **No third-party libraries in app code.** Build/dev tools are allowed. |
| X3 | **AI allowed/encouraged.** Only condition: you understand every line and can explain and modify it. |
| X4 | **16h cap.** If something is unfinished, stop and write in README what is missing and how you would finish it. |
| X5 | **Assumptions**: ask, or choose a sensible assumption and **document it in README**. |
| X6 | Project must **build in Xcode without modification**; deliver a **video** of the app running. |

---

## Delivery

| ID | Deliverable |
|---|---|
| D1 | Repository on GitHub/GitLab (private, with reviewer access) or ZIP including `.git`. |
| D2 | **Natural commit history**: one commit per logical step with clear messages. **Not** one big commit. |
| D3 | `README.md`: how to run; architecture briefly + why; key decisions and rejected alternatives; the **two hardest parts** and how you solved them in your own words; assumptions; approximate hours per part; what is missing and what you would improve with one more day. |
| D4 | `AI_NOTES.md`: tools used and for which parts; **three example prompts** with what came out and what you changed; **at least one time the AI was wrong** or suggested something you rejected, and how you noticed; what you learned that is new in Swift/iOS. |
| D5 | **Short video (2–3 min)** from Simulator or device: search, scrolling/pagination, saving, and **airplane mode**. |

## Evaluation criteria (what graders look at)

1. App works and is **stable**.
2. Understanding of **iOS and Swift concepts**.
3. **Architecture and code quality**.
4. Handling of hard cases: **slow network, errors, offline, pagination**.
5. **Tests**.
6. **UI and accessibility**.
7. **Quality of AI usage**; speed of learning; clarity of communication.

Not evaluated: number of optional extras, visual fanciness. Evaluation is based on what is
delivered — README and AI_NOTES must be clear.

---

## Acceptance checklist (copy into the final README as "Requirement coverage")

- [ ] R1.1 debounce · R1.2 min 3 chars · R1.3 stale results dropped · R1.4 row content · R1.5 all five states
- [ ] R2.1 auto next page · R2.2 no duplicates · R2.3 no double in-flight · R2.4 end detection
- [ ] R3.1 details content · R3.2 save/remove toggle
- [ ] R4.1 shelf tab + delete · R4.2 persistence · R4.3 offline shelf & details · R4.4 cross-screen sync
- [ ] R5.1 async images + placeholder · R5.2 no wrong image on reuse
- [ ] Q1 layering · Q2 protocol network · Q3 ≥3 unit test areas · Q4 no force unwrap · Q5 off-main work · Q6 a11y/Dynamic Type/Dark Mode
- [ ] D2 commit history · D3 README · D4 AI_NOTES · D5 video
