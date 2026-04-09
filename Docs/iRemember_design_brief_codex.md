# iRemember UI + Product Refactor Brief (Codex-Ready)

## Purpose

This document captures the current product and design direction for **iRemember** based on the discussion history in this chat.

It is intended to be:
- immediately readable by a coding agent
- specific enough to guide implementation
- opinionated about UX, information hierarchy, and accessibility
- grounded in a **Messages-inspired**, **Mac-native**, **archive-first** product vision

---

# 1. Product Vision

**Refactor iRemember into a Messages-inspired Mac archive app that feels immediately native, minimizes cognitive load, and adds only the capabilities users genuinely need beyond Apple’s app: time-based navigation, clean export, and person-level conversation merging.**


##1.1. Problem statement
Apple Messages is good for current communication, but poor for archival retrieval. Users who need to recover conversation history from a specific period often face slow scrolling, lost position when switching chats, weak date-based navigation, and search that depends on guessing message contents rather than navigating time directly. iRemember solves that by making long-range message history fast to browse, stable to navigate, easy to export, and faithful to the original conversation context.
A user needs to retrieve messages, attachments, and shared content from a specific historical period — for immigration, legal, personal, or record-keeping purposes — without losing their place, guessing search terms, or manually reconstructing context from scattered results.

## Core promise

Open your message history in a place that feels like Messages, but is better for:
- remembering
- navigating time
- exporting
- merging fragmented identities
- browsing shared content safely

## Non-goals

Do **not** turn iRemember into:
- a forensic utility
- a generic database browser
- a settings-heavy power-user app
- a dashboard with analytics-first UI
- a visually clever but cognitively expensive product

---

# 2. Core Design Brief

## Design principle 1: familiarity over novelty

The app should feel instantly understandable to anyone who has used Messages on Mac.

### Use
- standard window chrome
- sidebar + transcript + inspector
- native toolbar restraint
- familiar row selection
- familiar message bubble rhythm
- familiar shared content inspector structure

### Do not invent
- custom navigation metaphors everywhere
- oversized controls
- dashboard-style analytics homepages
- “clever” layouts that break Mac expectations

---

## Design principle 2: archive features must feel like natural extensions

New features should feel like they belong inside Messages.

### That means
- time scrubber should feel like a native index control
- export should live in inspector, toolbar, and File menu
- merged identities should feel like a contact enhancement
- media/link/file export should feel like an obvious batch action

---

## Design principle 3: keep the transcript sacred

The message transcript is the emotional center of the app.

### Therefore
- do not crowd it
- do not turn it into a data visualization surface
- do not keep too many controls inside it
- keep overlays subtle
- keep jumps and scrubbing smooth and quiet

---

## Design principle 4: people first, handles second

Users think in people, not raw identifiers.

### The app should support
- thread view
- person view
- suggested merges using Contacts
- optional manual overrides

---

## Design principle 5: export must be simple for non-technical users

A user should be able to export without learning formats.

### UI should translate technical outputs into human actions
- Export Conversation as PDF
- Export Full Archive as JSON
- Export All Photos
- Export All Links
- Export All Attachments

---

# 3. Proposed App Structure

## Main window

A true three-pane layout.

```text
┌──────────────┬──────────────────────────────────────────────┬─────────────────────┐
│ Sidebar      │ Transcript                                   │ Inspector           │
│              │                                              │                     │
│ Search       │ Header                                       │ Person              │
│ Pinned       │ Messages                                     │ Photos              │
│ Conversations│ Day separators                               │ Links               │
│ People/Threads│ Attachments inline                          │ Attachments         │
│              │ Right-edge time scrubber                     │ Export              │
└──────────────┴──────────────────────────────────────────────┴─────────────────────┘
```

This is the correct foundation.

---

# 4. Detailed UI Brief

## 4.1 Sidebar

Make it feel almost exactly as calm as Messages.

### Structure
At top:
- search field

Then:
- optional pinned section
- optional **People / Threads** segmented toggle
- conversation list

### Row design
Each row should contain:
- avatar
- primary name
- one-line snippet
- date on the right
- maybe an unread dot or subtle archive badge

### Important rule
Do not overload rows with metadata.

### Avoid in rows
- multiple badges
- handle strings
- export icons
- stats

### Sidebar row job
**Help me find the conversation I want.**

---

## 4.2 Transcript header

The header should be very minimal.

### Center or upper-center
- avatar
- name
- subtle subtitle if needed

### Right side
- details toggle
- maybe export button
- maybe jump-to-date

### Avoid
- counts
- technical identifiers
- lots of archive metadata

Keep that in the inspector.

### Header wireframe

```text
┌──────────────────────────────────────────────────────────────────┐
│                         [avatar]                                 │
│                        Alex Johnson                              │
│                  iMessage • 2014–2026                            │
│                                                [Export] [Info]   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4.3 Transcript body

This should be the closest Messages-inspired area.

### Keep
- left/right bubbles
- day separators
- image/file blocks inline
- reactions under or near messages
- reply context above relevant bubble
- generous padding
- wide whitespace

### Add carefully
- subtle “jumped to June 2019” marker
- right-edge year/month scrubber
- archive loading states

### Do not add
- visible technical database metadata
- noisy timeline charts in the main reading flow
- persistent export actions between messages

---

# 5. Timeline Rethink

## Primary direction

Do **not** make the main timeline a chart first.

The better instinct is a vertical A–Z-style time index.

Charts feel analytical.
The app should feel mnemonic.

## Primary timeline control

A **right-edge vertical year index** that expands into months during hover or drag.

### Example resting state

```text
2026
2025
2024
2023
2022
2021
2020
2019
2018
```

### Example interaction with 2021

```text
2026
2025
2024
2023
2022
2021
  Jan
  Feb
  Mar
  Apr
  ...
2020
2019
```

### Floating label example
- June 2021
- 1,248 messages
- Jumping…

This should feel more like Mac navigation and less like business analytics.

## Optional secondary timeline

A chart may still exist, but only behind:
- a Timeline View
- an inspector panel section
- an optional overview mode

Not as the main navigation affordance.

---

# 6. Inspector Design

The inspector should use stacked rounded cards, conceptually similar to Messages.

## Recommended section order

### Person
- avatar
- display name
- linked handles
- merge status

### Shared
- Photos
- Links
- Attachments

### Export
- Export Photos
- Export Links
- Export Attachments
- Export Conversation

### Archive
- first message date
- last message date
- message count
- participants

### Identity merge
Only when relevant:
- “These two threads may belong to the same person”
- Merge as one person
- Keep separate

## Suggested inspector wireframe

```text
┌──────────────────────────────┐
│ Alex Johnson                 │
│ 2 identifiers linked         │
├──────────────────────────────┤
│ Shared                       │
│ Photos (248)                 │
│ Links (53)                   │
│ Attachments (91)             │
├──────────────────────────────┤
│ Export                       │
│ [Export Photos]              │
│ [Export Links]               │
│ [Export Attachments]         │
│ [Export Conversation]        │
├──────────────────────────────┤
│ Archive                      │
│ First message: 2014          │
│ Last message: 2026           │
│ Messages: 18,420             │
├──────────────────────────────┤
│ Merge Identity               │
│ Alex mobile                  │
│ Alex email                   │
│ [Merge as One Person]        │
└──────────────────────────────┘
```

---

# 7. Export UX

Export should be dead simple.

## Entry points
- File > Export…
- toolbar export button
- inspector export section
- right-click on conversation/person

## Export Conversation sheet

```text
Export Conversation

Format
(o) PDF
( ) JSON
( ) DOCX

Include
[x] Messages
[x] Photos
[x] Links
[x] Attachments
[x] Reactions
[x] Timestamps

Destination
[Choose Folder]

[Cancel]                [Export]
```

## Export Shared Content sheet

```text
Export Shared Content

[x] Photos → Photos.zip
[x] Links → Links.json
[x] Attachments → Attachments.zip

[Cancel]                [Export]
```

## Export principles
- no jargon
- no schema language
- no advanced toggles unless behind a disclosure triangle
- human-readable defaults
- predictable output names and folders

---

# 8. Conversation Merging

This is a key product differentiator.

## Goal

Treat fragmented identifiers as a contact-resolution problem, not a raw database problem.

## Recommended behavior

If the app detects likely same-person threads:
show a subtle prompt in inspector or header:

**These conversations may belong to the same contact.**

### Actions
- View Merged
- Keep Separate
- Always Merge for This Contact

## Viewing modes

At the top of the sidebar:
- People
- Threads

That one toggle is enough.

### Threads
Raw source fidelity

### People
Human-meaningful archive view

---

# 9. Menu Structure

Keep menus simple and Mac-like.

## File
- Export Conversation…
- Export Shared Content…
- Export Full Archive…
- Close Window

## View
- Show Sidebar
- Show Details
- Show Time Index
- View by People
- View by Threads

## Navigate
- Jump to Date…
- Next Conversation
- Previous Conversation
- Jump to First Message
- Jump to Latest Message

## Help
- About iRemember
- Privacy & Permissions

---

# 10. Refactor Priorities

## Phase 1
Make the window structure feel like Messages:
- left sidebar
- center transcript
- right inspector
- minimal toolbar
- calm hierarchy

## Phase 2
Replace chart-led navigation with a vertical year/month time index.

## Phase 3
Build the inspector properly:
- shared content
- export actions
- archive summary
- merge suggestions

## Phase 4
Build export flows:
- PDF
- JSON
- DOCX
- media/link/file bulk export

## Phase 5
Add Contacts-powered merged identity view.

---

# 11. Main Wireframe

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●      iRemember                                           [Search]      [Export] [i]   │
├───────────────┬──────────────────────────────────────────────────────────────┬───────────────┤
│ Sidebar       │ Transcript                                                   │ Inspector     │
│               │                                                              │               │
│ Search        │                         [avatar]                              │ [avatar]      │
│               │                       Alex Johnson                            │ Alex Johnson  │
│ People Threads│                  iMessage • 2014–2026                        │ 2 handles     │
│               │                                                              │ linked        │
│ Pinned        │  ── Today ───────────────────────────────────────────         │               │
│ Alex          │                                                              │ Shared        │
│ Mum           │                          [bubble]                            │ Photos 248    │
│               │                                                              │ Links 53      │
│ All Chats     │                 [photo attachment inline]                    │ Files 91      │
│ Alex          │                                                              │               │
│ Work          │                          [bubble]                            │ Export        │
│ School        │                                                              │ [Photos]      │
│ …             │                                                              │ [Links]       │
│               │                                                              │ [Files]       │
│               │                                                              │ [Conversation]│
│               │                                                          2026│               │
│               │                                                          2025│ Archive       │
│               │                                                          2024│ First: 2014   │
│               │                                                          2023│ Last: 2026    │
│               │                                                          2022│ 18,420 msgs   │
│               │                                                          2021│               │
│               │                                                          2020│ Merge         │
│               │                                                          2019│ [Merge]       │
├───────────────┴──────────────────────────────────────────────────────────────┴───────────────┤
│ Optional bottom bar: jump state / loading older messages / archive notices                   │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

# 12. Design System Direction

The app should be specified as a **small design system**, not a collection of random pixel notes.

## Define in order
1. design principles
2. layout rules
3. design tokens
4. component specs
5. interaction states
6. motion behavior
7. content rules

## Do not start with
- blue bubble is 17 px radius with 6 px blur
- hover magnification is 1.12x
- sidebar row is 58 px

## Start with
- what the screen helps the user do
- what is primary vs secondary
- what should feel like Messages
- what should feel uniquely archival

---

# 13. Design Tokens

These are global constants for implementation.

## Categories to define
- spacing scale
- corner radius scale
- typography styles
- color roles
- shadows/material usage
- animation timings
- icon sizes
- hit target minimums

## Example token scaffolding

```swift
enum IRSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

enum IRRadius {
    static let bubble: CGFloat = 18
    static let card: CGFloat = 14
    static let panel: CGFloat = 18
    static let pill: CGFloat = 999
}

enum IRMotion {
    static let quick: Double = 0.16
    static let standard: Double = 0.22
    static let gentle: Double = 0.30
}
```

---

# 14. Window Layout Spec

Define the shell before the atoms.

## Initial layout guidance
- sidebar minimum width: 280
- transcript width: flexible
- transcript should preserve readable line lengths
- inspector width: 300–340
- toolbar height: native default
- transcript header height: fixed or bounded range
- bottom composer hidden in archive mode, or replaced with status strip

This matters more than bubble pixel perfection at first.

---

# 15. Core Components to Define

The first canonical components should be:

- `ConversationRowView`
- `TranscriptHeaderView`
- `MessageBubbleView`
- `DateSeparatorView`
- `ReplyPreviewView`
- `AttachmentTileView`
- `InspectorSectionCard`
- `ExportActionButton`
- `TimelineRailView`
- `TimelineBadgeView`
- `MergedIdentityBanner`

Each should have:
- purpose
- anatomy
- size rules
- states
- behavior
- content rules
- accessibility behavior

---

# 16. Message Bubble Spec

## Purpose
Present a single message clearly, with emotional familiarity close to Messages.

## Variants
- incoming text
- outgoing text
- incoming media
- outgoing media
- grouped top
- grouped middle
- grouped bottom
- standalone
- selected/highlighted for jump target

## Shape
- rounded rect with subtle asymmetry if grouped
- no over-styled glassmorphism
- outgoing bubble more saturated
- incoming bubble neutral and soft

## Suggested visual rules
- max text width: ~420–520 depending on window size
- internal padding: 10–12 horizontal, 7–9 vertical
- corner radius: 16–18
- vertical gap between same-speaker grouped bubbles: 2–4
- gap between speaker groups: 8–12

## Color roles
- outgoing: accent green or stable app-defined outgoing tint
- incoming: tertiary neutral fill
- text: always high contrast

## Behavior
- no hover chrome by default
- on hover: reveal subtle affordances only if needed
- on jump-to-date target: soft highlight pulse, then settle

## Motion
- scroll into view: no bounce
- highlight on navigation: fade in ~120 ms, out ~500–700 ms

---

# 17. Timeline Rail Spec

## Purpose
Allow rapid navigation by year and month with minimal cognitive load.

## Placement
- right edge of transcript pane
- visually secondary until hovered
- always accessible, never dominant

## Resting state
- slim vertical rail
- years visible as light labels
- low contrast
- no heavy track

## Hover state
- rail gains contrast
- hovered year slightly magnifies
- neighboring years subtly spread apart
- floating badge appears with selected year/month

## Drag state
- months appear nested under active year
- transcript scrubs smoothly, not 1:1 per pixel
- date badge follows cursor
- active target gains stronger emphasis

## Suggested visual behavior
- resting width: 28–36
- hover effective width: 60–80
- hovered label scale: 1.08–1.14
- adjacent labels shift by 2–6 px
- month children indented under active year
- floating badge should feel like a native scrub overlay, not a tooltip

## Motion
- hover enter: 140–180 ms
- magnification: springless or very low-bounce smooth animation
- month reveal: opacity + slight horizontal offset
- release: transcript snaps softly to nearest month anchor

## Important rule
It should feel like **browsing memory**, not a stock chart or editing timeline.

---

# 18. Inspector Card Spec

## Purpose
Chunk metadata and actions into calm, readable groups.

## Visual style
- rounded rectangular card
- light grouped background
- no harsh borders
- title small and muted
- content comfortably padded

## Structure
- section title
- primary content
- optional actions
- optional disclosure

## Spacing
- card internal padding: 14–16
- gap between cards: 12
- section titles quieter than body text

## Rule
One card = one mental job.

### Examples
- photos
- links
- attachments
- export
- archive summary
- merge identity

Do not mix jobs in one card.

---

# 19. Accessibility and Interaction Contract

These requirements belong in the spec from day one.

---

## 19.1 Text size and typography behavior

Every core view should be tested at:
- default size
- 1–2 steps larger
- maximum comfortable desktop scaling

### Rules
- sidebar rows get taller rather than clipping
- inspector cards expand vertically
- message bubbles wrap earlier, not truncate meaningful content
- date separators and metadata remain readable but secondary
- timeline labels simplify when space gets tight

### Truncation/wrapping rules
- conversation names: may tail-truncate
- snippets: may truncate
- export button labels: should remain fully readable
- message text: should never truncate in transcript

---

## 19.2 Contrast

Use semantic colors, not hardcoded pretty colors.

### Token categories
- background
- secondary background
- bubble incoming fill
- bubble outgoing fill
- primary text
- secondary text
- selected row fill
- separator
- accent action
- warning
- success

Define them for:
- light mode
- dark mode
- increased contrast mode

### Rules
- contrast must survive selection, hover, vibrancy, and translucency
- no text on low-contrast tinted fills unless verified
- inspector cards must remain readable in both appearances
- timeline labels must stay legible in inactive and hover states
- selection should never be color-only

---

## 19.3 Dark mode

Dark mode should not simply invert the UI.

### Desired qualities
- softer surfaces
- restrained contrast
- readable bubbles
- low-glare backgrounds
- clear focus states

### Define separately
- transcript background
- sidebar background
- inspector grouped cards
- incoming bubble dark appearance
- outgoing bubble dark appearance
- date separator treatment
- hover/selection states

### Media-specific rules
- thumbnails should not disappear into the background
- file cards need borders or subtle depth
- export buttons should remain obviously clickable

---

## 19.4 Accent color

The app should respect the system accent where practical, but not become accent-led.

### Best approach
- use system accent for interactive emphasis
- do not let accent determine message bubble identity if it hurts familiarity
- keep archive/navigation chrome mostly neutral
- outgoing bubbles may use a stable app-defined conversational color
- use accent more for selection, buttons, focus rings, toggles, and timeline highlights

---

## 19.5 Interaction accessibility

### Keyboard support
Users should be able to:
- move through sidebar conversations
- open/close inspector
- jump to date
- switch between People and Threads
- activate Export
- move between messages where relevant
- open attachments
- reveal original position in timeline

### VoiceOver examples
- “Conversation with Alex Johnson, last active Sunday”
- “Outgoing message, 7:42 PM, ‘See you soon’”
- “Photo attachment, sent March 14 2021”
- “Jump to June 2021”
- “Merged conversation suggestion for Alex mobile and Alex email”

### Hit targets
Interactive areas must be generous, especially for:
- tiny timeline labels
- reaction chips
- inline reply links
- attachment thumbnails
- inspector actions

---

# 20. Inline Replies

Inline replies should be a first-class archive navigation tool.

## Reply preview content
Each reply block should show:
- sender if needed
- short quoted text or media label
- subtle visual link to original message

## On click
Default behavior:
- jump to the original message in transcript
- briefly highlight the target
- optionally show a small “Back to previous position” affordance

## On hover
Can show:
- Jump to original
- timestamp preview
- maybe Open in context

## On right click
Potential options:
- Go to Original Message
- Open in Timeline
- Copy Reply Text
- Export This Thread Segment

---

# 21. Media and Attachment Context Menus

These must feel Mac-native.

## Media in transcript
Right-click options:
- Open
- Quick Look
- Show in Timeline
- Reveal in Shared Media
- Export…
- Copy
- Save As…
- Show Message Details

## Show in Timeline behavior
- jump transcript to the message’s date position
- optionally activate the timeline rail / date badge
- show the message in surrounding context, not isolated

## Links
Right-click options:
- Open Link
- Copy Link
- Show in Conversation
- Show in Timeline
- Export Links from This Conversation

## Attachments
Right-click options:
- Open Attachment
- Quick Look
- Export Attachment
- Reveal in Conversation
- Show in Timeline

---

# 22. Content Behavior Rules

Add explicit rules for:
- truncation
- wrapping
- empty states
- loading states
- corrupted or missing content
- inaccessible file states

## Trust rule
If archived media is missing, say so clearly and gently.
Do not fail silently.

---

# 23. Practical Product Rule

For every interactive element, define:

- What does click do?
- What does double-click do?
- What does right-click do?
- What does keyboard do?
- What does VoiceOver say?
- What happens in dark mode?
- What happens at large text sizes?

If these are undefined, the component is not fully designed.

---

# 24. Recommended Artifact Sequence

The next artifact should be:

## iRemember UI Specification v1

Include:
- design principles
- tokens
- window layout
- 10 core components
- 3 key flows
- motion rules
- accessibility and interaction contract

## Suggested implementation sequence
1. write design rules
2. define tokens
3. define 8–12 core components
4. define 3 critical screens in detail
5. implement as canonical reusable SwiftUI views

---

# 25. One-Sentence Summary

**The strongest move is not to “design more,” but to edit ruthlessly until iRemember feels as inevitable, calm, and native as Messages—while adding only the archive features Apple did not build: time navigation, clean export, and person-level conversation merging.**
