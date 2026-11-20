# Changelog

## 1.0.1 (Nov 20, 2026)

- Layout fixes (FrostSuite-1.0 r4, shared by the suite): a status too long to sit beside the title moves to its own line instead of running into it, and box heights fit their text.
- Box is 78 px in combat, so the `Frozen target hidden` line sits inside it.
- Low-level Mages (FrostSuite-1.0 r6, shared by the suite): until you have Fire Blast and Ice Lance the box shows one calm line, e.g. `Learn Fire Blast at level 6`, with a small **Hide until I learn** button (saved per character). It steps aside in combat and comes back by itself as soon as you learn them (checked when you learn a spell, level up, change talents or leave combat). The timer only runs once both are known.

## 1.0.0 (Nov 20, 2026)

First release, part of the Frost Suite.

- `LANCE`, `BLAST` or `WAIT n` for Ice Lance and Fire Blast's shared cooldown (8 seconds; 15 for the second set of Fire
  Blast spells in the game's data), timed from your own casts.
- Fingers of Frost from the buff when readable, otherwise from the game's own Ice Lance spell alert. When neither can be
  seen, the box shows the timer and `READY` (`timer only: Fingers hidden`), never a guessed verdict.
- Frozen target from Frost Nova / Frostbite on your target only when the game lets addons read it.
- Cold Snap is not assumed to reset Fire Blast. `/frost lance debug`. Docks with the other Frost Suite boxes.
