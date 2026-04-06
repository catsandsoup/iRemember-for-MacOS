# iRemember for Messages

Release 1 foundation shell for a native-feeling macOS archive browser for Apple Messages.

## What is in this scaffold

- SwiftUI macOS app shell with a three-pane `NavigationSplitView`
- onboarding and privacy education surface
- read-only source abstraction with a seeded sample library
- conversation list, transcript shell, media browser, inspector, and settings
- bounded transcript windowing to avoid unbounded in-memory rendering
- architecture note documenting a recommended hybrid source strategy

## Run

```bash
swift run iRemember
```

Open the package in Xcode if you want to iterate as a standard macOS app project.

## Current scope

This scaffold focuses on Release 1 from the PRD:

- source-access abstraction
- normalized app-facing model
- conversation browsing
- transcript rendering shell
- media preview entry point
- privacy/settings flows

It does not yet implement live Messages database access, exact date jump, timeline buckets, or export jobs against real user data.
