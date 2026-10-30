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

from animation import animation_config_lua

API = "https://wallhaven.cc/api/v1/search"
HOME = Path.home()
THEMES = HOME / ".config/omarchy/themes"
STATE_FILE = HOME / ".config/omarchy/wallhaven-picker-state.json"
LEGACY_STATE_FILE = HOME / ".config/omarchy/plugins/abhijeet.wallpaper-picker/state.json"
UI_SETTINGS_FILE = HOME / ".config/omarchy/plugins/abhijeet.wallpaper-picker/ui-config.json"
WALLPAPERS = HOME / "Wallpapers"
LOCAL_THUMB_CACHE = HOME / ".cache/omarchy/wallhaven-picker/local-thumbnails"
IMAGEMAGICK = shutil.which("magick") or shutil.which("convert")
SESSION = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"omarchy-wallhaven-{os.getuid()}"
HEADERS = {"User-Agent": "Omarchy-Wallhaven-Picker/1.0"}
SORT_MODES = {"month", "year", "week", "recent"}
THEME_SETTINGS_DEFAULTS = {
    "blurEnabled": False,
    "blurSize": 8,
    "blurPasses": 1,
    "noiseEnabled": False,
    "noiseStrength": 0.0117,
    "rounding": 0,
    "borderWidth": 2,
    "shadowEnabled": False,
    "shadowRange": 4,
    "inactiveOpacity": 1.0,
    "sameWindowOpacity": False,
    "terminalOpacity": 1.0,
    "shellOpacity": 1.0,
    "themeMode": "dark",
    "animationPreset": "fluid",
    "useThemeOverrides": False,
}


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
                return {
                    "sortMode": mode,
                    "themeSettings": normalize_theme_settings(state.get("themeSettings"), ui_theme_defaults()),
                }
        except (OSError, ValueError, TypeError):
            continue
    return {"sortMode": "month", "themeSettings": ui_theme_defaults()}


def ui_theme_defaults():
    defaults = dict(THEME_SETTINGS_DEFAULTS)
    try:
        ui = json.loads(UI_SETTINGS_FILE.read_text(encoding="utf-8"))
        if isinstance(ui, dict):
            defaults["blurEnabled"] = ui.get("backgroundBlur", defaults["blurEnabled"]) is True
    except (OSError, ValueError, TypeError):
        pass
    return normalize_theme_settings(defaults, dict(THEME_SETTINGS_DEFAULTS))


def normalize_theme_settings(settings, defaults=None):
    settings = settings if isinstance(settings, dict) else {}
    defaults = defaults or THEME_SETTINGS_DEFAULTS
    normalized = {
        "blurEnabled": settings.get("blurEnabled", defaults["blurEnabled"]) is True,
        "noiseEnabled": settings.get("noiseEnabled", defaults["noiseEnabled"]) is True,
        "shadowEnabled": settings.get("shadowEnabled", defaults["shadowEnabled"]) is True,
        "sameWindowOpacity": settings.get("sameWindowOpacity", defaults["sameWindowOpacity"]) is True,
        "themeMode": settings.get("themeMode", defaults["themeMode"])
        if settings.get("themeMode", defaults["themeMode"]) in {"dark", "light"}
        else defaults["themeMode"],
        # Existing state files had no override flag. Keep those user's styles
        # until they explicitly choose Reset to defaults.
        "useThemeOverrides": settings.get("useThemeOverrides", bool(settings)),
    }
    bounds = {
        "blurSize": (1, 20, int),
        "blurPasses": (1, 6, int),
        "noiseStrength": (0.0, 1.0, float),
        "rounding": (0, 40, int),
        "borderWidth": (0, 20, int),
        "shadowRange": (0, 40, int),
        "inactiveOpacity": (0.65, 1.0, float),
        "shellOpacity": (0.1, 1.0, float),
    }
    for key, (minimum, maximum, kind) in bounds.items():
        try:
            value = kind(settings.get(key, defaults[key]))
            normalized[key] = max(minimum, min(maximum, value))
        except (ValueError, TypeError, OverflowError):
            normalized[key] = defaults[key]
    try:
        normalized["terminalOpacity"] = max(
            0.65, min(1.0, float(settings.get("terminalOpacity", defaults["terminalOpacity"])))
        )
    except (ValueError, TypeError, OverflowError):
        normalized["terminalOpacity"] = defaults["terminalOpacity"]
    normalized["useThemeOverrides"] = normalized["useThemeOverrides"] is True
    animation_preset = settings.get("animationPreset", defaults["animationPreset"])
    normalized["animationPreset"] = animation_preset if animation_preset in {
        "fast", "fluid", "smooth", "vertical", "none"
    } else defaults["animationPreset"]
    return normalized


def save_state(mode=None, theme_settings=None):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        previous = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        previous = {"sortMode": "month", "themeSettings": ui_theme_defaults()}
    if not isinstance(previous, dict):
        previous = {"sortMode": "month", "themeSettings": ui_theme_defaults()}
    if previous.get("sortMode") not in SORT_MODES:
        previous["sortMode"] = "month"
    if mode is not None and mode not in SORT_MODES:
        raise ValueError("Invalid sort mode")
    state = {
        "sortMode": mode or previous["sortMode"],
        "themeSettings": normalize_theme_settings(theme_settings if theme_settings is not None else previous.get("themeSettings"), ui_theme_defaults()),
    }
    descriptor, temp_path = tempfile.mkstemp(prefix=".wallhaven-state-", dir=STATE_FILE.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as state_file:
            json.dump(state, state_file, indent=2)
            state_file.write("\n")
        os.replace(temp_path, STATE_FILE)
    except Exception:
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise
    return state


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


def write_terminal_theme_files(theme_dir, colors_file, opacity, mode="dark"):
    """Generate Omarchy's per-theme terminal colors and background alpha."""
    try:
        colors_text = Path(colors_file).read_text(encoding="utf-8")
    except OSError:
        colors_text = ""

    def color(name, fallback):
        match = re.search(rf"^\s*{re.escape(name)}\s*=\s*['\"]([^'\"]+)['\"]", colors_text, re.MULTILINE)
        return match.group(1) if match else fallback

    background = color("background", "#1a1b26")
    foreground = color("foreground", "#c0caf5")
    bright_foreground = color("bright_foreground", foreground)
    muted = color("muted", "#565f89")
    selection = color("selection", muted)
    selection_foreground = color("selection_foreground", foreground)
    accent = color("accent", "#7aa2f7")
    purple = color("purple", color("magenta", "#bb9af7"))
    palette_names = (
        "background", "red", "green", "yellow", "blue", "magenta", "cyan", "foreground",
        "muted", "bright_red", "bright_green", "bright_yellow", "bright_blue", "bright_magenta",
        "bright_cyan", "bright_foreground",
    )
    fallback_palette = (
        background, "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", foreground,
        muted, "#ff7a93", "#b9f27c", "#ff9e64", "#7da6ff", "#c0a0ff", "#89ddff", bright_foreground,
    )
    palette = [color(name, fallback) for name, fallback in zip(palette_names, fallback_palette)]
    hex_values = [entry.lstrip("#") for entry in palette]

    kitty_lines = [
        f"foreground {foreground}", f"background {background}",
        f"background_opacity {opacity:.2f}",
        f"selection_foreground {selection_foreground}", f"selection_background {selection}",
        f"cursor {bright_foreground}", f"cursor_text_color {background}",
        f"active_border_color {accent}", f"active_tab_background {accent}",
    ]
    kitty_lines.extend(f"color{index} {value}" for index, value in enumerate(palette))
    atomic_write(Path(theme_dir) / "kitty.conf", "\n".join(kitty_lines) + "\n")

    foot_lines = [
        f"[colors-{mode if mode in {'dark', 'light'} else 'dark'}]", f"foreground={foreground.lstrip('#')}",
        f"background={background.lstrip('#')}", f"alpha={opacity:.2f}",
        f"selection-foreground={selection_foreground.lstrip('#')}",
        f"selection-background={selection.lstrip('#')}",
        f"cursor={background.lstrip('#')} {bright_foreground.lstrip('#')}",
    ]
    foot_lines.extend(f"regular{index}={hex_values[index]}" for index in range(8))
    foot_lines.extend(f"bright{index}={hex_values[index + 8]}" for index in range(8))
    # Foot calls the fifth ANSI color purple; Wallust names that slot magenta.
    foot_lines[foot_lines.index(f"regular5={hex_values[5]}")] = f"regular5={purple.lstrip('#')}"
    atomic_write(Path(theme_dir) / "foot.ini", "\n".join(foot_lines) + "\n")

    ghostty_lines = [
        f"background = {background}", f"foreground = {foreground}",
        f"background-opacity = {opacity:.2f}", f"cursor-color = {bright_foreground}",
        f"selection-background = {selection}", f"selection-foreground = {selection_foreground}",
    ]
    ghostty_lines.extend(f"palette = {index}={value}" for index, value in enumerate(palette))
    atomic_write(Path(theme_dir) / "ghostty.conf", "\n".join(ghostty_lines) + "\n")


def wallust_colors(image, outdir, mode="dark"):
    wallust = shutil.which("wallust")
    if not wallust:
        raise RuntimeError("wallust is required. Install it with: yay -S wallust")
    cfg = Path(tempfile.mkdtemp(prefix="wallhaven-wallust-"))
    try:
        (cfg / "wallust").mkdir()
        (cfg / "wallust" / "templates").mkdir()
        template = '''mode = "__WALLHAVEN_MODE__"
{% if palette == "light" %}
accent = "{{color4 | darken(0.3)}}"
selection = "{{color4 | darken(0.3)}}"
selection_foreground = "{{background}}"
muted = "{{foreground | lighten(0.35)}}"
{% else %}
accent = "{{color4}}"
selection = "{{color8}}"
selection_foreground = "{{foreground}}"
muted = "{{color8}}"
{% endif %}
background = "{{background}}"
dark_background = "{{color0}}"
darker_background = "{{color0}}"
lighter_background = "{{color8}}"
foreground = "{{foreground}}"
{% if palette == "light" %}
dark_foreground = "{{foreground}}"
light_foreground = "{{foreground | lighten(0.2)}}"
bright_foreground = "{{foreground}}"
red = "{{color1 | darken(0.2)}}"
yellow = "{{color3 | darken(0.2)}}"
orange = "{{color11 | darken(0.2)}}"
green = "{{color2 | darken(0.2)}}"
cyan = "{{color6 | darken(0.2)}}"
blue = "{{color4 | darken(0.2)}}"
magenta = "{{color5 | darken(0.2)}}"
brown = "{{color3 | darken(0.2)}}"
bright_red = "{{color9 | darken(0.2)}}"
bright_yellow = "{{color11 | darken(0.2)}}"
bright_green = "{{color10 | darken(0.2)}}"
bright_cyan = "{{color14 | darken(0.2)}}"
bright_blue = "{{color12 | darken(0.2)}}"
bright_magenta = "{{color13 | darken(0.2)}}"
{% else %}
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
{% endif %}
'''
        mode = mode if mode in {"dark", "light"} else "dark"
        template = template.replace("__WALLHAVEN_MODE__", mode)
        (cfg / "wallust" / "templates" / "omarchy-colors.toml").write_text(template)
        (cfg / "wallust" / "wallust.toml").write_text(
            '[templates]\nomarchy = { src = "omarchy-colors.toml", dst = "' +
            str(Path(outdir) / "colors.toml") + '" }\n'
        )
        env = os.environ.copy()
        env["XDG_CONFIG_HOME"] = str(cfg)
        command = [wallust, "run", "--palette", mode]
        if mode == "light":
            # Wallust can adjust ANSI colors for contrast with the light background.
            command.append("--check-contrast")
        command.append(str(image))
        result = subprocess.run(command, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
        colors = Path(outdir) / "colors.toml"
        if result.returncode or not colors.is_file():
            raise RuntimeError(result.stderr.strip() or "wallust did not create colors.toml")
    finally:
        shutil.rmtree(cfg, ignore_errors=True)


def ensure_theme_palette_mode(theme, mode):
    """Regenerate colors.toml from the active wallpaper when mode changes."""
    colors_file = Path(theme) / "colors.toml"
    try:
        colors_text = colors_file.read_text(encoding="utf-8")
    except OSError:
        colors_text = ""
    match = re.search(r'^\s*mode\s*=\s*"(dark|light)"', colors_text, re.MULTILINE)
    if match and match.group(1) == mode:
        return

    backgrounds = (Path(theme) / "backgrounds").resolve()
    current_background = (HOME / ".local/state/omarchy/current/background").resolve()
    if not current_background.is_file() or not current_background.is_relative_to(backgrounds):
        allowed = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
        candidates = sorted(path for path in backgrounds.iterdir()
                            if path.is_file() and path.suffix.lower() in allowed)
        if not candidates:
            raise RuntimeError("No wallpaper found to regenerate the selected color mode")
        current_background = candidates[0]
    wallust_colors(current_background, theme, mode)


def write_theme_styling(theme_dir, colors_file, settings):
    """Write compositor and Omarchy shell styling for the generated theme."""
    settings = normalize_theme_settings(settings)
    try:
        colors_text = Path(colors_file).read_text(encoding="utf-8")
    except OSError:
        colors_text = ""

    def palette_color(name, fallback):
        match = re.search(rf"^\s*{re.escape(name)}\s*=\s*['\"]([^'\"]+)['\"]", colors_text, re.MULTILINE)
        return match.group(1) if match else fallback

    def hypr_rgb(name, fallback):
        value = palette_color(name, fallback)
        if not re.fullmatch(r"#?[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?", value):
            value = fallback
        return value.lstrip("#")[:6].upper()

    window_active_opacity = settings["inactiveOpacity"] if settings["sameWindowOpacity"] else 1.0
    active_border = hypr_rgb("accent", "#FFFFFF")
    active_border_secondary = hypr_rgb("bright_blue", "#FFFFFF")
    inactive_border = hypr_rgb("muted", "#808080")
    lua = f'''-- Generated by abhijeet.wallpaper-picker. Edit through Ctrl+S in the picker.
hl.config({{
  general = {{
    border_size = {settings["borderWidth"]},
    col = {{
      active_border = {{ colors = {{ "rgb({active_border})", "rgb({active_border_secondary})" }}, angle = 45 }},
      inactive_border = "rgba({inactive_border}99)",
    }},
  }},
  group = {{
    col = {{
      border_active = {{ colors = {{ "rgb({active_border})", "rgb({active_border_secondary})" }}, angle = 45 }},
      border_inactive = "rgba({inactive_border}99)",
    }},
  }},
  decoration = {{
    rounding = {settings["rounding"]},
    shadow = {{
      enabled = {str(settings["shadowEnabled"]).lower()},
      render_power = 3,
      range = {settings["shadowRange"]},
      color = "rgba(00000066)",
    }},
    blur = {{
      enabled = {str(settings["blurEnabled"]).lower()},
      size = {settings["blurSize"]},
      passes = {settings["blurPasses"]},
      noise = {settings["noiseStrength"] if settings["noiseEnabled"] else 0.0:.4f},
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
    }},
  }},
}})

-- Blur the picker overlay and Omarchy shell surfaces. Their own alpha is set
-- by the shell section overlays so the compositor blur can show through.
hl.layer_rule({{ match = {{ namespace = "abhijeet-wallhaven" }}, blur = true, ignore_alpha = 0.3 }})
hl.layer_rule({{ match = {{ namespace = "omarchy-osd" }}, blur = true, ignore_alpha = 0.3 }})
hl.layer_rule({{ match = {{ namespace = "omarchy-notifications" }}, blur = true, ignore_alpha = 0.3 }})
hl.layer_rule({{ match = {{ namespace = "omarchy-bar" }}, blur = true, blur_popups = true, ignore_alpha = 0.3 }})
hl.layer_rule({{ match = {{ namespace = "^(omarchy-menu|omarchy-image-selector|omarchy-emojis|omarchy-clipboard|omarchy-keyboard-panel|omarchy-polkit|omarchy-reminders|omarchy-network-qr)$" }}, blur = true, ignore_alpha = 0.3 }})

-- Match the glass window treatment used by blur-theme for Omarchy windows.
o.window({{ tag = "default-opacity" }}, {{ opacity = "{window_active_opacity:.2f} {settings["inactiveOpacity"]:.2f}" }})

{animation_config_lua(settings["animationPreset"])}
'''
    atomic_write(Path(theme_dir) / "hyprland.lua", lua)
    write_terminal_theme_files(theme_dir, colors_file, settings["terminalOpacity"], settings["themeMode"])

    background = palette_color("background", "#1a1b26")
    alpha = f'{settings["shellOpacity"]:.2f}'
    # Per-section overlays keep Omarchy's normal shell defaults while making
    # the surfaces translucent enough for the compositor blur to show through.
    sections = {
        "bar": f'background = "{background}"\nbackground-alpha = {alpha}\n',
        "popups": f'background = "{background}"\nbackground-alpha = {alpha}\n',
        "notifications": f'background = "{background}"\nbackground-alpha = {alpha}\n',
        "launcher": f'background = "{background}"\nbackground-alpha = {alpha}\nscrim-alpha = 0.0\n',
        "menu": f'background = "{background}"\nbackground-alpha = {alpha}\nscrim-alpha = 0.0\n',
        "tooltip": f'background = "{background}"\nbackground-alpha = {alpha}\n',
        "image-picker": f'scrim-alpha = 0.0\n',
    }
    for section, contents in sections.items():
        atomic_write(Path(theme_dir) / f"shell.{section}.toml", contents)


def atomic_write(path, contents):
    path = Path(path)
    descriptor, temp_path = tempfile.mkstemp(prefix=f".{path.name}-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            output.write(contents)
        os.replace(temp_path, path)
    except Exception:
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise


def apply_theme_settings(settings_json):
    try:
        settings = normalize_theme_settings(json.loads(settings_json))
    except (ValueError, TypeError):
        raise ValueError("Invalid wallpaper picker theme settings")
    if not settings["useThemeOverrides"]:
        return reset_theme_settings()
    state = save_state(theme_settings=settings)
    try:
        ui_config = json.loads(UI_SETTINGS_FILE.read_text(encoding="utf-8"))
        if not isinstance(ui_config, dict):
            ui_config = {}
    except (OSError, ValueError, TypeError):
        ui_config = {}
    ui_config.pop("cornerRadius", None)
    ui_config.pop("backgroundOpacity", None)
    ui_config["backgroundBlur"] = settings["blurEnabled"]
    UI_SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(UI_SETTINGS_FILE, json.dumps(ui_config, indent=2) + "\n")
    theme = THEMES / "wallhaven-picker"
    if not (theme / ".wallhaven-picker-managed").is_file():
        return {"settings": state["themeSettings"], "applied": False}

    ensure_theme_palette_mode(theme, settings["themeMode"])
    write_theme_styling(theme, theme / "colors.toml", settings)
    current_theme_file = HOME / ".local/state/omarchy/current/theme.name"
    try:
        current_theme = current_theme_file.read_text(encoding="utf-8").strip()
    except OSError:
        current_theme = ""
    if current_theme == theme.name:
        result = subprocess.run(["omarchy", "theme", "set", theme.name], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Could not apply theme settings")
        return {"settings": state["themeSettings"], "applied": True}
    return {"settings": state["themeSettings"], "applied": False}


def remove_theme_style_overrides(theme):
    style_files = (
        "hyprland.lua", "kitty.conf", "foot.ini", "ghostty.conf", "shell.toml", "shell.bar.toml", "shell.popups.toml",
        "shell.notifications.toml", "shell.launcher.toml", "shell.menu.toml",
        "shell.tooltip.toml", "shell.image-picker.toml",
    )
    for name in style_files:
        try:
            (theme / name).unlink()
        except FileNotFoundError:
            pass


def reset_theme_settings():
    """Delete generated overrides so Omarchy's base theme values take effect."""
    settings = dict(THEME_SETTINGS_DEFAULTS)
    settings["themeMode"] = load_state().get("themeSettings", {}).get("themeMode", "dark")
    state = save_state(theme_settings=settings)
    try:
        ui_config = json.loads(UI_SETTINGS_FILE.read_text(encoding="utf-8"))
        if not isinstance(ui_config, dict):
            ui_config = {}
    except (OSError, ValueError, TypeError):
        ui_config = {}
    ui_config.pop("cornerRadius", None)
    ui_config.pop("backgroundOpacity", None)
    ui_config["backgroundBlur"] = settings["blurEnabled"]
    UI_SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(UI_SETTINGS_FILE, json.dumps(ui_config, indent=2) + "\n")

    theme = THEMES / "wallhaven-picker"
    if not (theme / ".wallhaven-picker-managed").is_file():
        return {"settings": state["themeSettings"], "applied": False, "reset": True}
    ensure_theme_palette_mode(theme, settings["themeMode"])
    remove_theme_style_overrides(theme)
    current_theme_file = HOME / ".local/state/omarchy/current/theme.name"
    try:
        current_theme = current_theme_file.read_text(encoding="utf-8").strip()
    except OSError:
        current_theme = ""
    if current_theme == theme.name:
        result = subprocess.run(["omarchy", "theme", "set", theme.name], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Could not reset theme styling")
        return {"settings": state["themeSettings"], "applied": True, "reset": True}
    return {"settings": state["themeSettings"], "applied": False, "reset": True}


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
        theme_settings = load_state().get("themeSettings")
        wallust_colors(staged_image, staging, theme_settings.get("themeMode", "dark"))
        if theme_settings.get("useThemeOverrides", True):
            write_theme_styling(staging, staging / "colors.toml", theme_settings)
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
            value = sys.argv[2] if len(sys.argv) > 2 else ""
            result = save_state(value if value in SORT_MODES else None)
        elif action == "apply-settings":
            result = apply_theme_settings(sys.argv[2] if len(sys.argv) > 2 else "{}")
        elif action == "reset-settings":
            result = reset_theme_settings()
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
