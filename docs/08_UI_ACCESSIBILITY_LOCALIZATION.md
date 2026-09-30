# 08 — UI, accessibility, Dynamic Type, Dark Mode, RTL & iPad

Requirement links: R1.4, R1.5, R3.1, R4.1, Q6, O3 (RTL), O4 (iPad).
Design principle: **system components, semantic colours, system fonts.** Fanciness is not graded;
correctness under large text, VoiceOver and Dark Mode is.

## Screen map

```
RootView (TabView)
├── Tab "Search"  → NavigationStack → SearchView ──push──▶ BookDetailsView
└── Tab "Shelf"   → NavigationStack → ShelfView  ──push──▶ BookDetailsView
```

Both tabs push the **same** `BookDetailsView`; the ViewModel decides local-vs-remote (06).
Tab items: `Label("Search", systemImage: "magnifyingglass")`, `Label("Shelf", systemImage: "books.vertical")`.
Shelf tab shows a **badge** with the saved count (`.badge(store.books.count)`) — cheap, useful, a11y-announced.

## Components (UI/Components — reusable, stateless, previewable)

| Component | Purpose | Notes |
|---|---|---|
| `CoverView` | Cover with placeholder, fixed aspect 2:3 | Wraps `RemoteImage`; `@ScaledMetric` size; `.accessibilityHidden(true)` |
| `CoverPlaceholder` | Fallback art | Semantic colours, first letter of title |
| `BookRow` | Search/Shelf row | Adaptive layout (see Dynamic Type) |
| `ErrorStateView` | Full-screen error + Retry | Uses `ContentUnavailableView` + `Button("Retry")` |
| `LoadingFooter` | Pagination footer | `.idle/.loading/.failed/.end` |
| `OfflineBanner` | "You're offline" strip | `.accessibilityAddTraits(.updatesFrequently)` not needed; keep simple |
| `SaveToggleButton` | Save/Remove | Single component used in Details; label/hint change with state |
| `ReadingStatusBadge` | O1 | Text + icon, never colour only |

Every component has a `#Preview` group covering: light/dark, `.dynamicTypeSize(.accessibility3)`,
RTL (`.environment(\.layoutDirection, .rightToLeft)`). Previews use `AppDependencies.preview()`.

## Dynamic Type (Q6)

- **Only** system text styles (`.headline`, `.subheadline`, `.caption`) — never fixed point sizes.
- Layout metrics that should scale use `@ScaledMetric(relativeTo: .body) var coverWidth = 60`.
- Rows switch axis at accessibility sizes:

```swift
@Environment(\.dynamicTypeSize) private var typeSize
var body: some View {
    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading))
                                              : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    layout { CoverView(...); textStack }
}
```
- `Text` lines: title `.lineLimit(2)`, authors `.lineLimit(1)` at normal sizes, **no `lineLimit`**
  at accessibility sizes (truncation of the title is a real a11y failure).
- Buttons use `.buttonStyle(.borderedProminent)` + `.controlSize(.large)` → 44 pt targets grow
  with text.
- `minimumScaleFactor` is **not** used (it hides content from large-text users).

## Dark Mode (Q6)

- Only semantic colours: `.primary`, `.secondary`, `Color(.systemBackground)`,
  `Color(.secondarySystemGroupedBackground)`, `.tint`.
- The placeholder uses `Color(.tertiarySystemFill)` + `.secondary` glyph.
- Never `Color.white`/`Color.black`; never hardcoded hex. Assets: only `AccentColor`.
- Verify with `#Preview { … .preferredColorScheme(.dark) }` and in the video (toggle appearance
  in Simulator ⇧⌘A).

## VoiceOver (Q6)

| Element | Label / Hint / Traits |
|---|---|
| `BookRow` | `.accessibilityElement(children: .combine)`; label = "Title, by Authors, First published 1997, Saved to shelf" (built via `accessibilityLabel(Text)` from parts; year omitted when nil). Trait `.isButton` comes from `NavigationLink`. |
| Save button | Label "Save to shelf" / "Remove from shelf"; hint "Adds this book to your reading list" / "Removes …" ; `.accessibilityValue` not needed |
| Retry button | Label "Retry search" / "Retry loading details"; hint "Tries the request again" |
| Delete (swipe) | `Button(role: .destructive)` with `Label("Remove", systemImage: "trash")` — system provides trait |
| Offline banner | `.accessibilityLabel("You are offline. Saved books are still available.")` |
| Loading | `ProgressView` with `.accessibilityLabel("Searching")`; announce results with `AccessibilityNotification.Announcement("\(n) results").post()` on first page load |
| Covers | `.accessibilityHidden(true)` — decorative; the title is in the row |
| Reading status picker | Segmented `Picker` — system a11y; each option a `Text` |
| Pagination footer | `.accessibilityLabel("Loading more results")` / `"End of results"` |

Rule: **no icon-only button without `accessibilityLabel`**. `Label(_, systemImage:)` +
`.labelStyle(.iconOnly)` keeps the text label for VoiceOver — prefer that pattern.

Also: `.accessibilityIdentifier` on Search field, Retry, Save, Shelf tab — cheap and enables an
optional UI smoke test.

## Reduce Motion

Cover fade-in uses `.animation(reduceMotion ? nil : .easeIn(duration: 0.2))` with
`@Environment(\.accessibilityReduceMotion)`. Skeleton shimmer, if any, disabled under reduce motion.

## Localization & RTL (O3)

- All user-facing strings go through **`Localizable.xcstrings`** (String Catalog) with `en` (source)
  and `ar`. SwiftUI `Text("Search")` auto-extracts; for interpolations use
  `String(localized: "No results for \(query)", comment: …)`.
- **Never** use `.leading/.trailing` mixups: use `leading`/`trailing`, never `left`/`right`; use
  `HStack` order semantics; SF Symbols that imply direction (`chevron.forward`) not `.right`.
- Numbers: `Text(year, format: .number.grouping(.never))` so 1997 does not become "١٬٩٩٧" in
  Arabic locale (or accept Arabic-Indic digits — decide and document; recommended: keep locale
  digits, but **no grouping** for years).
- Test RTL via Scheme ▸ Options ▸ App Language: Arabic, or the preview environment.
- `Localizable.xcstrings` Arabic strings: keep them short and natural — a reviewer may be a native
  speaker. Examples: Search = "بحث", Shelf = "الرف", Save to shelf = "حفظ في الرف",
  Remove from shelf = "إزالة من الرف", Retry = "إعادة المحاولة", You're offline = "لا يوجد اتصال بالإنترنت",
  No results for "%@" = "لا توجد نتائج لـ \"%@\"", Want to read = "أنوي قراءته", Reading = "أقرأه الآن",
  Finished = "انتهيت منه", End of results = "نهاية النتائج".

## iPad (O4 — cheap wins only)

- `TabView` + `NavigationStack` already adapt (iPadOS 18+ renders tabs as a top bar/sidebar).
- Details: constrain content width with `.frame(maxWidth: 700)` centred and use a two-column
  `ViewThatFits` (cover left, text right) in regular width — avoids 12-inch-wide paragraphs.
- Search list rows are fine full-width; `List` on iPad gets inset grouped style automatically.
- Nothing more; `NavigationSplitView` would double the surface area for no graded benefit.

## Screen details

### SearchView
- `.navigationTitle("Search")`, `.searchable(text: $vm.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Title, author or subject")`.
- Body switches on `vm.phase` (see 05 §5). `List` with `.listStyle(.plain)`.
- `NavigationLink(value: book)` + `.navigationDestination(for: Book.self)` → details.
- Row trailing `Image(systemName: "bookmark.fill")` when saved (R4.4), `.foregroundStyle(.tint)`.

### BookDetailsView
- `ScrollView` → hero `CoverView(size: .large)` centred → title `.title2.bold()` → authors
  `.subheadline.secondary` → first publish → **Save toggle** (prominent, full width) → description
  (`Text` with `.textSelection(.enabled)`, "Read more" expander if > 8 lines) → subjects as
  wrapping chips (custom `FlowLayout` `Layout` — ~40 lines, reusable, or a simple `LazyVGrid(adaptive)`).
- `.task { await vm.load() }` (runs once per appearance; cancellation on pop is automatic).
- Offline + local source: small caption "Showing saved copy" (`.footnote.secondary`).
- Error: `ErrorStateView` **plus** the Save button still available if we have seed data
  (user can still save a book they found when the details endpoint is down — sensible fallback,
  document as assumption).

### ShelfView
- `List(vm.filteredBooks)` with `.onDelete`/swipe `Button(role: .destructive)` → `store.remove`.
- Empty: `ContentUnavailableView("Your shelf is empty", systemImage: "books.vertical", description: Text("Save books from Search to read them offline."))`.
- O1 filter `Picker` in a toolbar or as `.pickerStyle(.segmented)` above the list; hidden when
  shelf empty.
- Rows use `preloadedData: book.coverData` (offline covers).

## Definition of done for UI (self-check before recording the video)

- [ ] Every state of every screen reachable and screenshot-verified (light + dark).
- [ ] `Accessibility Inspector` audit: no "missing label" warnings on screens.
- [ ] Settings ▸ Accessibility ▸ Larger Text at max: no clipped/truncated titles, buttons still tappable.
- [ ] App Language = Arabic: layout mirrors correctly, no clipped Arabic text, chevrons point left.
- [ ] iPad simulator (any): no absurdly wide paragraphs; tabs work.
- [ ] VoiceOver walk-through of Search → Details → Save → Shelf → Delete makes sense by ear alone.
