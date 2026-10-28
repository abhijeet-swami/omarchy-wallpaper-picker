#!/usr/bin/env python3
"""Wallhaven API and theme helper for the Omarchy wallpaper picker."""

import json
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://wallhaven.cc/api/v1/search"
HOME = Path.home()
THEMES = HOME / ".config/omarchy/themes"
STATE_FILE = HOME / ".config/omarchy/wallhaven-picker-state.json"
LEGACY_STATE_FILE = HOME / ".config/omarchy/plugins/abhijeet.wallpaper-picker/state.json"
WALLPAPERS = HOME / "Wallpapers"
LOCAL_THUMB_CACHE = HOME / ".cache/omarchy/wallhaven-picker/local-thumbnails"
IMAGEMAGICK = shutil.which("magick") or shutil.which("convert")
SESSION = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"omarchy-wallhaven-{os.getuid()}"
HEADERS = {"User-Agent": "Omarchy-Wallhaven-Picker/1.0"}
SORT_MODES = {"month", "year", "week", "recent"}


def request(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=25) as response:
        return response.read()


def load_state():
    for path in (STATE_FILE, LEGACY_STATE_FILE):
        try:
            state = json.loads(path.read_text(encoding="utf-8"))
            mode = state.get("sortMode") if isinstance(state, dict) else None
            if mode in SORT_MODES:
                if path == LEGACY_STATE_FILE:
                    save_state(mode)
                return {"sortMode": mode}
        except (OSError, ValueError, TypeError):
            continue
    return {"sortMode": "month"}


def save_state(mode):
    if mode not in SORT_MODES:
        raise ValueError("Invalid sort mode")
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temp_path = tempfile.mkstemp(prefix=".wallhaven-state-", dir=STATE_FILE.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as state_file:
            json.dump({"sortMode": mode}, state_file, indent=2)
            state_file.write("\n")
        os.replace(temp_path, STATE_FILE)
    except Exception:
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise
    return {"sortMode": mode}


def download_wallpaper(item_id, image_url):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", item_id):
        raise ValueError("Invalid Wallhaven wallpaper id")
    WALLPAPERS.mkdir(parents=True, exist_ok=True)
    suffix = Path(urllib.parse.urlparse(image_url).path).suffix.lower()
    if suffix not in {".jpg", ".jpeg", ".png", ".webp", ".bmp"}:
        suffix = ".jpg"
    destination = WALLPAPERS / f"wallhaven-{item_id}{suffix}"
    if not destination.is_file():
        destination.write_bytes(request(image_url))
    return {"filename": destination.name, "path": str(destination)}


def list_local_wallpapers(query=""):
    extensions = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".avif"}
    WALLPAPERS.mkdir(parents=True, exist_ok=True)
    LOCAL_THUMB_CACHE.mkdir(parents=True, exist_ok=True)
    needle = query.strip().casefold()
    all_paths = [path.resolve() for path in WALLPAPERS.iterdir()
                 if path.is_file() and path.suffix.lower() in extensions]
    cache_keys = {hashlib.sha256(str(path).encode("utf-8")).hexdigest() for path in all_paths}

    # Keep the cache in sync with the source folder every time local mode is
    # opened or searched. A wallpaper removed by the user loses its thumbnail.
    for cached in LOCAL_THUMB_CACHE.iterdir():
        if (cached.suffix in {".jpg", ".json"}
                and re.fullmatch(r"[a-f0-9]{64}", cached.stem)
                and cached.stem not in cache_keys):
            try:
                cached.unlink()
            except OSError:
                pass

    def cache_paths(path):
        key = hashlib.sha256(str(path).encode("utf-8")).hexdigest()
        return LOCAL_THUMB_CACHE / f"{key}.jpg", LOCAL_THUMB_CACHE / f"{key}.json"

    def is_fresh(path, thumb, metadata_path):
        try:
            source_stat = path.stat()
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            return thumb.is_file() and metadata == {
                "mtime_ns": source_stat.st_mtime_ns,
                "size": source_stat.st_size,
                "inode": source_stat.st_ino,
            }
        except (OSError, ValueError, TypeError):
            return False

    paths = [path for path in all_paths if needle in path.name.casefold()]
    paths.sort(key=lambda path: (path.stat().st_mtime_ns, path.name.casefold()), reverse=True)
    entries = []
    for path in paths:
        thumb, metadata_path = cache_paths(path)
        ready = is_fresh(path, thumb, metadata_path)
        entries.append({
            "id": path.name,
            "thumb": str(thumb if ready else path),
            "thumbCache": str(thumb),
            "sourcePath": str(path),
            "url": str(path),
            "filename": path.name,
        })
    return {"data": entries}


def cache_local_thumbnails(paths_json):
    if not IMAGEMAGICK:
        return {"data": [], "error": "ImageMagick was not found; showing source images."}
    try:
        requested = json.loads(paths_json)
    except (ValueError, TypeError):
        raise ValueError("Invalid local thumbnail list")
    if not isinstance(requested, list):
        raise ValueError("Invalid local thumbnail list")
    LOCAL_THUMB_CACHE.mkdir(parents=True, exist_ok=True)

    def make_thumbnail(path_value):
        source = Path(path_value).expanduser().resolve()
        if not source.is_relative_to(WALLPAPERS.resolve()) or not source.is_file():
            return None
        source_stat = source.stat()
        key = hashlib.sha256(str(source).encode("utf-8")).hexdigest()
        thumb = LOCAL_THUMB_CACHE / f"{key}.jpg"
        metadata_path = LOCAL_THUMB_CACHE / f"{key}.json"
        try:
            cached_metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            if thumb.is_file() and cached_metadata == {
                "mtime_ns": source_stat.st_mtime_ns,
                "size": source_stat.st_size,
                "inode": source_stat.st_ino,
            }:
                return {"sourcePath": str(source), "thumb": str(thumb)}
        except (OSError, ValueError, TypeError):
            pass

        temp_thumb = LOCAL_THUMB_CACHE / f".{key}.{os.getpid()}.tmp.jpg"
        command = [
            IMAGEMAGICK, "-limit", "thread", "1", "-limit", "memory", "256MiB",
            "-limit", "map", "512MiB", str(source), "-auto-orient",
            "-thumbnail", "448x256^", "-gravity", "center", "-extent", "448x256",
            "-strip", "-quality", "82", str(temp_thumb),
        ]
        metadata_temp = None
        try:
            converted = subprocess.run(command, stdout=subprocess.DEVNULL,
                                       stderr=subprocess.PIPE, timeout=45)
            if converted.returncode or not temp_thumb.is_file() or not source.is_file():
                return None
            current_stat = source.stat()
            if (current_stat.st_mtime_ns, current_stat.st_size, current_stat.st_ino) != (
                    source_stat.st_mtime_ns, source_stat.st_size, source_stat.st_ino):
                return None
            os.replace(temp_thumb, thumb)
            descriptor, metadata_temp = tempfile.mkstemp(prefix=f".{key}.", dir=LOCAL_THUMB_CACHE)
            with os.fdopen(descriptor, "w", encoding="utf-8") as metadata_file:
                json.dump({
                    "mtime_ns": source_stat.st_mtime_ns,
                    "size": source_stat.st_size,
                    "inode": source_stat.st_ino,
                }, metadata_file)
                metadata_file.write("\n")
            os.replace(metadata_temp, metadata_path)
            return {"sourcePath": str(source), "thumb": str(thumb)}
        except (OSError, subprocess.SubprocessError):
            return None
        finally:
            for temporary in (temp_thumb, Path(metadata_temp) if metadata_temp else None):
                if temporary is None:
                    continue
                try:
                    temporary.unlink()
                except OSError:
                    pass

    # Limit ImageMagick concurrency so large source images do not overwhelm
    # CPU and memory when the picker warms nearby carousel items.
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = [entry for entry in pool.map(make_thumbnail, requested) if entry]
    return {"data": results}


def apply_local(path_value):
    path = Path(path_value).expanduser().resolve()
    wallpaper_root = WALLPAPERS.resolve()
    if not path.is_relative_to(wallpaper_root) or not path.is_file():
        raise ValueError("Choose a saved wallpaper from ~/Wallpapers")
    return apply_wallpaper_theme(path)


def search(query="", page=1, sort_mode="month"):
    page = max(1, int(page))
    params = {"page": page, "purity": "100"}
    if query.strip():
        params["q"] = query.strip()
        if sort_mode == "top":
            params["sorting"] = "toplist"
            params["topRange"] = "1M"
        else:
            params["sorting"] = "relevance"
    else:
        top_ranges = {"month": "1M", "year": "1y", "week": "1w"}
        if sort_mode == "recent":
            params["sorting"] = "date_added"
            params["order"] = "desc"
        else:
            params["sorting"] = "toplist"
            params["topRange"] = top_ranges.get(sort_mode, "1M")
    data = json.loads(request(API + "?" + urllib.parse.urlencode(params)))
    SESSION.mkdir(parents=True, exist_ok=True)
    items = data.get("data", [])

    def make_wallpaper(item):
        thumbs = item.get("thumbs", {})
        # `large` is enough for the selected card while far smaller than the
        # `original` thumbnail. Keep `small` as a fallback for older records.
        thumb = thumbs.get("large") or thumbs.get("small")
        cached = thumb or ""
        if thumb:
            suffix = Path(urllib.parse.urlparse(thumb).path).suffix or ".jpg"
            cached_path = SESSION / f"{item['id']}-large{suffix}"
            if not cached_path.is_file():
                try:
                    cached_path.write_bytes(request(thumb))
                except Exception:
                    pass
            if cached_path.is_file():
                cached = str(cached_path)
        return {
            "id": item.get("id", ""),
            "thumb": cached,
            "url": item.get("path", ""),
            "resolution": item.get("resolution", ""),
            "fileSize": item.get("file_size", 0),
            "favorites": item.get("favorites", 0),
        }

    # Fetch the page's thumbnails concurrently so one slow image doesn't hold
    # up all 24 results. Preserve the API's order for the carousel.
    with ThreadPoolExecutor(max_workers=8) as pool:
        wallpapers = list(pool.map(make_wallpaper, items))
    return {"data": wallpapers, "meta": data.get("meta", {})}


def safe_slug(value):
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")[:48]
    return slug or "wallhaven-theme"


def wallust_colors(image, outdir):
    wallust = shutil.which("wallust")
    if not wallust:
        raise RuntimeError("wallust is required. Install it with: yay -S wallust-bin")
    cfg = Path(tempfile.mkdtemp(prefix="wallhaven-wallust-"))
    try:
        (cfg / "wallust").mkdir()
        (cfg / "wallust" / "templates").mkdir()
        template = '''mode = "dark"
accent = "{{color4}}"
selection = "{{color8}}"
selection_foreground = "{{foreground}}"
muted = "{{color8}}"
background = "{{background}}"
dark_background = "{{color0}}"
darker_background = "{{color0}}"
lighter_background = "{{color8}}"
foreground = "{{foreground}}"
dark_foreground = "{{color8}}"
light_foreground = "{{color7}}"
bright_foreground = "{{color15}}"
red = "{{color1}}"
yellow = "{{color3}}"
orange = "{{color11}}"
green = "{{color2}}"
cyan = "{{color6}}"
blue = "{{color4}}"
magenta = "{{color5}}"
brown = "{{color3}}"
bright_red = "{{color9}}"
bright_yellow = "{{color11}}"
bright_green = "{{color10}}"
bright_cyan = "{{color14}}"
bright_blue = "{{color12}}"
bright_magenta = "{{color13}}"
'''
        (cfg / "wallust" / "templates" / "omarchy-colors.toml").write_text(template)
        (cfg / "wallust" / "wallust.toml").write_text(
            '[templates]\nomarchy = { src = "omarchy-colors.toml", dst = "' +
            str(Path(outdir) / "colors.toml") + '" }\n'
        )
        env = os.environ.copy()
        env["XDG_CONFIG_HOME"] = str(cfg)
        result = subprocess.run([wallust, "run", str(image)], env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
        colors = Path(outdir) / "colors.toml"
        if result.returncode or not colors.is_file():
            raise RuntimeError(result.stderr.strip() or "wallust did not create colors.toml")
    finally:
        shutil.rmtree(cfg, ignore_errors=True)


def apply_wallpaper_theme(image):
    """Update and apply the single theme owned by this plugin."""
    image = Path(image).resolve()
    if not image.is_file():
        raise ValueError(f"Wallpaper does not exist: {image}")

    THEMES.mkdir(parents=True, exist_ok=True)
    slug = "wallhaven-picker"
    theme = THEMES / slug
    marker_name = ".wallhaven-picker-managed"
    if theme.exists() and not (theme / marker_name).is_file() and any(theme.iterdir()):
        raise RuntimeError(f"Refusing to overwrite unowned theme directory: {theme}")

    staging = Path(tempfile.mkdtemp(prefix=".wallhaven-picker-stage-", dir=THEMES))
    backup = None
    try:
        staged_backgrounds = staging / "backgrounds"
        staged_backgrounds.mkdir()
        staged_image = staged_backgrounds / image.name
        shutil.copy2(image, staged_image)
        wallust_colors(staged_image, staging)
        (staging / marker_name).write_text("Managed by abhijeet.wallpaper-picker\n", encoding="utf-8")

        if theme.exists():
            backup = Path(tempfile.mkdtemp(prefix=".wallhaven-picker-backup-", dir=THEMES))
            backup.rmdir()
            os.replace(theme, backup)
        try:
            os.replace(staging, theme)
            staging = None
            applied = subprocess.run(["omarchy", "theme", "set", slug], text=True,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
            if applied.returncode:
                raise RuntimeError(applied.stderr.strip() or applied.stdout.strip() or "Could not apply Omarchy theme")
        except Exception:
            if theme.exists():
                shutil.rmtree(theme, ignore_errors=True)
            if backup and backup.exists():
                os.replace(backup, theme)
                backup = None
            raise

        if backup and backup.exists():
            shutil.rmtree(backup, ignore_errors=True)
            backup = None
        return {"theme": slug, "image": str(theme / "backgrounds" / image.name)}
    finally:
        if staging and staging.exists():
            shutil.rmtree(staging, ignore_errors=True)
        if backup and backup.exists() and not theme.exists():
            os.replace(backup, theme)


def apply(item_id, image_url, title):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", item_id):
        raise ValueError("Invalid Wallhaven wallpaper id")
    suffix = Path(urllib.parse.urlparse(image_url).path).suffix.lower()
    if suffix not in {".jpg", ".jpeg", ".png", ".webp", ".bmp"}:
        suffix = ".jpg"
    temp_dir = Path(tempfile.mkdtemp(prefix="wallhaven-download-"))
    image = temp_dir / f"wallhaven-{item_id}{suffix}"
    try:
        image.write_bytes(request(image_url))
        return apply_wallpaper_theme(image)
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if action == "load-state":
            result = load_state()
        elif action == "save-state":
            result = save_state(sys.argv[2] if len(sys.argv) > 2 else "")
        elif action == "download":
            result = download_wallpaper(sys.argv[2], sys.argv[3])
        elif action == "local-list":
            result = list_local_wallpapers(sys.argv[2] if len(sys.argv) > 2 else "")
        elif action == "cache-local":
            result = cache_local_thumbnails(sys.argv[2] if len(sys.argv) > 2 else "[]")
        elif action == "apply-local":
            result = apply_local(sys.argv[2])
        elif action == "search":
            result = search(
                sys.argv[2] if len(sys.argv) > 2 else "",
                sys.argv[3] if len(sys.argv) > 3 else 1,
                sys.argv[4] if len(sys.argv) > 4 else "month",
            )
        elif action == "apply":
            result = apply(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
        elif action == "cleanup":
            shutil.rmtree(SESSION, ignore_errors=True)
            result = {"cleaned": True}
        else:
            raise ValueError("Unknown action")
        print(json.dumps({"ok": True, "result": result}))
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
