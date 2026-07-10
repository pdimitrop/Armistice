# Armistice

A 3D WW1-themed football (soccer) game built in **Godot 4.7** (Forward+ renderer).
Players take the side of either the Allied Powers (Entente) or the Central Powers
and kick a ball around a muddy, war-torn pitch of trenches, sandbags, tombstones,
snow and ruins.

Undergraduate thesis (πτυχιακή) — **Paraskevas I. Dimitropoulos**, University of
Piraeus, 2026. Licensed under the MIT License (see [`LICENSE`](LICENSE)).

---

## ⚠️ Getting the full, runnable project

**This Git repository contains the source code only** — GDScript, scenes, project
configuration, shaders and localisation. The 3D models, textures and audio under
`Assets/` (~12 GB, with many files exceeding GitHub's 100 MB per-file limit) are
**not** stored here.

To open and *play* the game you need the complete bundle, delivered separately as
a zip:

> **Full project download:** _<paste your Google Drive link here>_

Unzip it, and the `Assets/` folder will sit alongside the folders in this repo.
On first open, Godot regenerates its own `.godot/` import cache automatically.

---

## How to run

1. Install **Godot 4.7** (.NET / Forward+ build).
2. Obtain the full project (see above) so that `Assets/` is present.
3. Open the project folder in Godot — `project.godot` is the entry point.
4. Press **Play**. The game boots at `Intro.tscn` and flows:
   `Intro → Intro1 → Intro2 → MainMenu → SideSelection → Loading → Main` (the 3D pitch).

### Controls
| Key | Action |
|-----|--------|
| Arrow keys | Move the selected player |
| **Z** | Pass (within 2.5 m of the ball) |
| **X** | Shoot (within 2.5 m of the ball) |
| **Q** | Switch selected player |
| **Esc** | Pause / menu |

---

## Project structure

| Path | Contents |
|------|----------|
| `Script/` | All GDScript gameplay & UI logic |
| `Scenes/` | `.tscn` scene files (menus, intro chain, `Main.tscn` pitch) |
| `lang/` | `localisation.csv` (source of truth) + generated `.translation` files |
| `addons/fuku/` | Editor-only AI assistant plugin (not used by gameplay) |
| `Assets/` | 3D models, textures, audio — **delivered separately** (see above) |
| `project.godot` | Godot project definition & input map |

The game supports 10 locales; strings live in `lang/localisation.csv`.

---

## Notes for reviewers

- Language: **GDScript** (the `[dotnet]` section in `project.godot` is a build
  target only — there is no C# in `Script/`).
- Renderer: Forward+, Jolt Physics 3D, 1920×1080.
- There is no external build step, test suite or CI — opening the project in
  Godot and pressing Play is the full workflow.
