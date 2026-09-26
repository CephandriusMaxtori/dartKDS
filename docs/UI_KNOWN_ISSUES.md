# DartKDS — Known UI Issues

Rough edges and outright bugs found while documenting the UI in [`UI.md`](UI.md). Nothing here
is fixed yet — this file is a worklist, not a description of intended behavior.

## Bugs

### 1. `Reset Application` does nothing

`lib/ui/host/views/settings_view.dart:554` — `_showResetConfirmation` shows a
`Reset Everything?` dialog whose `RESET` button only calls `Navigator.pop(context)`. No data
is deleted despite the copy: *"This will permanently delete all menu items and your order
history. This cannot be undone."*

### 2. Grid helper has a dead branch

`lib/ui/shared/responsive_utils.dart:63` — `gridColumnsFor(width, {max = 3, min = 2})` returns
`2` for the `>= 620` case and again for the fallback `min`, so screens using the default
arguments never collapse to a single column (`MoreView` is the only caller).

### 3. Client settings cannot select System theme

`lib/ui/client/client_home.dart:949` — the `APPEARANCE` `SegmentedButton` in `KDS SETTINGS`
offers only `Light` and `Dark`, so a client set to `ThemeMode.system` can never get back to
it from the client UI. (`settings.themeMode` is shared with the host picker, which does offer
`System Default`.)

## Inconsistencies

### 4. `TabBar` indicator color differs between the two tabbed screens

- `lib/ui/host/views/library_view.dart:52` uses `indicatorColor: onSurface`
- `lib/ui/host/views/sent_queue_view.dart:16` uses `indicatorColor: theme.colorScheme.primary`

Neither reads as intentional; the primary-colored indicator is the one that matches the rest
of the brand.

### 5. Hardcoded greys bypass the theme

`#666666`, `#111111`, `#6B7280`, and `#1F2937` are spread across `library_view.dart`,
`order_intake_view.dart`, `settings_view.dart`, `analytics_view.dart`, and
`client_home.dart` instead of using `theme.hintColor` / `theme.cardColor` / `theme.dividerColor`.
Consequence: these elements do not adapt to the `high contrast` KDS mode, and light-mode
hierarchy is inconsistent between screens.

### 6. Duplicated IP ranking function

`score()` is defined twice with identical logic —
`lib/ui/host/views/settings_view.dart:111` and `lib/ui/host/views/settings_view.dart:317`.
Any change to the subnet preference has to be made in two places.

### 7. Deletions in the library have no confirmation

`lib/ui/host/views/library_view.dart:571` (stations), `:689` (global modifiers) and the item
overflow menu delete immediately. Compare with the rest of the app, which confirms
`CLEAR TICKET?`, `CLOSE TAB?`, `IMPORT LIBRARY`, and `CLEAR ALL LIBRARY DATA?`.

## Dead code

### 8. `_buildConnectionScreen` is never called

`lib/ui/client/client_home.dart:455` builds a full first-run connect screen
(`SEARCHING FOR KITCHEN HOST...`, `SCAN QR CODE`, `RE-SCAN FOR HOST`, `MANUAL CONNECT`,
`CANCEL`), but `build` at `:340` never references it. The QR scan, manual connect, and
re-scan entry points are therefore unreachable from the UI; only the header's manual-connect
tap and the `swap_horiz` flow are live.

### 9. Client alarm volume may be write-only

`settings.clientVolume` is set in `KDS SETTINGS` and read in `_playSound`
(`lib/ui/client/client_home.dart:83`) — worth confirming the slider actually changes the
played asset, since `audioplayers` volume is applied per `AudioPlayer` instance.
