# iRemember for Messages

iRemember is a native macOS archive browser for Apple Messages. It opens your local Messages history in a read-only workspace designed for browsing long conversations, finding specific moments, reviewing shared media, and exporting clean archives without modifying the source data.

The app supports two operating modes:

- `Local Messages Library`: read-only access to the Messages database and attachments already stored on your Mac
- `Sample Library`: bundled sample data for development, demos, and UI work when live data is unavailable

## Table of Contents

- [Overview](#overview)
- [What the App Does](#what-the-app-does)
- [Privacy and Permissions](#privacy-and-permissions)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Using the App](#using-the-app)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Exports](#exports)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Development](#development)
- [Snapshot Export Automation](#snapshot-export-automation)
- [Known Limits](#known-limits)

## Overview

iRemember is built for people who need more control than the Messages app gives them when they are reviewing personal history, research material, family records, project threads, receipts, attachments, or long-running message archives.

The interface is a three-pane macOS workspace:

- a sidebar for conversations, contacts, and search results
- a main content area for message transcripts or shared media
- an inspector for archive details, selected messages, media details, and export actions

The app is optimized for archive browsing, not messaging. It does not send messages, edit your library, or mutate your Messages database.

## What the App Does

### Core browsing

- Opens the local Apple Messages archive in read-only mode
- Falls back to a bundled sample library when live access is unavailable
- Browses by individual conversation or by contact-merged archive
- Restores the previously open archive, transcript position, search text, and layout state

### Search

- Searches conversations, messages, media, links, and file attachments
- Returns typed search results with archive context and timestamps
- Lets you jump directly from a result into the matching transcript location
- Preserves a return path so you can jump back to where you were

### Transcript workspace

- Loads transcript windows lazily instead of rendering the entire archive at once
- Groups messages by day with pinned date headers
- Supports loading earlier and later message ranges on demand
- Highlights selected messages and tracks the visible message for timeline updates
- Supports reply-context jumps back to the original referenced message
- Shows reactions, reply previews, attachments, and grouped media blocks

### Timeline navigation

- Shows a dedicated timeline panel beside the transcript
- Jumps to specific dates, days, months, and years
- Supports previous-day and next-day navigation
- Preserves the previous reading position when you jump away

### Media browsing

- Switches from transcript view to a shared media browser
- Filters between all media, photos, and videos
- Opens media in a viewer and supports revealing an item back in the transcript
- Shows Finder reveal actions for locally available files

### Inspector

- Summarizes archive range, message count, media count, participant count, and conversation count
- Shows archive identities and linked handles
- Displays selected message details and selected media details
- Surfaces merge suggestions when related conversations appear to belong to the same person
- Provides export actions directly from the inspector

### Identity and merge behavior

- Can optionally use macOS Contacts to resolve better participant names
- Supports merged “contact archives” that group related conversations together
- Lets the user keep threads separate or always merge them for a contact

### Export

- Exports full conversations
- Exports only the currently loaded transcript window
- Exports custom date ranges
- Supports `PDF`, `JSON`, and `DOCX`
- Supports a “shared content” export preset focused on photos, links, and attachments

## Privacy and Permissions

iRemember is designed around a strict local-first, read-only model.

- Messages stay on your Mac
- The live archive opens in read-only mode
- The app reads `~/Library/Messages/chat.db` and `~/Library/Messages/Attachments`
- Nothing is uploaded, synced, or written back to the Messages store
- Contacts access is optional and used only for improving displayed names and archive grouping

When live mode is used, macOS Full Disk Access is required before the app can read the Messages database successfully.

## Requirements

- macOS `26.3` or later
- Xcode `26` or later for development
- A local Messages history on the same Mac for live browsing
- Full Disk Access for the app when opening the live Messages library
- Full Disk Access for Xcode as well when launching from Xcode during development

Optional:

- Contacts permission if you want contact-backed name resolution and better merged archive identity

## Getting Started

### Run the app

1. Open [iRemember.xcodeproj](iRemember.xcodeproj) in Xcode.
2. Select the `iRemember` scheme.
3. Build and run the app.

### First launch

You will see one of two entry points:

- `Open Messages Library`: attempts to open your local Apple Messages archive
- `Use Sample Library`: loads bundled data for testing and evaluation

If Full Disk Access has not been granted yet:

1. Open `System Settings > Privacy & Security > Full Disk Access`.
2. Enable access for iRemember.
3. If you launch from Xcode, enable Xcode too.
4. Relaunch the app and try again.

## Using the App

### 1. Choose a browsing mode

Use the sidebar mode controls or keyboard shortcuts to switch between:

- `Conversations`: browse each thread separately
- `Contacts`: browse merged contact-centric archives

### 2. Search the archive

Use the sidebar search field to search:

- conversations
- messages
- media
- links
- file attachments

Search results show the result type, title, subtitle, archive title, and timestamp where available.

### 3. Read the transcript

The transcript view is the main reading surface. It supports:

- lazy transcript loading
- day-section grouping
- attachment previews
- reply jumps
- message selection for inspector details

### 4. Use the timeline

When the timeline is visible, you can navigate large archives more efficiently by:

- jumping to a date
- moving day by day
- choosing broader month and year ranges
- returning to your previous position after a jump

### 5. Browse shared media

Switch the main content mode to `Shared Media` to review images and videos independent of the transcript. This is useful when the archive is media-heavy and you need a gallery-style workflow.

### 6. Review details in the inspector

The inspector summarizes:

- archive identity and archive type
- addresses linked to the current archive
- message and media counts
- selected message details
- selected media details
- export actions
- merge suggestions
- library access state

### 7. Export what you need

Exports can be launched from:

- the toolbar
- the `Archive` and `Navigate` menus
- sidebar row context menus
- the inspector

## Keyboard Shortcuts

The current app-level shortcuts are:

- `Command-Option-1`: Browse by conversation
- `Command-Option-2`: Browse by contact
- `Command-3`: Show messages
- `Command-4`: Show shared media
- `Command-J`: Jump to date
- `Command-E`: Export conversation
- `Command-Option-E`: Export loaded range
- `Command-Option-Left Arrow`: Previous day
- `Command-Option-Right Arrow`: Next day
- `Command-Option-T`: Show or hide timeline

## Exports

### Supported formats

- `PDF`
- `JSON`
- `DOCX`

### Supported scopes

- entire archive
- current loaded transcript range
- custom date range

### Export controls

The export sheet lets the user choose whether to include:

- messages
- photos
- links
- attachments
- reactions
- timestamps
- participants

## Architecture

The codebase is structured around a source abstraction rather than coupling the UI directly to SQLite or Messages internals.

### Source model

- `MessagesSource`: protocol boundary for any archive source
- `SQLiteMessagesSource`: live read-only Messages implementation
- `SampleMessagesSource`: bundled development and fallback data source

### App state

- `AppModel`: central observable application state and workflow coordinator
- `SwiftData` persistence: stores session state and merge decisions
- transcript windows and archive details are loaded lazily and cached

### Current strategy

The project currently implements:

- live read-only browsing of the Messages database
- sample-library fallback
- normalized app-facing models
- lazy transcript hydration
- archive/session persistence

For more detail, see [Docs/Architecture.md](Docs/Architecture.md).

## Project Structure

```text
iRemember/
├── iRemember.xcodeproj
├── iRemember/
│   ├── Core/
│   │   ├── Models.swift
│   │   ├── Persistence.swift
│   │   ├── Services.swift
│   │   └── SQLiteMessagesSource.swift
│   ├── Views/
│   │   ├── RootView.swift
│   │   ├── SidebarView.swift
│   │   ├── TranscriptView.swift
│   │   ├── MediaBrowserView.swift
│   │   ├── InspectorView.swift
│   │   ├── SettingsView.swift
│   │   └── OnboardingView.swift
│   ├── WorkspaceCommands.swift
│   ├── SnapshotExportController.swift
│   └── iRememberApp.swift
├── iRememberTests/
├── iRememberUITests/
└── Docs/
```

## Development

### Open the project

This repository is an Xcode project, not a Swift Package. Use Xcode to build and run it.

### Main contributor workflows

- use the sample library for UI work and layout iteration
- use the live Messages source when validating permissions and real-library behavior
- use the inspector and export surfaces to validate archive metadata and output paths

### Tests

The repository includes both unit tests and UI tests.

Example command:

```bash
xcodebuild test -project iRemember.xcodeproj -scheme iRemember -destination 'platform=macOS'
```

Note: macOS UI tests require the host machine to allow UI automation. If accessibility automation is not authorized, UI-test failures can be environmental rather than product regressions.

## Snapshot Export Automation

The app includes a built-in snapshot export path for generating workspace images during development.

Environment variables:

- `IREMEMBER_EXPORT_SNAPSHOTS=1`
- `IREMEMBER_SNAPSHOT_DIR=/path/to/output`
- `IREMEMBER_SNAPSHOT_SOURCE=sample` or `live`

When enabled, the app renders a set of PNG snapshots and then terminates automatically.

Current outputs:

- `01-transcript.png`
- `02-media.png`
- `03-media-no-inspector.png`
- `04-transcript-no-inspector.png`

## Known Limits

- The app is a browser and exporter, not a replacement for Messages
- Live browsing depends on local Messages files being present on the Mac
- Some attachment originals may be unavailable locally if Messages has offloaded them
- Contact identity improvements depend on optional Contacts permission
- The app currently targets modern macOS only

## License

No license file is currently included in this repository. Add one before public distribution if you intend to open-source or redistribute the project.
