# Eight Second Argument

A tiny Frost Mage box for **WoW: Forever** (Interface 16001). Version 1.0.1. Part of Kenny's Frost Suite, and it works alone.

Official Nov 2, 2026 notes gave Ice Lance **an 8-second cooldown shared with Fire Blast**. The game's own data agrees: every
Ice Lance rank and Fire Blast ranks 1-7 share one cooldown category at 8 seconds. Pressing Fire Blast while Ice Lance would
shatter wastes its 300% bonus. This box says one word:

| Word | Means |
| --- | --- |
| `LANCE` | the shared cooldown is free and Fingers of Frost is up or your target is Frozen |
| `BLAST` | the shared cooldown is free and neither is up (or you're moving and Fingers is known to be down) |
| `WAIT 3` | the shared cooldown is running, counted from your own last Ice Lance or Fire Blast |
| `READY` | the cooldown is free, but the game is hiding whether Fingers or a freeze is up, so no guess |

It's a verdict for one button pair, not a rotation helper. It never casts anything. It doesn't glow or play sounds.

Cold Snap is **not** assumed to reset Fire Blast, because the official text doesn't say it does. The game's data also lists a
second set of Fire Blast spells (IDs 400616, 400618-400623) on the same cooldown at 15 seconds. If you cast one of those, the
box waits 15.

## What the game lets it see

| Thing | How it's read | When the game hides it |
| --- | --- | --- |
| The shared cooldown | your own Ice Lance / Fire Blast casts | the box says `can't see your casts here` and gives no verdict |
| Fingers of Frost | the buff, if the game lets addons read it right now; otherwise the game's own spell alert on Ice Lance | `timer only: Fingers hidden`: the box shows the timer and `READY`, never LANCE or BLAST from a guess |
| Frozen target | Frost Nova / Frostbite on your target, if readable right now | treated as unknown (never as "not frozen") |

No alert doesn't count as "no Fingers" until this character has seen the game's Ice Lance alert at least once.

## Commands

The Frost Suite has no per-addon slash commands, only `/frost <sub>`. That keeps the risk of clashing with other addons low.

- `/frost lance debug`: what the game lets the addon see right now
- `/frost lock | unlock | scale 0.8-1.4 | reset | debug`: the shared dock

## Checks

`tests/run.sh <wow-ui-source>`, `tools/verify_unit_events.py <wow-ui-source>`, `tools/check_suite_lib.sh <frost-suite-lib folder>`, `tools/verify_media.sh`.
Spell IDs and cooldowns come from the game's data tables (SpellName, SkillLineAbility, SpellCategories, SpellCooldowns) for
build 1.60.1.70862.

MIT licence. Uses the game's own textures only.
