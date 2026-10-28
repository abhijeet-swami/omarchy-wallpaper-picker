# Wallpaper Picker

A small Omarchy overlay for browsing Wallhaven or wallpapers already in `~/Wallpapers`. It opens in local mode. Pick a wallpaper and apply it as an Omarchy theme; Wallust generates the colors.

## Install

Wallust is required:

```bash
yay -S wallust-bin
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
| Esc | Close the picker |

Wallhaven results continue into adjacent pages as you scroll. At the beginning and end of the result set, scrolling stops instead of wrapping. In local mode, search filters filenames. Alt+M cycles through month, year, week, and recent for an empty search; with a search, it switches between relevance and top results.

## Appearance

Edit `~/.config/omarchy/plugins/abhijeet.wallpaper-picker/ui-config.json`:

```json
{
  "cornerRadius": 14,
  "bottomOffset": 0,
  "backgroundOpacity": 1.0,
  "backgroundBlur": false
}
```

`cornerRadius` sets the dock, search bar, and thumbnail rounding; use `0` for square corners. `bottomOffset` moves the dock up from the screen edge in pixels. `backgroundOpacity` ranges from `0.0` (transparent) to `1.0` (opaque). Set `backgroundBlur` to `true` to request blur behind the dock. Hyprland's compositor blur must also be enabled for that setting to take effect. Settings reload when the file changes.
