<img width="1155" height="440" alt="player_status_youtube" src="https://github.com/user-attachments/assets/11f9729f-1a21-4f8d-be63-0dbbece6f256" />
# PlayerStatus — Rainmeter Now Playing Widget

A minimal Rainmeter widget that shows what's currently playing — track
title, artist, and a live animated waveform reacting to your actual
system audio.

Works with:
- **Windows Media Player**
- **Browser tabs** playing audio (YouTube Music, Spotify Web, etc.),
  via Windows' own System Media Transport Controls (SMTC) — the same
  thing that powers the media flyout on your volume icon

No background, no separator lines — just text and a waveform, sitting
directly on your desktop/wallpaper.

## How it works

Two pieces work together:

1. **`GetNowPlaying.ps1`** — a small PowerShell script that polls
   Windows' SMTC once a second, figures out what's actually playing,
   and writes it to a plain-text `nowplaying.json` file next to itself.
2. **`PlayerStatus.ini`** — the Rainmeter skin. It reads that JSON file
   for the title/artist, and separately reads real audio output levels
   (via Rainmeter's built-in `AudioLevel` plugin) to animate the bars.

Rainmeter alone can't see into browser tabs or run Windows' media APIs,
which is why the PowerShell helper exists as a bridge.

## Requirements

- Windows 10 or 11
- [Rainmeter](https://www.rainmeter.net/) installed (the `AudioLevel`
  plugin ships with it by default)
- PowerShell (built into Windows — nothing extra to install)

## Setup

1. **Download this folder** and place it at:
   ```
   Documents\Rainmeter\Skins\PlayerStatus\
   ```
   All three files (`PlayerStatus.ini`, `GetNowPlaying.ps1`,
   `RunHidden.vbs`) need to stay together in the same folder.

2. **Unblock the files.** Since they came from a downloaded/cloned
   repo, Windows may flag them as untrusted and block them from
   running. Right-click each of `RunHidden.vbs` and `GetNowPlaying.ps1`
   → **Properties** → check **Unblock** at the bottom of the General
   tab → OK.

   Or do it for the whole folder at once in PowerShell:
   ```powershell
   Get-ChildItem "C:\path\to\PlayerStatus" -Recurse | Unblock-File
   ```

3. **Start the background helper.** Double-click `RunHidden.vbs`.
   Nothing will visibly happen — that's expected, it runs silently.
   Confirm it's working by opening Task Manager → Details tab and
   checking for a `powershell.exe` process.

4. **Make it start automatically at login:**
   - Press `Win+R`, type `shell:startup`, hit Enter
   - Right-click `RunHidden.vbs` → **Create shortcut**
   - Drag that **shortcut** into the Startup folder

   Important: put a *shortcut* in Startup, not a copy of the actual
   `.vbs` file. The script finds `GetNowPlaying.ps1` by looking in its
   own folder — a raw copy sitting in Startup would look for the
   PowerShell script there and fail silently.

5. **Load the skin in Rainmeter:**
   - Right-click the Rainmeter tray icon → **Refresh all**
   - Right-click the tray icon → **Skins** → **PlayerStatus** →
     `PlayerStatus.ini`

6. Play something — WMP, or a music tab in Chrome/Edge — and the
   widget should update within a second or two.

## Customizing

Everything below is edited directly in `PlayerStatus.ini`, then applied
by right-clicking the widget → **Refresh skin** (or refresh all from
the tray icon).

### Colors

In the `[Variables]` section:
```ini
TitleColor=255,255,255,235
ArtistColor=255,255,255,150
WaveColor=255,255,255,200
```
Format is `R,G,B,A` (each 0–255). The last number is opacity — lower
means more transparent.

### Font

In `[MeterTitle]` and `[MeterArtist]`:
```ini
FontFace=Segoe UI Light
FontSize=17
StringStyle=Normal
```
- `FontFace` — any font installed on your system, must match the exact
  name. For a thinner look, use a Light/Thin *variant* of a font (e.g.
  `Segoe UI Light`, `Inter Light`) — `StringStyle` only supports
  `Normal` / `Bold` / `Italic` / `BoldItalic`, it has no thin option.
- `FontSize` — bigger number = bigger text

### Waveform bar height

```ini
BarMaxH=34
```
One line, controls all bars at once.

### Waveform bar count

Each bar is its own `[MeasureBandXX]` + `[MeterBarXX]` pair, so adding
more means duplicating blocks (bump `BandIdx` for each new measure,
reference the matching measure in each new meter) and updating both
`Bands=` in `[MeasureAudio]` and `BarCount=` in `[Variables]` to match
the new total. More bars at a fixed width take up more horizontal
space — check it still fits your layout.

### Bar spacing / width

```ini
BarW=1
BarGap=3
```
`BarW` is each bar's width, `BarGap` is the space between them.

### Spacing between rows

Each text row has a fixed `Y=` value — increase it to push that row
down (more gap above it):
```ini
[MeterTitle]
Y=46
...
[MeterArtist]
Y=90
```

## Limitations

- **Windows only knows which *app* is playing something, not which
  *website*.** SMTC has no concept of tabs, so there's no way to
  restrict this to one specific site (e.g. only `music.youtube.com`)
  at the OS level. The script works around this by only picking up
  sessions that report a real Artist tag — YouTube Music always sets
  one, while most other browser media (video sites, autoplay clips)
  doesn't — but it's a heuristic, not a guarantee.
- Elapsed playback time isn't shown — Windows' timeline API for SMTC
  sessions proved unreliable across different apps and was dropped.

## Resource usage

The PowerShell helper idles at roughly 20–40MB of RAM and negligible
CPU (it wakes up once a second, checks state, writes a few bytes,
sleeps). Rainmeter's own footprint for this skin is a few MB. Combined
impact is not something you'd notice on any modern machine.

## Troubleshooting

**Widget shows nothing / frozen on an old song**
Check Task Manager for a `powershell.exe` process. If it's not there,
the helper isn't running — double-click `RunHidden.vbs` again.

**Windows blocks `RunHidden.vbs` with a warning when you double-click it**
See step 2 above (Unblock).

**PowerShell shows an execution policy error when run manually**
Run it with `-ExecutionPolicy Bypass` explicitly:
```powershell
powershell -ExecutionPolicy Bypass -File .\GetNowPlaying.ps1
```
(`RunHidden.vbs` already does this automatically.)

**Text looks cut off at the bottom**
Increase that meter's `H=` value in the `.ini` — Rainmeter's window
canvas is sized from each meter's declared height, so a font that
needs more vertical room than `H` specifies gets clipped at the window
edge even with `NoClip=1` set.
