# Changelog

## 1.0.0 (Nov 20, 2026)

First release, part of the Frost Suite.

- `LANCE`, `BLAST` or `WAIT n` for Ice Lance and Fire Blast's shared cooldown (8 seconds; 15 for the second set of Fire
  Blast spells in the game's data), timed from your own casts.
- Fingers of Frost from the buff when readable, otherwise from the game's own Ice Lance spell alert. When neither can be
  seen, the box shows the timer and `READY` (`timer only: Fingers hidden`), never a guessed verdict.
- Frozen target from Frost Nova / Frostbite on your target only when the game lets addons read it.
- Cold Snap is not assumed to reset Fire Blast. `/frost lance debug`. Docks with the other Frost Suite boxes.
