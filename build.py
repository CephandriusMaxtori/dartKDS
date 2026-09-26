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
import os
import shutil
import subprocess
import sys
from pathlib import Path

# Force JDK 17 for Gradle/Flutter compatibility
os.environ["JAVA_HOME"] = r"C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"

ROOT = Path(__file__).resolve().parent


def run(cmd, cwd=None):
    print(f"\n==> {' '.join(cmd)}", flush=True)
    jdk17 = r"C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
    target_dir = cwd if cwd is not None else ROOT
    env = os.environ.copy()
    env["JAVA_HOME"] = jdk17
    env["PATH"] = f"{jdk17}\\bin;{env.get('PATH', '')}"
    full_cmd = ["cmd", "/c", f"set JAVA_HOME={jdk17}&& set PATH={jdk17}\\bin;%PATH%&& " + " ".join(cmd)]
    try:
        proc = subprocess.Popen(
            full_cmd,
            cwd=str(target_dir),
            env=env,
            bufsize=1,
            universal_newlines=True,
            encoding="utf-8",
            errors="replace",
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


def cleanup_android_locks():
    lock_file = Path.home() / ".android" / "debug.keystore.lock"
    if lock_file.exists():
        try:
            lock_file.unlink()
            print("==> Cleaned up stale debug.keystore.lock")
        except Exception as e:
            print(f"Warning: Could not remove lock file: {e}")


def main():
    cleanup_android_locks()
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
        webui_asset = ROOT / "assets" / "webui.bin"
        webui_asset.parent.mkdir(parents=True, exist_ok=True)
        if not webui_asset.exists():
            webui_asset.touch()

        if not args.skip_web:
            ensure_webui_placeholder()
            if run(["flutter", "build", "web", "--no-web-resources-cdn"]) != 0:
                return fail("Web UI build")
        if run(["dart", "run", "scripts/bundle_webui.dart"]) != 0:
            return fail("Web UI bundling")

    if args.web_only:
        print("\nWeb UI built and bundled. Done (--web-only).")
        return 0

    if args.debug:
        if run(["gradlew.bat", "assembleDebug"], cwd=ROOT / "android") != 0:
            return fail("APK build")
    else:
        if run(["flutter", "build", "apk", "--split-per-abi", "--release"]) != 0:
            if run(["gradlew.bat", "assembleRelease"], cwd=ROOT / "android") != 0:
                return fail("APK build")

    print("\nBuild complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())