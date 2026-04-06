# UIKit Overhaul Notes For iRemember

Reviewed on April 5, 2026 against Apple’s public documentation.

This is not a recommendation to rebuild `iRemember` in UIKit. The app is a native macOS SwiftUI product. The right use of UIKit documentation here is:

- extract interaction standards and quality bars Apple expects
- map applicable concepts into SwiftUI and AppKit-friendly implementation
- avoid importing iPhone-first patterns that would make the Mac app feel wrong

## Primary references

- [UIKit documentation](https://developer.apple.com/documentation/uikit)
- [Supporting Dark Mode in your interface](https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface)
- [Choosing a specific interface style for your iOS app](https://developer.apple.com/documentation/uikit/choosing-a-specific-interface-style-for-your-ios-app)
- [Accessibility for UIKit](https://developer.apple.com/documentation/uikit/accessibility-for-uikit)
- [UIKeyCommand](https://developer.apple.com/documentation/uikit/uikeycommand)
- [UIFindInteraction](https://developer.apple.com/documentation/uikit/uifindinteraction)
- [UIActivityItemsConfigurationProviding](https://developer.apple.com/documentation/uikit/uiactivityitemsconfigurationproviding)
- [UIContextMenuInteraction](https://developer.apple.com/documentation/uikit/uicontextmenuinteraction)
- [Restoring your app’s state](https://developer.apple.com/documentation/uikit/restoring-your-app-s-state)
- [UITableView prefetchDataSource](https://developer.apple.com/documentation/uikit/uitableview/prefetchdatasource)
- [UITableViewDataSourcePrefetching](https://developer.apple.com/documentation/uikit/uitableviewdatasourceprefetching)
- [UICollectionViewDiffableDataSourceReference applySnapshot(_:animatingDifferences:)](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasourcereference/applysnapshot(_:animatingdifferences:))
- [UITableViewDiffableDataSource itemIdentifier(for:)](https://developer.apple.com/documentation/uikit/uitableviewdiffabledatasource-2euir/itemidentifier(for:))
- [UITextInputContext](https://developer.apple.com/documentation/uikit/uitextinputcontext)
- [Dark Interface evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria/)

## What UIKit can overhaul in this app

## 1. Dark mode discipline

The documentation and App Store accessibility criteria point to a stricter bar than “looks okay in dark mode.”

What this should change in `iRemember`:

- Keep all structural surfaces on semantic system materials and background colors first.
- Stop relying on decorative grays and tinted fills as the main visual system.
- Audit contrast in both regular dark mode and increased contrast.
- Avoid low-contrast gray-on-black metadata for high-stress workflows.
- Ensure selected states remain legible when accent color changes.
- Keep message/media previews vivid, but keep chrome subdued.

Practical rule:

- If a control is important while the user is under stress, it should read clearly at a glance without relying on subtle tonal differences.

## 2. Keyboard-command quality

UIKit’s `UIKeyCommand` documentation reinforces a broader Apple expectation: commands should be discoverable, localizable, and central to desktop-quality UX.

What this should change:

- Expand command coverage beyond date jump and mode switching.
- Add commands for previous/next result, previous/next day, open media browser, reveal in transcript, and focus search.
- Ensure menu titles are concrete and user-language-first.
- Preserve reachability and consistency of shortcuts across layouts.

This matters because the target users are often not casually browsing. They are trying to move with confidence and speed.

## 3. Built-in find behavior

UIKit’s `UIFindInteraction` docs underline something important: Apple treats “find” as a first-class interaction, not an ad hoc search box.

What this should change:

- The app should distinguish global conversation search from in-transcript find.
- Search should support iterative navigation: next match, previous match, and current match count.
- Matching should be visually obvious and not force context loss.
- Timeline navigation and text find should feel like separate but cooperating tools.

For this app:

- toolbar search = broad filter and search
- transcript find = move between textual hits in the loaded context
- date jump = time anchor

## 4. Context menus and preview quality

UIKit’s context-menu and targeted-preview docs reinforce that secondary actions should feel spatially tied to the item they belong to.

What this should change:

- Every message bubble should expose context actions.
- Every media tile should expose quick actions.
- Secondary actions should cluster around user intent:
- reveal in transcript
- copy text
- copy timestamp
- export selected
- reveal in Finder
- inspect metadata

The preview and menu should feel attached to the selected artifact, not like a detached command list.

## 5. Share/export representations

`UIActivityItemsConfigurationProviding` is a useful mental model even though the app is macOS-first. Apple’s guidance is to provide multiple representations of the same content.

What this should change:

- Exports should not be single-format only.
- A selected message or media item should be representable as:
- plain text
- rich context snippet
- original file URL when applicable
- metadata JSON or CSV row
- manifest-backed archive item

The export system should think in representations, not just files.

## 6. Accessibility as interaction architecture

UIKit accessibility docs are explicit that many controls are accessible by default, but custom structures need deliberate work.

What this should change:

- Custom timeline buckets need real accessibility labels and values.
- The timeline cannot be “visually rich but semantically empty.”
- The right inspector tabs need accessible groupings.
- Media grid selection states need more than color.
- High-stress workflows need rotor-style navigation equivalents:
- jump by day
- jump by message result
- jump by media item
- jump by attachment type

For SwiftUI:

- use identifiers, labels, values, actions, and sort priorities deliberately
- don’t assume Charts or custom-drawn regions are sufficient by default

## 7. State restoration and continuity

UIKit’s state restoration docs are directly relevant to this product even if the concrete API is different in SwiftUI/AppKit.

What this should change:

- Restore selected conversation
- restore transcript anchor
- restore selected inspector tab
- restore timeline range and height
- restore search query and scope
- restore media browser filters

For an archival product, continuity is not a luxury. It is part of trust.

## 8. Prefetching and viewport preparation

The `prefetchDataSource` and `UITableViewDataSourcePrefetching` docs reinforce Apple’s expectation that list-like UIs prepare nearby data before it is strictly needed.

What this should change:

- Prefetch earlier/later transcript windows before the user hits the hard edge.
- Prefetch nearby thumbnail metadata around the visible media region.
- Precompute timeline bucket summaries for adjacent ranges.
- Keep cancellation strict so prefetching never becomes runaway work.

This is especially important for large histories where “smoothness” is perceived as product quality.

## 9. Diffable thinking and identity stability

Diffable-data-source documentation is about more than UIKit collection views. It encodes a discipline:

- stable identifiers
- state snapshots
- incremental updates
- animation only when it clarifies change

What this should change:

- Conversation list updates should preserve selection and scroll position.
- Search filtering should not cause jarring list identity churn.
- Timeline selection and transcript loading should operate on stable IDs.
- Media selection should survive inspector tab switches and search refinements.

This app should behave like a reliable archive, not a fragile live view.

## 10. Input-awareness and text ergonomics

`UITextInputContext` is iOS-oriented, but the concept still matters: Apple adapts UI to likely input mode.

What this should change conceptually:

- Favor keyboard-first flows by default on macOS.
- Avoid tiny controls that assume pointer precision during stressful usage.
- Keep the main search affordance active and fast to focus.
- Make transcript selection, copying, and navigation excellent with hardware keyboard alone.

## 11. Stress-safe UX

UIKit documentation doesn’t say “stress-safe” in those words, but its patterns reward clarity, reversibility, and predictability.

For `iRemember`, this should become an explicit product standard:

- No destructive ambiguity
- no hidden state changes
- no overloaded controls
- no “maybe it searched, maybe it filtered” confusion
- no subtle hit targets for critical timeline actions
- no hard mode for first-time users

The user under stress should always know:

- where they are
- what scope they’re searching
- what date they’re looking at
- what is selected
- what happens next if they click export

## UIKit ideas to import carefully

These are useful conceptually, but should be translated into Mac-native SwiftUI behavior rather than copied literally.

### Lists and collection presentation

- Dense, identity-stable content presentation
- Prefetching discipline
- Incremental updates
- Context menus per item

### Search and find

- Explicit find navigation
- Keyboard discoverability
- Search state persistence

### Preview and share

- item-centered preview
- action menus tied to selection
- multiple export representations

### Restoration

- continuity after relaunch
- explicit restoration IDs for core navigation state

## UIKit ideas we should not import directly

These would make the app worse on macOS if copied literally.

- iPhone-style bottom tab bars
- gesture-heavy navigation that hides state
- fullscreen modal-first flows for common tasks
- touch-sized blank surfaces without pointer affordance
- iOS-style navigation stacks in place of split-view information architecture
- oversized mobile padding that wastes desktop information density

## Expectations for this app

- Fast, calm, trustworthy historical browsing
- Excellent date-based navigation
- Strong transcript context around search results
- Media workflows that feel native and obvious
- Predictable export affordances
- State restoration and continuity
- Dark mode and accessibility quality high enough to pass close review

## Non-expectations

- It should not feel like iMessage copied wholesale
- it should not feel like a forensic utility first and a humane product second
- it should not become analytics-heavy
- it should not rely on custom visuals that fight macOS conventions
- it should not force users to learn a new navigation grammar

## Immediate overhaul backlog from these notes

Priority 1:

- Make the entire timeline bucket region clickable, not just day labels.
- Add explicit, adjustable timeline height with strong hit affordances.
- Add in-app “What to do next” guidance for first-run and first-selection states.
- Add full transcript context menus and stronger search/focus commands.
- Harden dark-mode contrast and metadata legibility.

Priority 2:

- Add state restoration for active conversation, timeline, filters, and inspector tab.
- Add real in-transcript find navigation.
- Expand accessibility labels and identifiers across custom timeline and media views.
- Add export representations and share-model design.

Priority 3:

- Add smarter prefetching around transcript and media edges.
- Add richer context actions and better preview transitions.
- Add saved workflows for archivists and memory-keepers.

## Bottom line

UIKit’s best contribution to this app is not “use UIKit.” It is the standard it sets for:

- continuity
- discoverability
- accessible semantics
- predictable commands
- structured previews
- disciplined appearance support
- incremental, identity-stable UI updates

Those principles should absolutely overhaul `iRemember`, but they should be realized through SwiftUI and macOS-native interaction patterns.
