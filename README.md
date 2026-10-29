# Wallpaper Picker

A small Omarchy overlay for browsing Wallhaven or wallpapers already in `~/Wallpapers`. It opens in local mode. Pick a wallpaper and apply it as an Omarchy theme; Wallust generates the colors.

## Install

Wallust is required:

```bash
yay -S wallust
```

Then install the plugin with Omarchy:

```bash
omarchy plugin add https://github.com/abhijeet-swami/omarchy-wallpaper-picker.git --enable
```

Open the picker with `omarchy-shell shell summon abhijeet.wallpaper-picker '{}'`.

To open it with a keybinding, add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + W", "Wallpaper Picker", "omarchy-shell shell summon abhijeet.wallpaper-picker \"{}\"")
```

## Keys

| Key | Action |
| --- | --- |
| Left / Right | Select a wallpaper |
| Mouse wheel | Scroll through Wallhaven results |
| Click a thumbnail | Select it |
| Enter | Apply the selected wallpaper |
| Alt+1 | Switch to local wallpapers |
| Alt+2 | Switch to Wallhaven |
| Alt+S | Search |
| Alt+D | Download the selected Wallhaven image to `~/Wallpapers` |
| Alt+Left / Alt+Right | Jump one Wallhaven results page |
| Alt+P | Jump to a Wallhaven page number |
| Alt+M | Change sorting |
| Ctrl+S | Open appearance settings |
| Esc | Close the picker |

Wallhaven results continue into adjacent pages as you scroll. At the beginning and end of the result set, scrolling stops instead of wrapping. In local mode, search filters filenames. Alt+M cycles through month, year, week, and recent for an empty search; with a search, it switches between relevance and top results.

## Appearance

Press **Ctrl+S** in the picker to adjust the appearance used by the generated Omarchy theme:

- Blur enable, size, and passes
- Window rounding (also used by the picker), shadow range, and inactive-window opacity
- A separate Kitty, Foot, and Ghostty opacity slider, with an option to match active and inactive opacity
- Four distinct workspace animation styles, plus no animation
- Omarchy shell opacity; the picker uses the same surface color and opacity as the rest of the shell

The terminal opacity slider sets the inactive opacity for Kitty, Foot, and Ghostty. With **Terminal active/inactive same** enabled, the slider applies to both states; with it disabled, active terminals stay fully opaque.

The spring preset uses the `dampening` property expected by Hyprland 0.56.x.

Press **Apply** to save the values in `~/.config/omarchy/wallhaven-picker-state.json`. If the generated Wallpaper Picker theme is active, it is applied immediately; otherwise the values are used the next time you apply a wallpaper. **Reset to defaults** removes the generated Hyprland and shell overrides so Omarchy's defaults take effect, and keeps that choice for future wallpapers.

The theme includes a Wallust-generated `colors.toml`, `hyprland.lua` for compositor blur/rounding/shadows, and small `shell.<section>.toml` overlays so Omarchy surfaces can show the blur while keeping its normal shell defaults. Other files from `blur-theme` (terminal and editor configs, for example) are optional and are not needed for wallpaper theming.

## Source layout

`WallpaperPicker.qml` owns picker state and key handling. The UI is split into `components/LocalWallpaperGallery.qml`, `components/WallhavenGallery.qml`, `components/WallpaperCarousel.qml`, `components/SettingsPanel.qml`, and `components/SearchBar.qml`. The root `wallpaper.py` is the stable command entry point; `python_files/picker_core.py` handles the API, state, cache, Wallust, and theme work, while `python_files/animation/` contains the standalone Hyprland Lua presets copied into the generated `hyprland.lua`.

The picker's dock-specific settings remain in `~/.config/omarchy/plugins/abhijeet.wallpaper-picker/ui-config.json`:

```json
{
  "bottomOffset": 0,
  "backgroundBlur": false
}
```

`bottomOffset` moves the dock up from the screen edge in pixels. The window-rounding slider in Ctrl+S also controls the picker dock, search bar, and thumbnails. Set `backgroundBlur` to `true` to request blur behind the dock. Hyprland's compositor blur must also be enabled for that setting to take effect. Settings reload when the file changes.
