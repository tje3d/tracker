# Changelog

All notable changes to **Tracker**, a modular class HUD for World of Warcraft
3.3.5a (WotLK). Newest first.

## 1.5.0 — 2026-10-04

### Added
- **PaladinTracker** — a Retribution Paladin module. Seals and auras form
  exclusive groups, Art of War procs and Judgement of the Wise are watched,
  mana gets a bar, and a `MISSING: SEAL + AURA` line warns when upkeep drops.
- **Rotation queue** — a new optional engine feature (`rotation` in a module's
  config). PaladinTracker uses it to show the next spells to cast, Clash-system
  style: soonest-ready first with the configured priority as the tie-break, the
  next ready spell glowing, unaffordable spells tinted blue, and cooldowns swept
  with their timers. Entries can be gated to execute range (`execute`) or an
  undead target (`undeadOnly`), and a buff swaps in a separate AoE list
  (`aoeBuff` / `aoeList`).
- PaladinTracker ships the Retribution Clash priority — Hammer of Wrath
  (execute), Judgement, Divine Storm, Crusader Strike, Consecration, Exorcism,
  Holy Wrath (undead only) — with an AoE order while Seal of Command is up.

### Changed
- The `auras` warning type understands `family`: mutually exclusive buffs such
  as seals and auras are reported only when none of the group is up, instead of
  one line per missing member.

## 1.4.1 — 2026-10-04

### Fixed
- The HUD no longer eats clicks on the action bars. Its container frame was a
  fixed 500 px tall and anchored by its centre, so while unlocked the invisible
  lower half hung over the bars. It now shrinks to fit exactly what it draws.
- The frame is anchored by its top edge, so growing or shrinking it never moves
  the icons. Existing saved positions are migrated automatically, and
  `/tracker reset` lands on the same spot as before.

## 1.4.0 — 2026-10-04

### Added
- `/tracker scale <0.5 - 2.0>` resizes the whole HUD — icons, bars and the
  warning line together. The size is stored per character.

### Fixed
- `/tracker scale` now exists. It was advertised on the docs page, but the core
  had no such command, so every attempt silently did nothing.

### Notes
- Forgiving input: `1.2`, `1,2` (comma decimal), `<1.2>` (the placeholder
  brackets) and `scale N 1.2` all resolve to the size you meant — the first
  number in the line wins.
- `/tracker scale up` and `/tracker scale down` step the size by 0.1.
- A bare `/tracker scale` prints the current size.
- `lock` / `unlock` / `reset` are unchanged.

## 1.3.1 — 2026-10-03

### Changed
- Addon titles now use the DBM-style coloured format: yellow `<Tracker>`
  brackets with class names in WoW class colours.

## 1.3.0 — 2026-10-01

### Added
- Hysteria is shown by every tracker, not just Death Knights, drawn at the
  larger icon size.

### Changed
- Rogue Rupture is caster-checked — only your own bleed on the target counts.
- Removed the alpha blink on abilities in their final seconds. Timers, the
  cooldown sweep and grey upkeep reminders are unchanged, and cooldowns still
  glow when they come back up.

### Docs
- README and landing page refreshed for the above.

## 1.2.0 — 2026-09-30

### Added
- DKTracker: tracks the **Desolation** buff (Unholy talent proc). It has no
  spellbook entry, so it is built up front and matches any rank by aura name.
- DKTracker: **Mark of Blood** cooldown.

## 1.1.1 — 2026-09-30

### Changed
- `/tracker` handles only `lock`, `unlock` and `reset`. The testing/utility
  subcommands are gone: `rebuild`, `force`, `debug`, `debugauras`, `debugglow`,
  `forceglow`, `scale`, `sweep`.

### Removed
- Dead code behind those commands and the unused per-module debug hooks.
- Comment tidy-up across the core and class modules.

## 1.1.0 — 2026-09-30

### Added
- Top-to-bottom cooldown sweep (ElvUI nameplate style), replacing the circular
  clock hand. `/tracker sweep <1-4>` tuned the shade opacity.
- Variable-size icons: auras grow to their configured size while active and
  shrink back for greyscale upkeep reminders.

### Changed
- DKTracker: dropped Chain of Ice and rebalanced the cooldown rows.
- PriestTracker: removed Mind Blast and Vampiric Embrace.
- WarlockTracker: Fel Armor / Demon Armor now form an exclusive group; Haunt
  repositioned.

## 1.0.0 — 2026-09-29

### Added
- Initial release: TrackerCore engine plus Rogue, DK, Hunter, Mage, Priest,
  Warrior, Warlock and Druid modules, with the shared `/tracker` command.
