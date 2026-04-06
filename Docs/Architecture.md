# iRemember Architecture Decision

## Chosen source strategy

Use a hybrid source strategy:

- live read-only perusal of Messages source data for truth and change detection
- lightweight local derived indexes for conversation summaries, time buckets, media metadata, and search acceleration
- lazy per-conversation hydration so the user can enter the app quickly without a blocking full-library import wall

## Why this fits the PRD

This approach best matches the product constraints:

- it preserves a read-only relationship with the source data
- it avoids forcing a painful full import before first use
- it supports sub-second thread switching and date jumps once local indexes warm
- it keeps bulk export and media browsing efficient without repeatedly hammering the source store
- it isolates the UI from source-schema volatility through a normalized app-facing model

## Operational shape

1. The source access layer discovers conversations and lightweight metadata first.
2. The app builds resumable local indexes for summaries, time buckets, and media records in SQLite.
3. Transcript windows are fetched lazily around the active viewport or jump target.
4. Original media is streamed on demand; thumbnails are cached with a bounded budget.
5. Change detection updates only the affected conversations and buckets.

## Why not full import only

A mandatory full import would slow first use, increase failure surface area, and create more trust friction during onboarding.

## Why not live-query only

Pure live querying is simpler initially, but it risks sluggish date navigation, repeated heavy scans for media workflows, and more exposure to source-schema quirks.

## Implementation note

The current codebase ships a sample source and a read-only protocol boundary. The next engineering step is to add a concrete Messages-backed source plus a SQLite-backed derived index behind the same abstraction.
