# Federfeuer (working title)

## Game design
- `docs/game_design.md` is the authoritative reference for all game mechanics,
  values and decisions. Read it before changing gameplay code.
- If the code and the document disagree, ask instead of silently changing either one.

## Keeping the document up to date
- When a change affects mechanics, balancing values, enemies, weapons, items or
  the game flow, update `docs/game_design.md` in the same commit.
- Values in the document must match `lib/game/config.dart`.
- Add new decisions to the matching section; mark resolved questions as decided
  under "Offene Punkte & Roadmap".
- Leave unaffected sections unchanged.