# Codex Prompt: Integrate Real Apple Messages Data Into iRemember

You are working on the macOS SwiftUI app `iRemember for Messages` in:

- `/Users/monty/Documents/iRemember/iRemember`

The Xcode project is:

- `/Users/monty/Documents/iRemember/iRemember/iRemember.xcodeproj`

The app target source is:

- `/Users/monty/Documents/iRemember/iRemember/iRemember`

## Goal

Replace the current sample-only data source with a real, read-only Apple Messages ingestion pipeline using:

- `~/Library/Messages/chat.db`
- `~/Library/Messages/Attachments`

Preserve the product’s core qualities:

- native macOS feel
- SwiftUI-first architecture
- read-only behavior
- bounded memory usage
- calm, precise interaction design
- no full-thread eager loading
- local-only processing by default

## Current app state

The app already has:

- a real Xcode macOS app target
- `MessagesSource` protocol in `/Users/monty/Documents/iRemember/iRemember/iRemember/Core/Services.swift`
- `AppModel` wired through the UI shell
- timeline, transcript, media browser, inspector, onboarding, settings, and tests
- compact, horizontally scrollable timeline surfaces
- pane minimisation controls for sidebar, inspector, and timeline
- duplicate center conversation header removed

The app currently still uses `SampleMessagesSource`.

## Architecture decision

Use direct read-only access to the Mac’s local Messages store as the primary source strategy.

Do not make Finder/iTunes backups or iMazing exports the primary first-run path.

Backups are fallback/import modes for later, useful when:

- local Mac history is incomplete
- the user wants a frozen evidentiary snapshot
- the data exists only in an iPhone backup
- direct local access fails

## Research conclusions already established

1. `chat.db` is the correct primary source on macOS.

2. `message.text` alone is not reliable.
Visible content may be in:

- `message.text`
- `message.attributedBody`
- both

3. `chat.db` may not always be a perfect mirror of user expectations.
Some users report missing history on Mac despite seeing more in Messages, likely due to sync state, local availability, WAL state, or iCloud behavior.

4. Attachments must be resolved separately.
Do not fully load originals into memory. Build metadata first, then preview/original loading lazily.

5. Full Disk Access is a real prerequisite.
Even local shell access to `chat.db` may fail with `authorization denied` unless the host app/tool has TCC permission.

## References already reviewed

- Apple SwiftUI Mac guidance:
  [Building a Great Mac App with SwiftUI](https://developer.apple.com/documentation/swiftui/building-a-great-mac-app-with-swiftui)
- Apple HIG and dark mode guidance:
  use familiar pane behavior, semantic colors, standard macOS interaction patterns
- Feifan Zhou article:
  [Viewing iMessage History on a Computer](https://feifan.blog/posts/viewing-imessage-history-on-a-computer)
- Feifan Zhou reference repo:
  [messages-browser](https://github.com/feifanzhou/messages-browser)
- Atomic Object:
  [Searching Your iMessage Database (Chat.db file) with SQL](https://spin.atomicobject.com/search-imessage-sql/)
- User-provided evidence about missing chat history:
  [Reddit thread](https://www.reddit.com/r/osx/comments/uevy32/texts_are_missing_from_mac_chatdb_file_despite/)
  and Apple Community discussion on missing Mac history

## Prerequisites

### User and environment prerequisites

The user explicitly accepts these requirements.

1. Full Disk Access must be manually granted in macOS for:

- Codex
- Terminal
- Xcode
- the built app at `/Users/monty/Documents/iRemember/Build/Products/Debug/iRemember.app`

If the app is run from Xcode, Xcode itself must have Full Disk Access.

If `sqlite3` or shell tools are used, Terminal or Codex must also have Full Disk Access.

This cannot be granted programmatically. macOS TCC requires the user to approve it manually in:

- System Settings
- Privacy & Security
- Full Disk Access

2. The Messages files must exist locally:

- `~/Library/Messages/chat.db`
- `~/Library/Messages/Attachments`

3. The app should remain unsandboxed for development.
This has already been changed in:

- `/Users/monty/Documents/iRemember/iRemember/iRemember.xcodeproj/project.pbxproj`

Specifically:

- `ENABLE_APP_SANDBOX = NO`

Do not turn sandboxing back on during this direct-source integration pass.

4. SQLite access is required.
Use Apple’s system SQLite or the system `sqlite3` tooling as needed.

5. Expect related SQLite live files:

- `chat.db-wal`
- `chat.db-shm`

The reader must tolerate live database conditions.

### Optional but useful development tools

- `sqlite3`
- DB Browser for SQLite
- Instruments for memory verification

## What must be implemented

### Phase 1: Real source layer

Create a real source implementation such as:

- `SQLiteMessagesSource`
- `MessagesDatabase`
- `MessagesSchema`
- `AttachmentResolver`

Responsibilities:

- verify source paths
- open the database read-only
- load conversations
- load a selected conversation
- normalize raw data into existing app-facing models

Do not bind the UI directly to raw SQLite rows.

### Phase 2: Conversation and message ingestion

Support:

- conversation list
- snippets
- participant resolution
- chat/message joins
- sender resolution via handle joins
- correct chronological ordering
- timestamp conversion from Apple epoch-based storage

Preserve the existing transcript windowing behavior.

Do not load entire large threads eagerly.

### Phase 3: Message content extraction

Support:

- `message.text`
- `message.attributedBody` fallback when `text` is missing
- graceful handling of missing/unknown body formats

If `attributedBody` decoding is partial at first, still implement a structured fallback path and avoid silently dropping messages.

### Phase 4: Attachments and media

Support:

- attachment joins
- image/video/file/link typing
- message-to-attachment relationships
- file existence checks
- media asset generation for current UI
- missing or offloaded attachment handling

Do not load full-size media into memory unless explicitly requested.

### Phase 5: Permission and failure UX

Update onboarding and failure flows to explain:

- why Messages access is needed
- that the app is read-only
- exactly which folders/files are read
- that Full Disk Access is required
- how to recover from denial

Do not pretend permission can be auto-approved.

### Phase 6: Verification

Add tests for:

- timestamp conversion
- conversation joins
- missing `text` with present `attributedBody`
- absent attachment files
- permission/source-path failures

Run:

- `./Scripts/build-xcode-app.sh`
- `xcodebuild test -project /Users/monty/Documents/iRemember/iRemember/iRemember.xcodeproj -scheme iRemember -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

If UI tests fail due to environment or runner permissions, say so explicitly and separate app-code success from environment limitations.

## UX rules that must remain true

- If a surface looks interactive, it must be interactive
- Timeline stays compact by default
- Timeline and day scrubber remain horizontally scrollable on macOS
- Sidebar, inspector, and timeline remain minimisable
- Center pane should prioritize task surfaces, not duplicate metadata
- Important actions should exist in toolbar and command/menu access where appropriate
- Use semantic macOS colors/materials instead of custom hard-coded chrome

## Constraints

1. Read-only only.
Do not mutate `chat.db`, attachments, or source records.

2. No App Store compatibility in this pass.
Direct protected-folder access is the priority.

3. Do not rely on backup import as the main path.

4. Do not revert unrelated workspace changes.

5. Do not stop at research only.
Implement as much of the real integration as possible.

## Non-goals for this pass

- sending or editing messages
- iCloud API integration
- App Store sandbox distribution
- full evidence export packages
- iPhone/iPad app UI
- iMazing-first architecture

## Expected output

Complete the real Messages ingestion integration as far as possible in one pass, then summarize:

- what was implemented
- what still depends on manual Full Disk Access
- what remains for backup import fallback
- any schema gaps still unresolved, especially around `attributedBody`
