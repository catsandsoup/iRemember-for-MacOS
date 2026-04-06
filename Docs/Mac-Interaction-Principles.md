# Mac Interaction Principles for iRemember

## Sources

- Apple SwiftUI guidance on great Mac apps:
  flexible, familiar, expansive, precise
- Apple dark mode guidance:
  use semantic colors, standard controls, adaptive materials, and avoid hard-coded light-only assumptions
- WWDC guidance for Mac apps:
  toolbar actions should be discoverable, menu commands should exist for important actions, sidebars and detail panels should be adjustable per-user

## Product-specific rules

1. If a surface looks like a pane, it needs pane behavior.
Sidebar, center content, inspector, and timeline surfaces should be resizable, collapsible, or both.

2. If a surface suggests scrolling, make it scroll.
Desktop timeline and scrubber surfaces should support horizontal scrolling instead of trapping mobile-style swipe patterns inside fixed widths.

3. If information is repeated, remove the weaker copy.
Conversation identity should live in the inspector and sidebar. The center pane should prioritize task surfaces like timeline, transcript, and media.

4. Important controls need more than one entry point.
Toolbar access is not enough on macOS. Add menu-bar commands and keyboard shortcuts for core display and navigation actions.

5. Calm does not mean passive.
A quiet interface can still show affordances clearly through hover states, selection states, scroll indicators, disclosure, and segmented controls.

## Core user modes

- Focused archivist:
  needs precise navigation, bounded memory behavior, reproducible context
- Stressed evidence-prep user:
  needs low-friction date jumps, obvious controls, no ambiguous dead surfaces
- Family memory keeper:
  needs warmth and calm, but still fast access to photos and dates
- Power user:
  expects keyboard shortcuts, menus, split panes, and customization
- Low-confidence user:
  needs familiar Apple patterns and strong interaction hints

## Expectations

- Sidebars and inspectors can be shown or hidden
- Timeline is compact by default and user-adjustable
- Search, timeline, transcript, and media each feel like distinct task surfaces
- Scrollable surfaces show scrollability
- Selection and reveal actions feel immediate

## Non-expectations

- Decorative dashboards with no direct action
- Duplicate metadata blocks
- Full-thread eager loading
- iPhone-style gesture dependence on macOS
- Custom chrome that hides standard macOS behaviors
