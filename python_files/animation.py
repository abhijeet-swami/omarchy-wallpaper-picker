"""Load a selected, standalone Hyprland animation snippet."""

from pathlib import Path

ANIMATION_DIR = Path(__file__).with_name("animation")
PRESETS = {"fluid", "smooth", "fast", "vertical", "none"}


def animation_config_lua(preset):
    """Return the complete animation block embedded in generated hyprland.lua."""
    if preset not in PRESETS:
        preset = "soft-pop"
    return (ANIMATION_DIR / f"{preset}.lua").read_text(encoding="utf-8").strip()
