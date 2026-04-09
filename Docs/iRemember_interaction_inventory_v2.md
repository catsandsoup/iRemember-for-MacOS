# iRemember Interaction Inventory v2

This document turns the design brief and interaction spec into an implementation-facing inventory of interactive behavior.

Status labels:
- `Already exists`
- `Partial`
- `Missing`

## Audit Summary

### Sidebar
- Browse mode toggle: `Partial`
- Archive row selection and preserved return state: `Partial`
- Typed search results with routing: `Missing`
- Conversation context menu export actions: `Missing`

### Transcript Header
- Calm archive identity presentation: `Partial`
- Mode switcher and inspector affordance: `Already exists`
- Export entry point: `Already exists`

### Transcript Body
- Bounded window loading: `Already exists`
- Reply jump with preserved return path: `Partial`
- Search jump highlight in context: `Missing`
- Missing-content honesty and context menus: `Partial`

### Timeline Rail
- Year and month anchors: `Partial`
- Hover-only activation: `Partial`
- Pending drag target and release-to-commit semantics: `Missing`
- Preserved return path after timeline jump: `Partial`

### Inspector
- Person/archive summary: `Partial`
- Shared content preview: `Already exists`
- Merge actions with persistence: `Missing`
- Export shortcuts: `Partial`

### Media Browser / Shared Content
- Shared media browsing: `Already exists`
- Reveal in context: `Already exists`
- Missing-original honesty: `Partial`
- Context menus and keyboard polish: `Partial`

### Export Sheet / Commands
- Native sheet/save flow: `Already exists`
- Human-readable scope/type/include language: `Partial`
- Menu bar and context-menu entry points: `Missing`
- Shared-content specific export flows: `Missing`

### Merge / Contact Flows
- People mode as real merged archive: `Missing`
- Persisted keep-separate / always-merge overrides: `Missing`

### Empty / Loading / Missing-Content States
- Onboarding/loading/failure states: `Already exists`
- Calm missing-original messaging in transcript/media: `Partial`
- No-results and no-selection states: `Partial`

### Session Restore / Relaunch
- Per-thread transient in-memory restore: `Partial`
- Cross-relaunch persistence via SwiftData: `Missing`
- Graceful fallback when restore target is gone: `Missing`

### Accessibility / Keyboard / Context Menus
- Baseline labels and identifiers: `Partial`
- VoiceOver-friendly timeline/search/media affordances: `Partial`
- Large text / truncation review: `Partial`
- Archive-level context menus: `Missing`

## Sidebar

### Browse Mode Toggle
- User intent: switch between raw thread archives and merged person archives.
- Entry point: segmented control under the Archive heading.
- Trigger: click `Threads` or `People`, or the matching keyboard/menu command.
- Preconditions: library is loaded.
- App interpretation: preserve the current human context if possible instead of resetting to a random item.
- Data/query behavior: rebuild the sidebar source from raw conversations or merged person archives; do not move corpus data into SwiftData.
- UI outcome: the list relabels and reselections to the corresponding archive where possible.
- State updates: `sidebarMode`, current archive selection, persisted session snapshot.
- Keyboard behavior: command-driven mode switches should mirror pointer behavior.
- Right-click/context menu behavior: none on the toggle itself.
- VoiceOver text: “Browse mode, Threads” or “Browse mode, People”.
- Dark mode / large text notes: avoid truncating both segments at common window widths.
- Empty/failure behavior: if the corresponding archive no longer exists, fall back to the most recent valid archive.

### Archive Row Selection
- User intent: open an archive and resume browsing without losing historical place.
- Entry point: archive list row in the sidebar.
- Trigger: click anywhere in the row hit area.
- Preconditions: archive metadata exists.
- App interpretation: select the archive, not a sub-label.
- Data/query behavior: restore the saved archive session if valid; otherwise load the newest bounded transcript window.
- UI outcome: row selection updates, transcript loads, inspector follows.
- State updates: selected archive, representative conversation ID, transcript window, anchor, inspector context, persisted session.
- Keyboard behavior: selection should be reachable from the sidebar list and commit on keyboard selection.
- Right-click/context menu behavior: `Open Archive`, `Export Archive…`, `Export Loaded Range…`.
- VoiceOver text: archive title, snippet, last activity date.
- Dark mode / large text notes: keep snippet to two lines max and preserve clear selection contrast.
- Empty/failure behavior: show a calm unavailable state rather than landing in a blank half-shell.

### Typed Search Results
- User intent: find a conversation, message, photo, link, or file without filtering the transcript destructively.
- Entry point: search field and `Search In` menu.
- Trigger: type a query, change search scope, select a typed result.
- Preconditions: library loaded; query is non-empty.
- App interpretation: switch from archive browsing to typed result browsing, not row filtering.
- Data/query behavior: search remains SQL-backed / source-backed; conversation results may use loaded metadata, message and attachment results should come from source queries.
- UI outcome: sidebar shows typed results with kind badges and archive/date context.
- State updates: `searchText`, `searchScope`, `searchResults`, `isSearching`.
- Keyboard behavior: arrow keys should traverse results; Return should jump in context.
- Right-click/context menu behavior: `Jump in Context`.
- VoiceOver text: result type, primary title, archive title, snippet/date.
- Dark mode / large text notes: type badges should not rely only on color.
- Empty/failure behavior: “No Matches” state with scope hint; no silent fallback to archive filtering.

## Transcript Header

### Archive Identity
- User intent: confirm which archive is open and whether it is raw or merged.
- Entry point: top of the transcript pane.
- Trigger: archive selection changes.
- Preconditions: selected archive exists.
- App interpretation: show calm identity, not analytics.
- Data/query behavior: use archive summary plus range metadata.
- UI outcome: avatar, title, subtle subtitle, linked handles if helpful.
- State updates: none beyond selection-driven rendering.
- Keyboard behavior: header controls participate in normal focus order.
- Right-click/context menu behavior: none required.
- VoiceOver text: archive title and archive subtitle.
- Dark mode / large text notes: header should wrap title cleanly before controls collapse.
- Empty/failure behavior: fallback to generic archive label if metadata is incomplete.

### Header Actions
- User intent: switch content mode, export, reveal inspector.
- Entry point: header right-side controls.
- Trigger: segmented mode picker, `Export`, info button.
- Preconditions: archive selected.
- App interpretation: secondary controls should not reset transcript state.
- Data/query behavior: mode switches reuse the current archive detail; export opens native sheet without eager full reload unless needed.
- UI outcome: transcript/media switches cleanly; export sheet appears; inspector opens.
- State updates: `contentMode`, `isInspectorVisible`, export state.
- Keyboard behavior: all actions should have menu equivalents.
- Right-click/context menu behavior: none.
- VoiceOver text: explicit labels for “Show archive details” and export affordances.
- Dark mode / large text notes: preserve separation between picker and border buttons.
- Empty/failure behavior: disable actions when no archive is selected.

## Transcript Body

### Windowed Loading
- User intent: browse older or newer history without loading the full corpus.
- Entry point: transcript edge buttons and jump actions.
- Trigger: `Load Earlier Messages`, `Load Later Messages`, date/search/reply/timeline jumps.
- Preconditions: archive detail exists.
- App interpretation: adjust the bounded window while preserving continuity.
- Data/query behavior: SQL/source-backed window fetches centered on the active anchor.
- UI outcome: transcript extends or recenters in place.
- State updates: transcript window, active anchor, visible message IDs, persisted archive session.
- Keyboard behavior: later add keyboard-driven older/newer navigation.
- Right-click/context menu behavior: none.
- VoiceOver text: “Load earlier messages” / “Load later messages”.
- Dark mode / large text notes: controls should remain distinct from day separators.
- Empty/failure behavior: if a fetch fails, fall back to a calm error surface rather than a silent empty transcript.

### Message Selection And Reply Jump
- User intent: inspect a message, jump to a quoted original, and return.
- Entry point: message bubble, reply preview block.
- Trigger: click a message, click a reply preview, choose reply context menu.
- Preconditions: referenced message GUID resolves in the current archive.
- App interpretation: quoted-message jumps are deliberate archive navigation and must preserve return state.
- Data/query behavior: anchor around the target message and keep the jump origin snapshot.
- UI outcome: original message loads in context with subtle highlight; status bar offers return affordance.
- State updates: selected message, active anchor, jump origin, highlighted message.
- Keyboard behavior: selected message should remain focusable after the jump and after return.
- Right-click/context menu behavior: `Jump to Original`, `Copy Message`.
- VoiceOver text: sender, timestamp, body, plus explicit reply action label.
- Dark mode / large text notes: highlight should remain subtle and readable.
- Empty/failure behavior: if the original is missing, show a calm “Original message unavailable in this archive” explanation.

### Attachments And Missing Content
- User intent: understand whether shared content exists locally and what to do next.
- Entry point: inline attachment/media block.
- Trigger: click media, right-click file/link/media.
- Preconditions: attachment metadata exists.
- App interpretation: missing originals should be stated plainly, not implied by an empty preview.
- Data/query behavior: preview thumbnails are lazy; originals stream only when locally available.
- UI outcome: inline thumbnails/files, unavailable badge, Finder reveal when possible.
- State updates: selected media asset, content mode if media browser opens.
- Keyboard behavior: attachments should expose actions through context menu and focus.
- Right-click/context menu behavior: `Inspect Media`, `Reveal in Finder` when local.
- VoiceOver text: attachment filename, type, availability.
- Dark mode / large text notes: availability badges need contrast over media.
- Empty/failure behavior: “Original unavailable on this Mac” should replace silent failure.

## Timeline Rail

### Hover Activation
- User intent: orient temporally without triggering navigation.
- Entry point: right-edge timeline rail.
- Trigger: hover over year/month groups.
- Preconditions: archive timeline snapshot exists.
- App interpretation: hover expands/activates the rail visually only.
- Data/query behavior: no transcript reload on hover.
- UI outcome: years expand, focus badge updates only for pending drag state, not plain hover.
- State updates: hovered/expanded year.
- Keyboard behavior: later add keyboard movement across years/months.
- Right-click/context menu behavior: not required.
- VoiceOver text: “Jump to 2025”, “Jump to March 2025”.
- Dark mode / large text notes: month labels should remain legible at narrow widths.
- Empty/failure behavior: show “No timeline anchors available yet.”

### Click And Drag Jump
- User intent: jump to a meaningful historical anchor and preserve a way back.
- Entry point: year and month chips in the rail.
- Trigger: click year/month, drag across the rail, release.
- Preconditions: archive detail loaded.
- App interpretation: click commits immediately; drag previews a pending target and only commits on release.
- Data/query behavior: no repeated transcript window reloads while scrubbing; only final commit should fetch.
- UI outcome: pending target shows in the status/focus badge; committed target recenters transcript and exposes return path.
- State updates: pending timeline date, active anchor, jump origin, highlighted message.
- Keyboard behavior: later map arrow keys and Return to the same state transitions.
- Right-click/context menu behavior: not required.
- VoiceOver text: focused temporal target plus “Release to jump” during scrub if possible.
- Dark mode / large text notes: pending and committed states must be distinguishable without heavy color.
- Empty/failure behavior: if no message exists in the exact bucket, jump to nearest indexed context and say so nowhere unless the miss is user-visible.

## Inspector

### Person / Archive Summary
- User intent: confirm merged handles, archive counts, and provenance without cluttering the transcript.
- Entry point: inspector top cards.
- Trigger: archive selection changes.
- Preconditions: archive selected.
- App interpretation: show archive metadata, not dashboard analytics.
- Data/query behavior: use archive summary/detail counts.
- UI outcome: person card, shared counts, archive counts, source card.
- State updates: none beyond selection-driven rendering.
- Keyboard behavior: inspector controls should be tabbable.
- Right-click/context menu behavior: optional on preview items.
- VoiceOver text: explicit linked-handle count and archive range.
- Dark mode / large text notes: cards must preserve hierarchy without thin low-contrast separators only.
- Empty/failure behavior: show “No Selection” content-unavailable state.

### Merge Actions
- User intent: decide whether fragmented raw threads should stay separate or merge into one person archive.
- Entry point: merge card in inspector for thread mode.
- Trigger: `View Merged`, `Keep Separate`, `Always Merge`.
- Preconditions: selected thread participates in a mergeable person archive or has multiple handles/provenance.
- App interpretation: `View Merged` is navigational; `Keep Separate` and `Always Merge` are persisted overrides.
- Data/query behavior: store only app-owned decisions in SwiftData; never move corpus data there.
- UI outcome: people archive selection updates immediately after persistence.
- State updates: merge-decision store, rebuilt person archives, selected archive if mode changes.
- Keyboard behavior: buttons activate with standard keyboard focus/action behavior.
- Right-click/context menu behavior: optional duplicate actions in archive row menus later.
- VoiceOver text: explain the consequence of each action.
- Dark mode / large text notes: action order should keep the non-destructive choice obvious.
- Empty/failure behavior: if persistence fails, keep the current thread view and surface a calm failure message.

## Media Browser / Shared Content

### Shared Media Browsing
- User intent: inspect all photos/videos in the selected archive and reveal them in transcript context.
- Entry point: content mode switcher or shared preview thumbnails.
- Trigger: switch to `Media`, click a thumbnail, right-click a card.
- Preconditions: archive detail and media assets exist.
- App interpretation: media browser is a first-class archive mode, not an overlay.
- Data/query behavior: use archive attachment metadata, not transcript hydration alone.
- UI outcome: grid of media cards, selection outline, inspector detail, transcript reveal action.
- State updates: `contentMode`, selected media asset.
- Keyboard behavior: selection and reveal should be reachable from focus.
- Right-click/context menu behavior: `Reveal in Transcript`, `Reveal in Finder` when local.
- VoiceOver text: filename, sender, sent date, availability.
- Dark mode / large text notes: filenames should truncate without crushing thumbnail scale.
- Empty/failure behavior: `No Shared Media` state instead of a blank pane.

## Export Sheet / Export Commands

### Export Command Surfaces
- User intent: export the current archive from a predictable Mac location.
- Entry point: File menu, iRemember menu, inspector buttons, archive row context menu, future transcript/media context menus.
- Trigger: choose an export command.
- Preconditions: archive selected.
- App interpretation: all entry points lead into the same native export sheet and shared export state.
- Data/query behavior: export remains transcript/archive-backed; no hidden persistence beyond defaults/history if added later.
- UI outcome: native save panel flow with format/scope/include configuration.
- State updates: export sheet state, export defaults, last export description.
- Keyboard behavior: menu commands should mirror pointer entry points.
- Right-click/context menu behavior: archive-level export should be available from the sidebar row.
- VoiceOver text: “Export archive”, “Export loaded context”, format labels, include toggles.
- Dark mode / large text notes: keep toggles single-column and human-readable.
- Empty/failure behavior: disable export commands when no archive is selected; on failure, show the error summary in the sheet/status area.

### Export Sheet
- User intent: choose output format, scope, and inclusion rules without learning technical jargon.
- Entry point: modal export sheet.
- Trigger: export command opens sheet.
- Preconditions: archive selected.
- App interpretation: scope and include toggles define one coherent export job.
- Data/query behavior: full-archive export may need complete source reads; loaded-context export must reuse current window.
- UI outcome: segmented format picker, human-readable scope picker, include toggles, optional date-range pickers.
- State updates: export configuration and optional persisted defaults/history later.
- Keyboard behavior: default action commits export; Escape cancels.
- Right-click/context menu behavior: not on the sheet itself.
- VoiceOver text: clear labels for scope and include toggles.
- Dark mode / large text notes: avoid compressing picker labels into ambiguous abbreviations.
- Empty/failure behavior: if no messages match the selected date range/content toggles, explain that before saving.

## Empty / Loading / Missing-Content States

### Onboarding / Loading / Failure
- User intent: understand what the app is waiting on and how to recover.
- Entry point: root shell state.
- Trigger: first launch, library bootstrap, source failure.
- Preconditions: app is not yet in ready state.
- App interpretation: source setup and recovery are first-class states, not background details.
- Data/query behavior: show setup snapshot and progress milestones from the source layer.
- UI outcome: onboarding, loading assistant, or recovery instructions.
- State updates: access state, progress, setup snapshot, failure metadata.
- Keyboard behavior: buttons should be reachable without a mouse.
- Right-click/context menu behavior: not required.
- VoiceOver text: current step, requirement status, failure title and recovery steps.
- Dark mode / large text notes: avoid fixed-size titles that clip under larger settings.
- Empty/failure behavior: never fall through to an empty ready shell while data is still unstable.

## Session Restore / Relaunch

### Persisted Session Continuity
- User intent: relaunch the app and continue where they left off.
- Entry point: app relaunch after a previously saved session.
- Trigger: archive load completes and a saved session exists.
- Preconditions: saved archive target still resolves; saved transcript window is still valid.
- App interpretation: restore only complete, valid state; otherwise degrade to the most recent archive.
- Data/query behavior: keep corpus in source/SQLite; persist only app-owned state in SwiftData.
- UI outcome: sidebar mode, archive selection, transcript anchor/window, inspector visibility, and optional search restore.
- State updates: SwiftData session record and in-memory archive session snapshots.
- Keyboard behavior: restored selection should also restore keyboard focus expectations where practical.
- Right-click/context menu behavior: not applicable.
- VoiceOver text: no special text required beyond restored visible state.
- Dark mode / large text notes: none specific.
- Empty/failure behavior: if the archive or window no longer exists, log the fallback and open a recent archive cleanly.

## Accessibility / Keyboard / Context Menus

### Cross-Cutting Requirements
- User intent: operate the archive calmly with keyboard and assistive technologies.
- Entry point: every interactive element.
- Trigger: focus movement, keyboard commands, VoiceOver navigation, right-click.
- Preconditions: none beyond standard view availability.
- App interpretation: archive reading must remain calm and explicit; hidden affordances need command/menu equivalents.
- Data/query behavior: accessibility labels should describe result type, archive title, temporal target, and missing-content states.
- UI outcome: labeled buttons, result rows, timeline controls, inspector actions, and attachment states.
- State updates: none beyond the same state transitions used by pointer actions.
- Keyboard behavior: support mode switches, jump to date, transcript/media switching, previous/next day, search result activation, and export commands.
- Right-click/context menu behavior: archive rows, message bubbles, reply previews, media cards, and attachment blocks should all expose the most relevant actions.
- VoiceOver text: prefer concise labels that include role, archive/message identity, and availability state.
- Dark mode / large text notes: do not rely on thin separators or color-only distinctions.
- Empty/failure behavior: all “nothing here” states must be announced semantically, not just visually.
