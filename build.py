#!/usr/bin/env python3
"""Build DartKDS release: Flutter web UI + Android APK.

Steps (unless skipped):
  1. flutter build web --no-web-resources-cdn   (local canvaskit, air-gapped safe)
  2. dart run scripts/bundle_webui.dart          (pack build/web -> assets/webui.bin)
  3. flutter build apk --release --split-per-abi (APK now bundles the web UI)

Usage:
  python build.py               # full release build
  python build.py --debug       # build a debug APK instead of release
  python build.py --skip-web    # skip recompiling web; bundle the existing build/web
  python build.py --web-only    # build + bundle the web UI, skip APK
  python build.py --apk-only    # build the APK only (web UI must already be bundled)
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def run(cmd):
    print(f"\n==> {' '.join(cmd)}", flush=True)
    first = shutil.which(cmd[0])
    if first is not None and first.lower().endswith((".bat", ".cmd")):
        cmd = ["cmd", "/c"] + cmd
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=str(ROOT),
            bufsize=1,
            universal_newlines=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
    except OSError as e:
        print(f"ERROR: failed to launch {' '.join(cmd)}: {e}", file=sys.stderr)
        return 1
    if proc.stdout is not None:
        for line in proc.stdout:
            print(line, end="", flush=True)
    proc.wait()
    return proc.returncode


def tools_ok():
    missing = [tool for tool in ("flutter", "dart") if shutil.which(tool) is None]
    if missing:
        print(f"ERROR: not found on PATH: {', '.join(missing)}", file=sys.stderr)
        return False
    return True


def ensure_webui_placeholder():
    """The web build validates every pubspec asset, including the bundled web UI
    (assets/webui.bin) that only exists after bundling. Create an empty placeholder
    so an initial fresh build can compile; bundle_webui.dart overwrites it."""
    placeholder = ROOT / "assets" / "webui.bin"
    if not placeholder.exists():
        placeholder.touch()
        print("==> Created empty assets/webui.bin placeholder (bundled later)")


def fail(step):
    print(f"\nERROR: {step} failed.", file=sys.stderr)
    return 1


def main():
    ap = argparse.ArgumentParser(
        prog="build",
        description="Build DartKDS (Flutter web UI + Android APK).",
    )
    ap.add_argument(
        "--debug",
        action="store_true",
        help="build a debug APK instead of a release APK",
    )
    ap.add_argument(
        "--skip-web",
        action="store_true",
        help="skip recompiling the web UI; bundle the existing build/web into assets",
    )
    ap.add_argument(
        "--web-only",
        action="store_true",
        help="build + bundle the web UI only (no APK)",
    )
    ap.add_argument(
        "--apk-only",
        action="store_true",
        help="build the APK only (web UI must already be bundled into assets/webui.bin)",
    )
    args = ap.parse_args()

    if not tools_ok():
        return 1

    if not args.apk_only:
        if not args.skip_web:
            ensure_webui_placeholder()
            if run(["flutter", "build", "web", "--no-web-resources-cdn"]) != 0:
                return fail("Web UI build")
        if run(["dart", "run", "scripts/bundle_webui.dart"]) != 0:
            return fail("Web UI bundling")

    if args.web_only:
        print("\nWeb UI built and bundled. Done (--web-only).")
        return 0

    apk_cmd = ["flutter", "build", "apk", "--split-per-abi"]
    if args.debug:
        apk_cmd.append("--debug")
    else:
        apk_cmd.append("--release")
    if run(apk_cmd) != 0:
        return fail("APK build")

    print("\nBuild complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())