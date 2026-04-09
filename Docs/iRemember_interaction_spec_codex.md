# iRemember Interaction Specification (Codex-Ready)

## Purpose

This document defines **user interactions and intended outcomes** for iRemember in implementation-oriented language.

It goes beyond:
- “user clicks X”
- “screen opens”

Instead it describes:
- user intent
- trigger
- selection behavior
- data/query behavior
- loading strategy
- state changes
- view updates
- navigation outcomes
- contextual menus
- export flows
- accessibility behavior

This is intended to help implementation in **SwiftUI**, with architecture that may use:
- `NavigationSplitView`
- `NavigationStack`
- observable app state / store
- async loading tasks
- searchable UI
- context menus
- inspector panels
- file exporters / save panels
- model-backed collections
- persisted selection state

---

# 1. What this type of thinking is called

The type of thinking requested here is usually a combination of:

- **interaction design**
- **behavior specification**
- **user flow design**
- **state modeling**
- **event-driven UX design**
- **functional specification**
- **use-case specification**
- **interaction contract design**

In product and engineering terms, the most accurate labels are probably:

## Best-fit labels
- **interaction specification**
- **behavioral specification**
- **event/state UX specification**

Because the goal is not just visuals or wireframes, but:

**When the user does X, how does the app interpret it, what state changes, what loads, and what outcome appears?**

That is exactly the level that bridges design and implementation.

---

# 2. Guiding Interaction Principles

## 2.1 Intent first
Model the user’s intention, not just the click target.

Bad:
- user clicks row

Better:
- user chooses a conversation to revisit from the sidebar

## 2.2 Outcome over mechanism
Each interaction should specify the intended result.

Bad:
- app scrolls

Better:
- app restores the user to the relevant historical context without losing surrounding message continuity

## 2.3 Context must be preserved
The app should preserve:
- scroll position
- loaded history segment
- jump origin
- selected conversation/person
- active filters/search state
- export context
- merge mode

## 2.4 Large histories are loaded deliberately
The app should avoid loading full conversations eagerly.
Instead it should:
- load recent context initially
- load historical windows on demand
- preserve anchor points
- support precise jumps by date/search/reply/reference/media

## 2.5 Archive interactions must feel calm
The app should not surprise the user with:
- losing place
- full resets
- jarring jumps without context
- disappearing navigation history
- modal overload

---

# 3. Core Application State Model

This is a conceptual model, not a required implementation.

## 3.1 Global app state domains
- sidebar mode (`threads` or `people`)
- selected conversation or person archive
- active transcript segment/window
- transcript jump anchor
- search query
- search results
- active inspector section
- timeline hover state
- timeline drag state
- active export context
- merge suggestions / merge decisions
- current loading state
- current error state

## 3.2 Important persistent user context
The app should preserve when possible:
- last selected conversation
- last visible transcript anchor per conversation
- last active sidebar mode
- inspector visibility
- selected export format defaults
- merge overrides
- chosen sort/view preferences where appropriate

## 3.3 Transcript loading model
Recommended conceptual behavior:
- recent message window loads first
- historical windows load lazily
- explicit anchor objects identify top/bottom range boundaries
- jumps create a new anchor-centered context window
- reply jumps and search jumps should preserve a way back

---

# 4. Primary User Intents

The app primarily serves these intentions:

1. Find a conversation or person
2. Revisit a specific historical period
3. Search for a known phrase, attachment, or event
4. Open shared media/links/files in context
5. Export a conversation or historical subset
6. Merge fragmented threads into one human-facing person archive
7. Recover evidence or records from a specific date range
8. Resume exactly where the user left off

---

# 5. Interaction Specifications

Each interaction includes:
- User intent
- Entry point
- Trigger
- App interpretation
- Data behavior
- UI outcome
- State updates
- Notes

---

# 5A. Sidebar Selection and Conversation Loading

## 5A.1 Select conversation from sidebar row

### User intent
The user wants to open a conversation archive and begin browsing it.

### Entry point
Left sidebar conversation list.

### Trigger
The user clicks anywhere within the interactive row hit area for a conversation.

### App interpretation
The app interprets the row hit as selection of the conversation item, not selection of subtext or decoration.

### Interaction rule
The row should behave as a single selection target unless the user explicitly interacts with a secondary affordance such as:
- context menu
- pin toggle if one exists
- disclosure control if one exists

### Data behavior
The app:
1. records the selected conversation ID
2. checks for a previously saved transcript anchor for that conversation
3. if a saved anchor exists and the user is resuming, optionally restore that anchor
4. otherwise load the most recent transcript window into memory
5. resolve inline metadata needed for the initial visible segment:
   - sender identity
   - reactions
   - reply context
   - inline attachments
   - date separators

### UI outcome
- the selected row becomes active
- the transcript pane displays the selected conversation
- the inspector updates to reflect the selected conversation/person
- the transcript initially shows the most recent relevant message window unless a restoration anchor is used

### State updates
- `selectedConversationID`
- `activeTranscriptAnchor`
- `visibleTranscriptWindow`
- `inspectorContext`
- `selectionSource = .sidebar`

### Notes
Clicking whitespace inside the row should still select the row.
Do not require clicking the text label specifically.

---

## 5A.2 Re-select already active conversation

### User intent
The user may want to refocus the currently active conversation.

### Trigger
The user clicks the already-selected conversation row again.

### App interpretation
This should not reset transcript position by default.

### UI outcome
- maintain current transcript position
- optionally bring focus to transcript pane
- do not jump to latest unless user explicitly invokes “Jump to Latest”

### Notes
Avoid destructive resets caused by re-selection.

---

## 5A.3 Switch from one conversation to another and back

### User intent
The user wants to inspect multiple conversations without losing place.

### Trigger
The user selects another conversation, then later returns.

### App behavior
For each conversation, the app should preserve:
- last visible anchor
- last loaded historical window
- any jump origin if relevant

### UI outcome
Returning to a conversation should restore the prior historical context where feasible, not force the user back to the most recent message every time.

### Notes
This directly solves one of the product’s original pain points.

---

# 5B. Person View vs Thread View

## 5B.1 Toggle sidebar between Threads and People

### User intent
The user wants to browse raw message threads or merged person-centric archives.

### Entry point
Sidebar top segmented control or similar native mode switch.

### Trigger
The user selects `People` or `Threads`.

### App interpretation
- `Threads` shows raw source conversations
- `People` shows merged contact/person archives where handles may be grouped

### Data behavior
Switch visible collection source:
- thread-backed list for Threads
- merged identity/person-backed list for People

### UI outcome
- sidebar list updates
- transcript remains open if the current selection maps cleanly into the selected mode
- otherwise the app selects the closest equivalent entity or clears selection gracefully

### State updates
- `sidebarMode`

### Notes
This should be a calm mode change, not a different app.

---

## 5B.2 Open merged person archive

### User intent
The user wants to view a single person’s communication history across multiple handles.

### Trigger
The user selects a person in People mode.

### App interpretation
Load a merged archive timeline composed from multiple related thread sources, preserving source thread metadata under the hood.

### Data behavior
- resolve all linked handles and threads
- create a unified chronological timeline
- preserve origin thread IDs per message for reference/export fidelity

### UI outcome
- transcript shows a single merged chronological archive
- inspector shows linked handles and merge status
- export options allow exporting as merged view or raw threads if implemented

---

# 5C. Search Interactions

## 5C.1 Search from global sidebar/search field

### User intent
The user wants to locate conversations or message content using words or phrases.

### Entry point
Primary search field.

### Trigger
The user enters one or more terms.

### App interpretation
The app searches indexed message content and related entities depending on scope.

### Data behavior
Search index may include:
- message text
- participant names
- linked handles
- attachment filenames
- link titles/URLs
- dates if date-aware search is supported

### UI outcome
Search results should make clear whether the result is:
- a conversation result
- a message hit
- a media result
- a link result
- an attachment result

### State updates
- `searchQuery`
- `searchResults`
- `searchScope`

---

## 5C.2 Search phrase appears multiple times across history

### User intent
The user knows a phrase or word but needs to land in the correct historical context.

### Trigger
The user chooses one result among many repeated hits.

### App interpretation
The selected result should be treated as an **anchor into history**, not just a loose search hit.

### Data behavior
The app:
1. identifies the matched message
2. determines the target conversation/person archive
3. loads a transcript window centered around the matched message
4. includes surrounding context before and after
5. resolves inline content for that window:
   - images
   - GIFs
   - stickers
   - attachments
   - reactions
   - replies

### UI outcome
- transcript opens directly at the relevant timeframe
- matched message is highlighted subtly
- surrounding messages provide historical context
- the user can continue scrolling naturally from that point

### State updates
- `selectedConversationID`
- `activeTranscriptAnchor = .message(matchID)`
- `searchSelection`
- `selectionSource = .search`

### Notes
This is not “open conversation from the top.”
It is “open conversation at the right place in context.”

---

## 5C.3 Search within active conversation

### User intent
The user wants to find a phrase inside the currently open conversation only.

### Trigger
User invokes in-conversation search or scoped search mode.

### Data behavior
Limit search to active conversation or merged archive.

### UI outcome
- result list scoped to current context
- selecting a result jumps within transcript without leaving the conversation
- a back-to-current-position affordance may be shown

---

## 5C.4 Search by date or date range

### User intent
The user wants messages from a specific period without guessing keywords.

### Trigger
User enters date criteria or invokes Jump to Date / date-range retrieval UI.

### App behavior
The app resolves the requested date or range and loads the corresponding transcript segment.

### UI outcome
- transcript jumps to nearest relevant anchor
- date badge / time indicator confirms landing period
- user sees messages in surrounding context

### Notes
This directly addresses a core deficiency in Apple Messages.

---

# 5D. Timeline Interactions

## 5D.1 Hover over right-edge timeline rail

### User intent
The user wants to preview available historical periods before jumping.

### Trigger
Mouse pointer enters the timeline rail interaction area.

### App interpretation
The timeline becomes active/focused.

### UI outcome
- timeline gains contrast
- hovered year may magnify slightly
- floating badge may appear
- neighboring labels may spread subtly
- transcript itself does not jump yet

### State updates
- `timelineHoverState`

---

## 5D.2 Click year in timeline

### User intent
The user wants to navigate to that year quickly.

### Trigger
User clicks a year label.

### App behavior
- resolve first meaningful anchor for that year in the active archive
- load transcript window centered around that anchor
- preserve surrounding context

### UI outcome
- transcript jumps to the selected year
- date badge confirms landing point
- target area receives brief highlight/context marker

### Notes
The jump should not land on an isolated message with no context.

---

## 5D.3 Drag through year/month timeline

### User intent
The user wants to scrub time fluidly.

### Trigger
User click-drags on timeline rail.

### App behavior
- track hovered year/month target
- preview target period
- avoid reloading full transcript on every subpixel movement
- use throttled or anchor-based loading behavior

### UI outcome
- floating badge updates with month/year
- month labels appear for active year
- on release, transcript snaps to nearest valid anchor

### State updates
- `timelineDragState`
- `pendingTimelineTarget`

### Notes
This should feel gentle and stable, not hyper-reactive.

---

## 5D.4 Jump from timeline and return

### User intent
The user explores another historical period but wants an easy way back.

### App behavior
If the timeline jump represents a deliberate relocation, the app may preserve a prior anchor.

### UI affordance
Optional:
- “Back to previous position”
- breadcrumb jump marker
- navigation stack behavior

---

# 5E. Transcript Reading and Context

## 5E.1 Scroll older messages

### User intent
The user wants to continue moving backward in history.

### Trigger
The user scrolls upward toward the historical boundary of the loaded window.

### App behavior
- detect approach to top anchor threshold
- lazily request older message window
- prepend older content without visually losing the current reading position
- preserve the visible message anchor during insertion

### UI outcome
- older messages appear seamlessly
- day separators remain correct
- no snap-back to the bottom
- no full reset of the transcript view

### Notes
This is critical for archive usability.

---

## 5E.2 Scroll newer messages from historical context

### User intent
The user wants to move forward again from a historical jump point.

### Trigger
User scrolls toward lower boundary of loaded window.

### App behavior
- load newer window on demand if not already present
- append while preserving continuity

---

## 5E.3 Open transcript at latest by explicit action

### User intent
The user wants the newest messages immediately.

### Entry point
Toolbar button, menu item, keyboard shortcut, or transcript affordance.

### App behavior
Load and display most recent anchor for active archive.

### Important rule
Only do this when explicitly requested.
Do not force this during normal navigation.

---

# 5F. Inline Replies

## 5F.1 Click inline reply preview

### User intent
The user wants to inspect the original referenced message.

### Trigger
User clicks the reply preview block inside a message bubble.

### App behavior
- resolve original referenced message
- jump transcript to that message
- load missing history window if needed
- briefly highlight the original
- preserve a way back to the reply origin

### UI outcome
- original message is shown in context
- temporary “Back to previous position” affordance may appear

### State updates
- `navigationOriginAnchor`
- `activeTranscriptAnchor = .message(replyTargetID)`
- `selectionSource = .replyJump`

---

## 5F.2 Right-click inline reply preview

### User intent
The user wants alternate actions.

### Suggested context menu
- Go to Original Message
- Open in Timeline
- Copy Reply Text
- Export This Thread Segment

---

# 5G. Media, Links, and Attachments

## 5G.1 Click media attachment inline

### User intent
The user wants to view the media item.

### Trigger
User clicks photo/video/GIF/sticker/attachment tile in transcript.

### App behavior
Use appropriate native viewing behavior:
- inline expansion if appropriate
- Quick Look
- dedicated preview
- open externally if needed

### UI outcome
Media appears without losing transcript context where possible.

---

## 5G.2 Right-click media in transcript

### User intent
The user wants contextual actions related to the media item.

### Suggested context menu
- Open
- Quick Look
- Show in Timeline
- Reveal in Shared Media
- Export…
- Copy
- Save As…
- Show Message Details

## Show in Timeline outcome
- transcript jumps to the media message’s historical context
- timeline/date badge may activate
- surrounding messages remain visible

---

## 5G.3 Right-click link in transcript

### Suggested context menu
- Open Link
- Copy Link
- Show in Conversation
- Show in Timeline
- Export Links from This Conversation

---

## 5G.4 Right-click attachment in transcript

### Suggested context menu
- Open Attachment
- Quick Look
- Export Attachment
- Reveal in Conversation
- Show in Timeline

---

## 5G.5 Click shared content in inspector

### User intent
The user wants to browse photos, links, or attachments belonging to the active archive.

### Trigger
User selects Photos, Links, or Attachments section/item in inspector.

### App behavior
Open corresponding shared-content browser scoped to the active conversation/person archive.

### UI outcome
Depending on design:
- inline inspector expansion
- modal sheet
- dedicated subview
- filtered content panel

### Important rule
Selecting shared content should still allow “Show in Conversation” or “Show in Timeline.”

---

# 5H. Export Interactions

## 5H.1 Export active conversation from menu bar

### User intent
The user is in an active conversation and wants to export it.

### Entry point
macOS menu bar: `File > Export Conversation…`

### Trigger
The user moves the pointer to the menu bar near the Apple menu, opens File, and selects an export command.

### App interpretation
Use the currently active conversation or person archive as the export context.

### UI behavior
Present a native macOS sheet or panel asking:
- what scope to export
- how much history to export
- which format to use
- what content to include
- where to save it

### Export option examples
Scope:
- Entire conversation
- Current loaded range
- Custom date range
- From first message to selected message
- From selected message to latest

Format:
- PDF
- JSON
- DOCX

Include:
- messages
- photos
- links
- attachments
- reactions
- timestamps
- participants

### Outcome
The app exports using a native save/export flow and confirms completion clearly.

---

## 5H.2 Export from toolbar button

### User intent
The user wants quick access to export from the current transcript.

### Entry point
Toolbar export button.

### Behavior
Equivalent to export menu action, scoped to current archive.

---

## 5H.3 Export from inspector

### User intent
The user wants to export a specific content type.

### Entry point
Inspector export section.

### Possible actions
- Export Photos
- Export Links
- Export Attachments
- Export Conversation

### App behavior
Use the current archive as scope and prefill the export configuration accordingly.

---

## 5H.4 Export shared content as grouped outputs

### User intent
The user wants to save all photos, all links, or all attachments separately.

### App behavior
The app may produce:
- separate folders
- separate zip files
- structured JSON manifests for links
- companion metadata if enabled

### Outcome
Export output should be obvious and human-readable.

---

## 5H.5 Export current historical subset

### User intent
The user does not want the entire conversation, only a relevant historical period.

### Trigger
User chooses export while viewing a specific historical timeframe.

### App behavior
The export sheet should allow the user to specify:
- entire archive
- active visible range
- current loaded segment
- date range
- selected messages only if supported

### Notes
This is especially useful for immigration/legal/evidence workflows.

---

# 5I. Contacts and Merge Suggestions

## 5I.1 App detects likely same-person threads

### User intent
The user may benefit from grouped history across multiple handles.

### Trigger
The app identifies a likely merge based on Contacts or strong identity matching.

### UI outcome
Show subtle prompt in inspector or header:

**These conversations may belong to the same contact.**

### Actions
- View Merged
- Keep Separate
- Always Merge for This Contact

---

## 5I.2 User chooses View Merged

### App behavior
- resolve linked handles
- construct merged chronological archive
- preserve raw thread provenance per message

### UI outcome
- transcript updates to merged archive
- inspector shows linked identity status
- sidebar may switch to People mode or remain stable depending on design

---

## 5I.3 User chooses Keep Separate

### App behavior
- suppress immediate merge for this context
- preserve raw thread view

---

## 5I.4 User chooses Always Merge for This Contact

### App behavior
Persist merge preference for that contact identity.

---

# 5J. Selection, Hover, Focus, and Context Menus

## 5J.1 Selection model
Selections should be distinct for:
- active sidebar item
- active transcript message if one is focused
- active inspector item/section
- active timeline target

These should not conflict visually.

## 5J.2 Hover behavior
Hover should reveal optional affordances gently, not flood the UI.

Hover may affect:
- timeline
- message bubbles
- reply previews
- attachments
- export controls

## 5J.3 Focus behavior
Keyboard focus order should be coherent:
1. sidebar/search
2. conversation list
3. transcript
4. timeline
5. inspector
6. export/dialog actions

---

# 5K. Restoration and Session Continuity

## 5K.1 Reopen app and restore prior session

### User intent
The user wants to continue where they left off.

### App behavior
Restore where feasible:
- sidebar mode
- selected conversation/person
- transcript anchor
- inspector visibility
- last search query if appropriate

### Important rule
Do not restore into a broken or confusing half-state.
If restoration fails, fall back gracefully to recent conversation view.

---

## 5K.2 Recover from missing or unavailable content

### User intent
The user expects honesty and stability if archive content is incomplete.

### App behavior
If media or content is missing:
- indicate that clearly
- preserve surrounding transcript
- offer alternative actions if possible
- do not fail silently

---

# 6. Accessibility Interaction Requirements

For every interaction, also define:

- What does click do?
- What does double-click do?
- What does right-click do?
- What does keyboard do?
- What does VoiceOver say?
- What happens in dark mode?
- What happens at larger text sizes?

If these are not defined, the interaction is not complete.

## 6.1 Keyboard examples
Users should be able to:
- navigate sidebar items
- open the selected conversation
- jump to date
- switch between People and Threads
- move to the timeline
- activate export
- open attachments
- return from reply jumps where applicable

## 6.2 VoiceOver examples
- “Conversation with Alex Johnson, last active Sunday”
- “Matched search result in conversation with Alex Johnson, June 2021”
- “Outgoing message, 7:42 PM, ‘See you soon’”
- “Photo attachment, sent March 14 2021”
- “Jump to June 2021”
- “Export conversation, current scope: entire archive”

---

# 7. Recommended SwiftUI / Swift Architecture Mapping

This is not a mandated architecture, but a practical mapping idea.

## Likely UI structures
- `NavigationSplitView` for sidebar / transcript / inspector
- `List` or custom lazy list for sidebar conversation rows
- scrollable transcript surface with anchored loading
- inspector as native detail panel or split-column inspector
- `.searchable(...)` for search field(s)
- `.contextMenu(...)` for transcript items and rows
- `.fileExporter(...)` or native save/export panel integration for export
- menu commands for File/View/Navigate actions

## Likely implementation concepts
- observable `AppModel` or feature stores
- selected entity IDs and transcript anchors as first-class state
- async loading tasks for transcript windows
- stable message IDs for scroll anchoring and reply jumps
- search result types that carry archive context
- export descriptors that carry scope + format + inclusion options

---

# 8. Interaction Inventory to Build Next

The app likely has hundreds of interactions.
That is normal.

The goal is not to write all of them at once, but to formalize the most important ones first.

## Start with these groups
1. sidebar selection + restoration
2. transcript loading + historical scrolling
3. search result jump-in-context
4. timeline jumps
5. reply jumps + return
6. shared media browsing + show in timeline
7. export flows
8. merge suggestion flows
9. keyboard and accessibility behaviors
10. session restore + missing-content states

---

# 9. Recommended Next Artifact

After this document, the next useful artifact would be:

## `iRemember_interaction_inventory_v2.md`

Containing:
- all primary screens
- each interactive element on each screen
- trigger / state / outcome table
- keyboard behavior
- accessibility labels
- context menu definitions
- error and empty-state behavior

That would become the behavioral source of truth for implementation.

---

# 10. One-Sentence Summary

**This document defines the behavioral contract of iRemember: when a user performs an action, the app should interpret the user’s intent, load only the necessary historical context, preserve continuity, and present archive data in a calm, native, Mac-like way.**
