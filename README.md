# Open Doors — The Blood of Dawnwalker Mod

> **Freedom to enter. Freedom to leave.**

**Open Doors** is a quality-of-life and immersion mod for *The Blood of Dawnwalker*. It eliminates artificial door lockouts, self-shutting gates, and invisible walls that trap the player upon crossing an interior threshold.

---

## Why Open Doors?

In *The Blood of Dawnwalker*, walking through an open door into a guard post, watchtower, or fortress often triggers an instant, phantom door closure behind you. Even if you pushed the door open yourself and no guard bolted it shut, the game seals the entrance and places an invisible barrier, preventing you from backing out.

This restricts tactical freedom and breaks immersion:
- **Tactical Retreat**: If you peek into a room and realize you are outmatched, you should be able to retreat, regroup, and plan a better attack.
- **No Phantom Mechanisms**: Doors shouldn't magically slam shut just because you took two steps past the doorframe. If an entrance was open, it stays open.
- **Natural Exploration**: Scout ahead and draw enemies out into open terrain without getting locked in an artificial killbox.

---

## Features & Goals

- **Persistent Open Doors**: Doors remain open after entering rooms, towers, and fortresses.
- **Barrier Removal**: Disable invisible doorway collision volumes triggered on entry.
- **Immersion Preserved**: Story-driven locked doors (requiring keys or scripted narrative events) remain untouched.

---

## Development Setup & Linking

This repository uses relative paths for all tools and scripts to keep personal machine paths private when publishing to GitHub.

To work with this repository, the game installation directory must be linked via a Windows directory junction:

```cmd
mklink /J game "<path-to-your-Dawnwalker-folder>"
```

Once linked, all tools and documentation reference `game/` (e.g. `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe`). The `game/` folder is excluded by `.gitignore` and is never committed.

---

## Technical Documentation

- **[GroundTruth.md](GroundTruth.md)**: Live technical state, engine specifications, and active mod architecture.
- **[Changelog.md](Changelog.md)**: Iteration log tracking added features, changes, and deprecations.
- **[AGENTS.md](AGENTS.md)**: Guidelines for AI agent contributions.
