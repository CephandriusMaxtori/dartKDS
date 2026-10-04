# DartKDS — Known UI Issues

Rough edges and outright bugs found while documenting the UI in [`UI.md`](UI.md).

Items 1–3, 5, 7, 9 and 10 below were listed here previously and have since been
fixed; they are kept as short notes so the next person does not re-investigate
them. What is still open is under **Open**.

## Open

### 4. A ticket taller than the board scrolls with no indication

`lib/ui/client/client_home.dart` — the item list inside `_TicketCard` is bounded
by the card, so an order with more items than fit, or `clientTextScale` at its
2.0 maximum (which grows the rows without growing the card), still truncates.
Issue #6 gave every tile the full board height instead of a share of it, which
fixed the common case but left the list bounded.

**Fixed:** the list is wrapped in a `Scrollbar` with `thumbVisibility: true`, so
the control is always on screen. A full-length thumb means everything fits; a
short one means there is more below. It uses an explicit `ScrollController`
rather than the primary one, because the board is a horizontal strip of cards
and a shared controller would put two scrollables on one position.

### 6. Hardcoded greys bypass the theme (partly fixed)

`#666666`, `#111111`, `#6B7280` and `#1F2937` are spread across `library_view`,
`order_intake_view`, `settings_view`, `analytics_view`, `client_home`,
`inventory_view`, `more_view` and `sent_queue_view`.

**Fixed so far** — the secondary-text cases, which are the ones that actually
vanish in `high contrast` mode:

- `analytics_view` — `PERFORMANCE BY ITEM` heading and the summary-card labels
  now use `theme.hintColor`
- `settings_view` — `_buildSectionHeader` and the empty-state row now use
  `theme.hintColor`

**Still open, and deliberately not changed.** The remaining greys are not hint
colours, so the "replace with `hintColor` / `cardColor` / `dividerColor`"
instruction in the old version of this file would have made things worse:

- `#111111` and `#1F2937` are mostly *deliberate brand near-blacks* — primary
  button fills paired with `foregroundColor: Colors.white`, selection fills,
  snackbar surfaces, slider active thumbs. Recolouring these to a grey token
  would drop them straight out of contrast.
- `sent_queue_view.dart:381` is a *semantic status colour* for the `CLOSED`
  order state, not a hint.
- `library_view.dart:413` and `more_view.dart:72` pass a dark grey in as the
  text/icon colour of a light chip; `hintColor` there would be too pale.
- `client_home.dart:814` looks like a hardcoded surface but is already correct
  — it branches on `highContrast` and `light` first.

**The one real bug left in this group** is the client dialogs at
`client_home.dart:933`, `:1339` and `:1379`: each hardcodes
`AlertDialog(backgroundColor: Color(0xFF1F2937))` alongside a
`TextStyle(color: Colors.white)` title, so they stay dark on a light board and
ignore `high contrast` entirely. The sibling dialog at `:1118` already does it
correctly with `isLight ? Colors.white : const Color(0xFF1F2937)`.

This was left alone because it is not a one-line find-and-replace: retheming
the background also invalidates the hardcoded white title and content colours in
each dialog. It wants a shared helper that resolves a dialog surface plus
foreground pair from `isDarkBoard`, applied to all four dialogs together.

## Fixed

### 1. `Reset Application` does nothing — fixed

`lib/ui/host/views/settings_view.dart` — `RESET` used to only
`Navigator.pop(context)`. It now calls `_resetEverything`, which clears the
library and the sales/history stores and reports failure in a snackbar instead
of swallowing it.

One wrinkle survived that fix and is worth a follow-up: the reset is still
confirmed **twice**. `_showResetConfirmation` puts up `Reset Everything?`, and
`_resetEverything` immediately puts up a second `Delete for good?` dialog on top
of it. The two also disagree on scope — the first says "all menu items and your
order history", the second adds stations and the display-clearing side effect.
Collapsing them into one dialog would fix both.

### 2. Grid helper has a dead branch — fixed

`lib/ui/shared/responsive_utils.dart` — the mid-width case is now
`2.clamp(min, max)` and the fallback `min.clamp(1, max)`, so `min: 1` actually
collapses to a single column.

### 3. Client settings cannot select System theme — fixed

`lib/ui/client/client_home.dart` — `APPEARANCE` offers `Auto` / `Light` /
`Dark`, and `selected: {settings.themeMode}` reports the real setting rather
than always showing `Dark`.

### 5. `TabBar` indicator color differs between the two tabbed screens — fixed

`lib/ui/host/views/library_view.dart` now uses
`indicatorColor: colorScheme.primary`, matching `sent_queue_view.dart`.

### 7. Duplicated IP ranking function — fixed

Both call sites now go through `HostServer.rankLanAddress`, so the address shown
in settings and in the pairing QR code is the one the host would have picked for
itself.

### 8. Deletions in the library have no confirmation — fixed

`lib/ui/host/views/library_view.dart` — the item overflow menu, the station
trash icon and the global-modifier trash icon all route through a new
`_confirmDelete` helper, which names the row being destroyed and matches the
`CLEAR ALL LIBRARY DATA?` dialog styling already in the file.

### 9. `_buildConnectionScreen` is never called — fixed

`lib/ui/client/client_home.dart` — `build` now returns it on first run
(`!_isConnected && !_hasConnectedBefore`), so QR scan, manual connect and
re-scan are reachable again.

### 10. Client alarm volume may be write-only — not a bug

`settings.clientVolume` is applied correctly. `_audioPlayer` is a single
long-lived `AudioPlayer` instance held by the client state, and `_playSound` sets
the volume on that same instance immediately before `play`. There is no
per-play recreation, so the value takes effect.