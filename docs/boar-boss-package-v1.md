# ReBite Boar Boss Package v1

This package contains the design brief and final art assets for the ReBite boar boss encounter.

## Contents

- `docs/boar-boss-implementation-brief.md`
  - Encounter objective, rules, class boundaries, state machines, events, and acceptance tests
- `assets/gimmicks/`
  - Corrected transparent gimmick sprite sheets and 36 individual frames
  - `manifest.json` defines frame sizes, names, and the stopper pivot
- `assets/boss_intro/`
  - Transparent intro sprite sheets and 19 individual frames
  - `manifest.json` defines frame sizes and anchors
  - `intro_timeline.json` defines the four-second intro sequence
- `references/`
  - Original player, boar, and rock references
  - Wide stage concept illustration

## Import settings

- Use nearest-neighbor filtering
- Disable texture filtering and mipmaps
- Preserve PNG alpha
- Use the frame sizes and anchors from each `manifest.json`
- Render the boss name and DASH/SMASH labels with the game's existing font rather than baking text into sprites

Files in `references/` are visual references. Production-ready transparent assets are under `assets/`.
