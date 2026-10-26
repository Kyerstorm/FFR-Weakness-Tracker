# WeaknessTracker

A UE4SS Lua mod for **FINAL FANTASY RESONANCE** that shows which elements you've already tried on an enemy, including the ones that did **neutral** damage. Out of the box, the enemy **Affinities** panel (**Display Unit Info**) only lists weaknesses and resistances, so after trying Wind, Light and Dark on a fire-weak monster there's no record of which ones you've used. With this mod, every neutral element you've tried appears in the panel as a plain element icon, next to the game's own weakness and resistance icons.

| Element | How it appears in the Affinities panel |
|---|---|
| Weakness / Halved / Invalid / Absorb | As shipped: the resistance icon with the element, or **?** until you find it |
| **Neutral, tried** | **The plain element icon** (no resistance icon) |
| Neutral, not tried yet | Hidden (set `ShowUntested = true` to show them as **?**) |

Elements you try are remembered per monster type by the game itself, so a monster you've tested shows its neutral elements in every later battle, on that save.

## Settings
Open `WeaknessTracker/config.ini`. Restart the game to apply a change.

```ini
NeutralRow = true
ShowUntested = false
Debug = false
```

- `NeutralRow`: `false` leaves the Affinities panel exactly as the game ships it.
- `ShowUntested`: `true` also shows neutral elements you haven't tried yet, as **?**, the way the game shows unrevealed weaknesses.
- `Debug`: `true` writes every neutral entry the panel draws to `UE4SS.log`.

## How it works
The game already records every element you hit a monster with, neutral ones included, in your save data (per monster type). The panel draws only the resistance types listed in `DisplayResistanceList` of the data asset `/Game/UI/Common/Resistance/Data/DA_UI_Resistance`, and neutral (`eResistance::None`) isn't one of them. The mod adds it in memory, so each enemy's element list now includes its neutral elements, revealed or **?**.

Neutral has no icon of its own in that asset, so on its own it would be drawn with the Weakness icon. The mod hooks `SetResistData` on the panel entry widget `WBP_BtlSkillResistEntry` and, for neutral entries, hides the resistance icon (tried) or the whole entry (not tried yet). The game reuses these widgets, so anything the mod hid is put back when the same widget later shows a weakness or resistance. No game files are modified.

## Requirements
- **UE4SS v4** (a release supporting UE 5.6) from the official project: https://github.com/UE4SS-RE/RE-UE4SS/releases
- No other mod tools are required.

## Install
1. Extract UE4SS into `<game>/FFRS/Binaries/Win64/`. You should end up with `dwmapi.dll` and a `ue4ss/` folder next to `FFRS-Win64-Shipping.exe`.
   - UE4SS uses `dwmapi.dll`, so it does not conflict with ReShade/Luma's `dxgi.dll`.
2. Copy the `WeaknessTracker` folder into `<game>/FFRS/Binaries/Win64/ue4ss/Mods/`.
3. Enable it **one** way only: either add `WeaknessTracker : 1` to `ue4ss/Mods/mods.txt` (above the `Keybinds` line) and delete the mod's `enabled.txt`, or leave `enabled.txt` in place and don't list it in `mods.txt`.
4. Launch the game. `ue4ss/UE4SS.log` should show `[WeaknessTracker] loaded`, and, the first time you open an enemy's info in battle, `[WeaknessTracker] hooked .../WBP_BtlSkillResistEntry_C:SetResistData`.

## Uninstall
Delete `ue4ss/Mods/WeaknessTracker/`. Nothing is written to your save, so the panel goes back to normal right away. To remove UE4SS entirely, delete `dwmapi.dll` and `ue4ss/` from `Win64`.

## Troubleshooting
- **No neutral elements appear:** check `UE4SS.log` for `[WeaknessTracker] added the Neutral row`. If that line never appears, the data asset wasn't found (a patch may have renamed it). Also check that `NeutralRow` isn't set to `false`.
- **Neutral elements show the Weakness icon:** check `UE4SS.log` for `could not hook`. The mod then fixes the icons once a second instead, so they may show the wrong icon briefly when the panel opens.
- **An element I hit isn't shown:** the game only records an element once a hit with it lands on that monster. A miss or a fully blocked hit may not count.
- **The game crashes on launch after updating UE4SS or the game:** delete `ue4ss/Mods/WeaknessTracker/` and report the UE4SS version and the end of `UE4SS.log`.
