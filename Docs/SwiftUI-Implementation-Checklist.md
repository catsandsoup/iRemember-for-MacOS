# SwiftUI Implementation Checklist

Reviewed against Apple documentation on April 5, 2026.

This checklist is for `iRemember for Messages`, not for a generic SwiftUI app. Apple documentation is the primary source of truth. The Medium article on `TimelineView` and `Canvas` is useful as a pattern reference, but it should not override Apple’s platform guidance or lead to gratuitous animation.

## Reference baseline

Primary references:

- [SwiftUI](https://developer.apple.com/swiftui/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Adding a search interface to your app](https://developer.apple.com/documentation/SwiftUI/Adding-a-search-interface-to-your-app)
- [Canvas](https://developer.apple.com/documentation/swiftui/canvas)
- [EveryMinuteTimelineSchedule](https://developer.apple.com/documentation/SwiftUI/EveryMinuteTimelineSchedule)
- [Creating a data visualization dashboard with Swift Charts](https://developer.apple.com/documentation/charts/creating-a-data-visualization-dashboard-with-swift-charts)
- [Filtering and sorting persistent data](https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data)
- [Maintaining a local copy of server data](https://developer.apple.com/documentation/swiftdata/maintaining-a-local-copy-of-server-data)
- [Unifying your app’s animations](https://developer.apple.com/documentation/swiftui/unifying-your-app-s-animations)
- [Creating visual effects with SwiftUI](https://developer.apple.com/documentation/swiftui/creating-visual-effects-with-swiftui)
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

Secondary inspiration:

- [Advanced Animations in SwiftUI: Using TimelineView and Canvas](https://commitstudiogs.medium.com/advanced-animations-in-swiftui-using-timelineview-and-canvas-cf71fbcb2f11)

## Native app observations to emulate

From the screenshots of Calendar, Messages, Contacts, and Music:

- [ ] Keep chrome restrained. Apple apps let content dominate and keep the window frame, toolbar, separators, and materials quiet.
- [ ] Use layout hierarchy instead of decoration. The native apps rely on pane structure, spacing, typography, and selection states more than on borders, cards, gradients, or heavy shadows.
- [ ] Keep inspectors contextual. Calendar’s right column supports the selected item instead of competing with the main content.
- [ ] Let the center pane breathe. Messages and Contacts both leave large uninterrupted content surfaces rather than overfilling every area with controls.
- [ ] Match density to task. Music uses a dense table because the task is catalog browsing; Messages uses softer bubbles and whitespace because the task is conversational reading.
- [ ] Keep search in the toolbar or the expected platform slot. Do not invent custom always-floating search UI.

## 1. SwiftUI-first app structure

- [ ] Use SwiftUI scenes (`WindowGroup`, `Settings`, and additional windows only when there is a clear task reason).
- [ ] Keep feature state in SwiftUI-friendly observable models using current Apple patterns such as `@Observable`, `@Bindable`, environment values, and bindings where appropriate.
- [ ] Keep the UI declarative. Avoid imperative AppKit view orchestration unless a platform gap requires it.
- [ ] If AppKit interop is required, isolate it behind thin adapters and keep animation/state ownership in SwiftUI.
- [ ] Ensure every major feature has a previewable SwiftUI view model and deterministic sample data.

## 2. Navigation and window layout

- [ ] Use `NavigationSplitView` as the primary shell.
- [ ] Sidebar content should be true navigation and saved views, not a dumping ground for secondary controls.
- [ ] The center pane should switch cleanly between transcript, search results, timeline mode, and media mode without rebuilding the entire window state.
- [ ] The right-side surface should behave like an inspector: metadata, filters, export options, selected media details, and timeline summaries.
- [ ] Use column widths intentionally and keep resizing behavior stable across common Mac window sizes.
- [ ] Preserve native toolbar placement and avoid custom top bars that duplicate standard macOS window chrome.
- [ ] Use `Table` where the task is tabular and high-density, such as export history, diagnostics, and maybe attachment manifests.
- [ ] Use `List` where the task is browsing navigable collections, such as conversations and saved searches.

## 3. Search implementation

- [ ] Implement search with SwiftUI’s `searchable` APIs rather than a bespoke search field unless a clear limitation forces otherwise.
- [ ] Add search scopes for broad filters such as `All`, `Messages`, `Media`, `Links`, `Photos`, `Videos`, and `Sender`.
- [ ] Use programmatic search presentation only when it materially improves keyboard-first workflows.
- [ ] Keep simple search and advanced search in the same native search system instead of building an unrelated custom filter surface.
- [ ] Support date-oriented search through native controls integrated into search or adjacent toolbar affordances, not a separate modal-heavy flow for routine use.
- [ ] Ensure search can narrow results without forcing a full-thread preload.

## 4. Transcript implementation

- [ ] Use a SwiftUI transcript implementation that keeps rendering bounded. Do not load full multi-year threads into one view tree.
- [ ] Group transcript content by day using lightweight section headers and sticky context where it helps orientation.
- [ ] Use lazy containers and viewport-based paging around the active anchor.
- [ ] Keep message bubble styling familiar to Messages without copying Apple branding literally.
- [ ] Use native text selection, link detection, context menus, Quick Look-style preview affordances, and keyboard navigation.
- [ ] Preserve stable identity for messages so scroll position, selection, and focus survive incremental loads.
- [ ] Use scroll APIs carefully for jump-to-date and reveal-in-context flows; scrolling should retarget the viewport, not rebuild the transcript.
- [ ] Keep inline attachments lightweight; originals should stream on demand.

## 5. Timeline and time navigation

- [ ] Time must be a first-class control in the UI, not just a filter buried in search.
- [ ] Release 2 should provide exact date jump and date-range search before any decorative timeline work.
- [ ] Release 3 should add a compact timeline rail plus a larger dedicated timeline mode.
- [ ] Use Swift Charts for message-density and media-density views when the data is fundamentally chart-like.
- [ ] Use `TimelineView` only when the view needs scheduled updates over time, such as animated scrub feedback, a live playhead, or time-driven visual interpolation.
- [ ] Use `Canvas` only for custom drawing that benefits from immediate-mode rendering and does not need per-element accessibility or interaction.
- [ ] Prefer static or lightly animated density views first. Only move to `TimelineView` plus `Canvas` if profiling shows it gives a real advantage for scrubbing or very large datasets.
- [ ] Keep the timeline visually quiet. It should behave like Calendar’s time structure: informative, not flashy.
- [ ] Ensure bucket-to-transcript anchoring is exact and reversible.
- [ ] Make month, week, and day zoom transitions clear and restrained.

### Mobile-style date scrubber concept

The mobile concept you attached is a good model for quick temporal orientation:

- [ ] Treat the idea as a compact date scrubber for rapid jump navigation.
- [ ] On macOS, adapt it into a horizontal or rail-based control that works with pointer, trackpad, mouse wheel, and keyboard.
- [ ] Use it for high-frequency jumps between nearby dates or weeks, not as the only timeline representation.
- [ ] Keep labels sparse and legible, with clear current focus and selected anchor.
- [ ] Pair the scrubber with transcript repositioning and sticky date feedback so the user always knows where they landed.
- [ ] Support semantic zoom: day strip for local browsing, week/month density views for broader travel.
- [ ] Make the scrubber inertial and smooth only if that improves control; avoid novelty scrolling for its own sake.
- [ ] Ensure the control is fully keyboard accessible and VoiceOver describable.
- [ ] If the product later gets an iPhone or iPad client, this concept can become the touch-first timeline primitive with shared domain logic but platform-specific presentation.

## 6. Swift Charts usage

- [ ] Use Swift Charts for:
- [ ] Message density by day, week, month.
- [ ] Media density over time.
- [ ] Export progress summaries or diagnostics only if a chart conveys trend or distribution better than text.
- [ ] Do not use charts for:
- [ ] Transcript rendering.
- [ ] Conversation lists.
- [ ] Simple totals that are clearer as labels.
- [ ] Prefer native chart semantics, axes, selection, and accessibility support over hand-drawn chart-like components.
- [ ] For large data collections, use modern chart APIs that scale efficiently rather than many per-mark view allocations when possible.
- [ ] Make sure chart colors maintain contrast and remain legible in light mode, dark mode, and increased contrast.

## 7. Motion and animation

- [ ] Use SwiftUI animation APIs as the default motion system.
- [ ] Prefer Apple-standard animation curves such as `.smooth`, `.snappy`, and spring-based animations before inventing custom timing.
- [ ] Use `withAnimation` and transaction control to unify motion behavior across related state changes.
- [ ] Use `contentTransition` where text or numeric metadata changes in place.
- [ ] Use `symbolEffect` only for purposeful icon feedback, not ambient ornament.
- [ ] Use `phaseAnimator` or `keyframeAnimator` only when the interaction has distinct semantic phases.
- [ ] Use matched transitions or navigation transitions only where the user benefits from spatial continuity, such as opening a media item from the grid into a larger preview.
- [ ] Respect `Reduce Motion`; all nonessential animations must degrade gracefully.
- [ ] Avoid continuous animation in the baseline UI. The app should feel calm like Calendar and Messages, not like a dashboard.
- [ ] If mixing AppKit and SwiftUI, keep animation timing unified using Apple’s current guidance on cross-framework animation consistency.

## 8. Data layer, SQLite, and SwiftData

- [ ] Do not force SwiftData onto every persistence problem. That is not the right architectural rule for this product.
- [ ] Keep a read-only source layer for Messages access that is separate from the app-facing domain model.
- [ ] Use a normalized app-facing model for conversations, participants, messages, attachments, media assets, timeline buckets, exports, and saved searches.
- [ ] Use SQLite for the high-volume derived index, search structures, timeline buckets, and media metadata where scale and control matter most.
- [ ] Use SwiftData selectively for lower-volume app-owned state if it improves development speed and integrates cleanly with SwiftUI.
- [ ] Good SwiftData candidates:
- [ ] Saved searches.
- [ ] Smart collections.
- [ ] Export history.
- [ ] UI restoration state.
- [ ] Diagnostics snapshots.
- [ ] Poor SwiftData candidates unless benchmarking proves otherwise:
- [ ] The entire mirrored message corpus.
- [ ] Massive token indexes.
- [ ] High-churn attachment metadata caches.
- [ ] Any store layout that needs tight manual SQL tuning for timeline/date/media performance.
- [ ] If SwiftData is used, follow Apple’s query and predicate patterns and keep query-driven views narrow and intentional.

## 9. Media browser

- [ ] Build the media browser as a first-class mode, not as a bolted-on sheet.
- [ ] Use `LazyVGrid` or another paged SwiftUI layout for media browsing.
- [ ] Preserve large thumbnail spacing and quiet metadata treatment similar to how Apple apps let artwork breathe.
- [ ] Keep selection, preview, and reveal-in-context behaviors separate and obvious.
- [ ] Use native preview patterns for images and video where possible.
- [ ] Avoid tiny thumbnails, dense overlays, or aggressive hover chrome.
- [ ] Support chronological grouping and date filters without requiring transcript hydration.
- [ ] Use matched transitions sparingly if they make media preview feel more spatially coherent.

## 10. Inspector and secondary panels

- [ ] The inspector should summarize the selected conversation, message, timeline range, or media item.
- [ ] Do not duplicate the transcript or media browser in the inspector.
- [ ] Keep inspector cards compact and semantically grouped, similar to Calendar’s detail presentation.
- [ ] Put destructive or high-commitment actions behind clear confirmation flows.
- [ ] Surface export counts, destination, scope, and privacy implications directly in the inspector or export sheet.

## 11. Toolbar, commands, and keyboard support

- [ ] Follow macOS toolbar grouping conventions from Apple’s HIG.
- [ ] Keep essential actions in the toolbar: search, date jump, mode switching, sidebar toggles, inspector toggle, export entry points.
- [ ] Put secondary actions in menus or command groups rather than crowding the toolbar.
- [ ] Add menu bar commands and keyboard shortcuts for search, jump to date, next/previous result, transcript/media toggle, and export.
- [ ] Support full keyboard navigation through sidebar, transcript, media grid, inspector, and sheets.

## 12. Accessibility

- [ ] Audit VoiceOver labels, roles, values, and reading order across every pane.
- [ ] Ensure chart and timeline views have accessible summaries and alternative navigation paths.
- [ ] Do not make `Canvas` the only way to understand a timeline; provide semantic labels and alternate controls.
- [ ] Support Dynamic Type where it applies on macOS and ensure truncation remains graceful.
- [ ] Verify high contrast, increased contrast, reduce transparency, and reduce motion.
- [ ] Ensure multi-select media state is visible without relying only on color.
- [ ] Make export outputs and manifests accessible and machine-readable.

## 13. Performance and memory discipline

- [ ] Benchmark with the PRD dataset sizes, not only sample data.
- [ ] Use Instruments to measure hangs, hitches, allocations, leaks, and SwiftUI view update cost.
- [ ] Keep thumbnail caches bounded and observable.
- [ ] Make transcript paging, media paging, search work, and index updates cancellable.
- [ ] Ensure switching between transcript and media modes does not cause a full reload of the conversation.
- [ ] Avoid broad `@State` or observable mutations that invalidate the whole window for small changes.
- [ ] Keep expensive transforms off the main actor.
- [ ] Use Xcode preview and runtime diagnostics to inspect layout, accessibility, and appearance regressions.

## 14. Release-specific implementation checklist

### Release 1

- [ ] Native onboarding and permission education.
- [ ] Conversation list, transcript shell, basic inspector, settings, and privacy views.
- [ ] Real source abstraction with documented read-only behavior.
- [ ] Viewport-based transcript loading.
- [ ] Thumbnail cache with bounded memory.
- [ ] Architecture benchmark documenting live, indexed, and hybrid tradeoffs.

### Release 2

- [ ] Exact date jump.
- [ ] Date range search.
- [ ] Around-this-date context expansion.
- [ ] Sticky date markers.
- [ ] Keyboard-first time navigation.

### Release 3

- [ ] Compact timeline rail.
- [ ] Dedicated timeline mode.
- [ ] Message-density summaries using Swift Charts unless a measured custom renderer is required.
- [ ] Custom `TimelineView` plus `Canvas` only if needed for smooth scrub feedback or high-scale rendering.

### Release 4

- [ ] Dedicated media browser.
- [ ] Multi-select and bulk export.
- [ ] Streaming export engine with resumable jobs.
- [ ] Sidecar metadata and transcript reveal flows.

### Release 5+

- [ ] Archive/export rendering pipelines.
- [ ] Evidence mode.
- [ ] Saved searches and smart collections.
- [ ] Optional local index encryption and diagnostics tooling.

## 15. Definition of done for “proper SwiftUI implementation”

- [ ] The UI uses native SwiftUI navigation, search, selection, commands, and presentation APIs wherever they are sufficient.
- [ ] AppKit interop is minimal, justified, and isolated.
- [ ] Charts are implemented with Swift Charts where the UI is genuinely chart-based.
- [ ] Timelines use `TimelineView` or `Canvas` only when time-driven rendering or custom drawing is actually required.
- [ ] Motion uses Apple’s animation system and stays calm, purposeful, and accessibility-aware.
- [ ] Persistence choices are workload-driven: SwiftData where it helps, SQLite where scale and indexing demand it.
- [ ] The app feels visually aligned with Apple’s native macOS apps: quiet chrome, clear hierarchy, strong spacing, contextual inspectors, and no gratuitous custom styling.
- [ ] Performance targets and accessibility checks pass on realistic datasets.

## Current recommendation for this codebase

- [ ] Keep SwiftUI as the mandatory UI framework.
- [ ] Keep SQLite as the likely primary derived-index store.
- [ ] Use SwiftData only for app-owned lightweight state unless benchmarking proves it can handle more.
- [ ] Plan for Swift Charts in Release 3 timeline density views.
- [ ] Plan for `TimelineView` plus `Canvas` only for the scrubber or timeline rail if the standard chart implementation cannot stay smooth at multi-year scale.
- [ ] Keep animation conservative and system-like from the start.
