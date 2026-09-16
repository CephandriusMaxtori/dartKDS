# OpenKDS (dartKDS)
[![Build Android APK](https://github.com/CephandriusMaxtori/dartKDS/actions/workflows/build.yml/badge.svg)](https://github.com/CephandriusMaxtori/dartKDS/actions/workflows/build.yml)

An open-source **Kitchen Display System (KDS)** built with Flutter — a self-hosted alternative to paper tickets and commercial KDS hardware for restaurants and kitchens.

One device on your network acts as the **Host** (order intake + server), and any number of other devices join as **Clients** (kitchen/prep/expo displays) that receive orders in real time over your local network. No cloud, no subscription, no internet connection required.

Any device with a browser can also access the KDS web UI by visiting `http://<host-ip>:8080` — the host serves a compiled Flutter web client that automatically connects back to the host as a kitchen display. Features are written once in Dart and compiled to web, with no hand-written JS/HTML.

## How it works

- **Host** — Runs the order intake screen and an embedded server (via `shelf` + WebSockets). Orders are stored locally in a SQLite database (via `drift`) and pushed live to every connected client. On desktop the host also serves the Flutter web UI from `build/web`; on mobile the web UI is bundled into the APK via assets and served via `rootBundle`.
- **Client** — Discovers the Host automatically on the local network (via mDNS/`nsd`) and connects over WebSockets to display incoming orders as they arrive. On the web, clients connect directly to the host that served them (`Uri.base.host:8080`), with no manual IP entry needed.
- **Web Client** — The host serves a compiled Flutter web app at `http://<host-ip>:8080`. It shows the role selection screen; picking Client auto-connects to the host. Same Dart codebase as the native app — no separate JS/HTML to maintain.
- Devices pick their role (Host or Client) on first launch from a simple role-selection screen, and each gets its own UI/theme suited to the job — a light "office" UI for intake, and a high-contrast dark UI for kitchen displays.

## Features

- 🖥️ **Host/Client architecture** — one intake station, many kitchen displays, all on the same LAN
- 🌐 **Web UI** — browser-based client served by the host, compiled from the same Dart codebase (no JS/HTML)
- 🔍 **Automatic discovery** — clients find the host via mDNS/NSD, no manual IP entry needed
- 🔌 **Real-time sync** — orders and status updates push instantly over WebSockets
- 🗂️ **Order & item tracking** — orders and individual items move through clear status stages (pending → cooking/partial → ready/complete → bumped)
- 📋 **Menu management** — manage a reusable menu/item library from the host
- 💾 **Local persistence** — orders are stored on-device with `drift`/SQLite, no external database needed
- 🌓 **Light/dark theming** with distinct styles for front-of-house vs. kitchen screens

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.12.2`)
- A target platform toolchain (Android Studio for Android, or a modern browser for web)

### Setup

```bash
# Clone the repo
git clone https://github.com/CephandriusMaxtori/dartKDS.git
cd dartKDS

# Install dependencies
flutter pub get

# Generate database/model code (drift, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Building for production

```bash
# 1. Build the web UI (with local canvaskit for air-gapped LAN)
flutter build web --no-web-resources-cdn

# 2. Bundle the web UI into assets for the APK
dart run scripts/bundle_webui.dart

# 3. Build the release APK (now includes the bundled web UI)
flutter build apk --release --split-per-abi
```

Alternatively, run all three steps at once with `python build.py` (see `build.py --help`
for flags like `--debug`, `--web-only`, `--skip-web`).

The CI workflow (`.github/workflows/build.yml`) runs all three steps automatically on every push.

### Usage

1. Launch the app on the device that will take orders and pick **HOST (Order Intake + Server)**. This starts the local server and advertises it on the network.
2. Launch the app on each kitchen/expo device and pick **CLIENT (Prep / Expo Display)**. Clients will discover the host automatically over the local network and connect.
3. Alternatively, open any browser on the LAN and visit `http://<host-ip>:8080` to use the web client — it auto-connects to the host that served it.
4. Enter orders from the Host's intake screen — they'll appear on all connected Client displays (native + web) in real time. Kitchen staff can update item/order status as food moves through prep.

> All devices must be on the **same local network** for discovery and syncing to work.

## Project Structure

```
lib/
├── main.dart                  # App entrypoint, theming, role-based routing
├── models/                    # Data models (orders, items, menu, statuses) + drift database
├── providers/                 # Riverpod state providers (app state, settings, services)
├── services/                  # Networking: host server, client connection, mDNS discovery
├── ui/
│   ├── host/                  # Order intake, menu management, sent-queue views
│   ├── client/                # Kitchen/expo display
│   └── shared/                # Role selection and other shared screens
└── web_*.dart                 # Stubs for web compilation (dart:io, nsd, shelf_io, etc.)

scripts/
└── bundle_webui.dart          # Copies build/web → assets/webui for APK bundling

assets/
├── notification.mp3           # Alert sound
└── webui/                     # Bundled Flutter web UI (populated by bundle script)
```

## Tech Stack

- **Flutter** / **Dart**
- **Riverpod** — state management
- **shelf**, **shelf_router**, **shelf_web_socket**, **web_socket_channel** — embedded HTTP/WebSocket server & client networking
- **nsd** — mDNS-based network service discovery
- **drift** + **sqlite3_flutter_libs** — local relational database
- **shared_preferences** — lightweight local settings storage
- **Flutter Web** — compiled Dart UI served by the host, no separate JS/HTML codebase

## Status

This project is under active early development. Core host/client networking, discovery, order intake, and kitchen display views are in place; expect rough edges and breaking changes.

## Contributing

Issues and pull requests are welcome. If you're extending the protocol, database schema, or adding new client display types, please open an issue first to discuss the approach.

## License

_No license file is currently included in this repository — add one (e.g. MIT, Apache-2.0, GPL-3.0) to clarify usage terms for contributors and users._
