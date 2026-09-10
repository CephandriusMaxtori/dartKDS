# Plan: Two Host Devices with Full 2-Way Sync (Fallback Host)

Status: **ON HOLD** — confirmed by user on 2026-09-09. No code has been changed yet (audit only).

## Goal

Allow 2 host devices so 1 can act as a fallback. Both hosts stay fully writable and exchange
changes both ways while both are online (full 2-way sync). Kitchen display clients auto-switch
to whichever host is alive (preferring the primary).

## Current State (verified audit)

### Schema (`lib/models/database.dart`, schemaVersion 8)
- Toolchain: Drift + `build_runner`. No `updatedAt`/`createdAt` column on ANY table.
- `KDSOrders`: PK = `uuid` (text, stable across hosts already).
- `KDSItems`: PK = local auto-increment `id`, plus `uuid` (text, stable) + FK `orderUuid`.
- `MenuItems`: PK = local auto-increment `id`. NO stable cross-host key.
- `Stations`: PK = local auto-increment `id`; `name` is UNIQUE (usable as natural sync key).
- `GlobalModifiers`: PK = local auto-increment `id`; `name` is UNIQUE (usable as natural sync key).

### Sync-relevant behavior
- `ItemBumped` / `TicketFinished` are in-memory only on clients — no DB write. Bump state is NOT
  persisted anywhere. Only order *creation* (and order-edit) touch the DB.
- Stock decrement happens in:
  - `order_intake_view.dart` `_sendToKitchen` (per-item quantity, also restores on edit)
  - `host_server.dart` WS `CreateOrder` (hardcoded -1 per array entry; buggy for quantity)
  - `intake_screen.dart` `_submitOrder` does **NOT** touch stock.
- Web POS (browser `host.html`) writes only via HTTP API + WS on the host server.
- Discovery: UDP broadcast (port 41234, `{'app':'dartkds','port':8080}`) + mDNS `_kdsapp._tcp`.
  No host identity in the payload.

### All DB write sites (need `updatedAtMs` stamping)
| File | Table / lines |
|---|---|
| `lib/services/host_server.dart` | Stations 99,113,146,158,166,266; GlobalModifiers 102,103,104,182,190,269; MenuItems 70-80,97-107,115,130,272-282,331-333; KDSOrders 317-322; KDSItems 336-344 |
| `lib/ui/host/intake_screen.dart` | KDSOrders ~430-435; KDSItems ~441-448 |
| `lib/ui/host/views/order_intake_view.dart` | MenuItems stock 541-543, 570-572; KDSItems 547, 576-584; KDSOrders 549-555, 557-562 |
| `lib/ui/host/views/library_view.dart` | MenuItems 170-180, 258, 518, 603; Stations 335, 369, 516, 542; GlobalModifiers 404, 438, 517 |
| `lib/ui/host/views/inventory_view.dart` | MenuItems stock 207 |

## Design Decisions

1. **Sync identity keys**
   - `KDSOrders` → `uuid`; `KDSItems` → `uuid`.
   - `Stations` / `GlobalModifiers` → `name` (unique constraint).
   - `MenuItems` → NEW `guid` column (uuid v4, generated at insert) since no natural key.

2. **Change tracking**: `updatedAtMs` (epoch ms int) on all 5 tables + NEW `SyncTombstones`
   table for deletions (physical delete + record tombstone). Reads are NOT filtered by tombstone
   (tombstones live in their own table) → minimal blast radius on read paths.

3. **Conflict resolution**: Last-write-wins by `updatedAtMs` (ties: skip). Acceptable — LAN clocks
   skew is small and simultaneous edits across two hosts are rare. Orders are effectively
   insert-only, so conflicts are minimal for them.

4. **Skew robustness**: delta requests use `since=<ms>` BUT the responder also returns rows whose
   own `updatedAtMs` is within a recent window (e.g. last 120s) so a lagging peer clock cannot
   permanently stall an item. Plus a periodic full resync failsafe.

5. **Sync protocol (delta pull/push)**
   - `GET /api/sync/changes?since=<ms>` → rows with `updatedAtMs > since` OR inside window, PLUS tombstones.
   - `POST /api/sync/apply` → merge incoming changes + tombstones (LWW).
   - `POST /api/sync/reset` → full snapshot bootstrap on first pairing (or full resync).
   - Core merge logic lives in a separate `SyncEngine` class (pure, unit-testable with two
     in-memory Drift DBs) — the HTTP handlers and the periodic poller both call it.

6. **Host pairing**: host announcement payload becomes
   `{'app':'dartkds','port':8080,'hostId':<uuid>,'role':'primary'|'backup'}`.
   - `hostId` persisted in SharedPreferences (`host_id`, generated once).
   - `role` persisted in SharedPreferences (`host_role`).
   - Each host syncs with every discovered host whose `hostId != self` and role is a host.

7. **Client failover**: discovery keeps a map of available hosts; client prefers a `primary`
   host, else any; on WS disconnect, auto-rediscover and reconnect to best available host.

8. **No auth** (consistent with the rest of the air-gapped system). Sync only accepts LAN peers.

## Implementation Steps (todo order)

1. [x] Map all DB write sites across `lib/` (done, see table above).
2. Schema v9:
   - Add `updatedAtMs` (default 0) to `MenuItems`, `Stations`, `GlobalModifiers`,
     `KDSOrders`, `KDSItems`.
   - Add `guid` (text, default '') to `MenuItems`; backfill via raw SQL uuid generation
     (`lower(hex(randomblob(4)) || '-' || ... )` — verify snake_case table/column names in
     `database.g.dart` first).
   - Add `SyncTombstones` table (`tableName` + `rowKey` composite PK + `updatedAtMs`).
   - Run `dart run build_runner build --delete-conflicting-outputs`.
3. Stamp `updatedAtMs` (+ `guid` on new MenuItems) at all write sites listed above.
4. Host announcement: add `hostId` + `role` (DiscoveryService + prefs + RoleSelection).
5. `SyncEngine` class (snapshot / delta / LWW merge / tombstone apply).
6. HTTP endpoints: `/api/sync/changes`, `/api/sync/apply`, `/api/sync/reset`.
7. `SyncService`: periodic poll (e.g. 10s) of discovered peers, push+pull, status provider
   (peer address, role, last sync time, error).
8. Client failover in `client_home.dart`.
9. UI: "BACKUP HOST" card on `role_selection_screen.dart` (+ store role); SYNC status card on
   host More/Settings view.
10. Integration test: run two in-memory Drift DBs through `SyncEngine` (LWW + tombstone),
    plus a two-`HostServer` HTTP exchange test.

## Open Questions / Risks

- `intake_screen.dart` (`_submitOrder`) does not decrement stock — inconsistent with other
  order paths. Fix while stamping (decide desired behavior).
- Bump state (`ItemBumped`/`TicketFinished`) is not persisted; failover currently loses bump
  state per client. Decide whether to persist per-client or per-order bump status.
- Clock skew on LAN: mitigated by windowed delta + tie-skip, but not eliminated.