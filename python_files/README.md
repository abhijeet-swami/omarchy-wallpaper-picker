# Picker helper modules

`picker_core.py` contains the API, cache, state, and theme operations called by the QML UI. `animation.py` reads a selected standalone Lua preset from `animation/` and embeds it in the generated theme's `hyprland.lua`. The root `wallpaper.py` is the stable command-line entry point used by the plugin.

To add or tune a preset, add a `.lua` file in `animation/`, register its name in `animation.py` and in the QML preset list, then bump the manifest version. Every theme write builds a fresh `hyprland.lua` from the common rules plus exactly one selected preset; there is no old animation sidecar to linger between selections.
