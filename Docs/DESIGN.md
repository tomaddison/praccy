# Design

The feel of Praccy is part of the product. A few principles guide every screen:

- **Calm over hype.** No exclamation marks, no streak-shaming, no pushy notifications. A full stop is always enough.
- **Chunky and legible.** Nunito Black/ExtraBold, large rounded shapes, every tappable ≥ 44×44pt. Children read every string; teachers skim them.
- **Snap, don't animate state.** Only physical motion (metronome beat, beat-dot reflow, mascot pendulum) is animated. State changes are instant.
- **Mascot carries the warmth.** Tempo (the kiwi) is the brand. No emojis in UI strings; the mascot and chunky shapes carry the tone.
- **The teacher–student loop is the product.** Every surface assumes a real human on the other side. Solo mode is not supported and not a roadmap item.

**Typography:** Nunito Black for display, headlines, eyebrows; Nunito ExtraBold for task titles and CTAs; Nunito Bold for meta. The full scale lives in `Extensions/Font+Praccy.swift`:

| Role     | Size | Weight     | Tracking | Use                                |
| -------- | ---- | ---------- | -------- | ---------------------------------- |
| display  | 56   | Black      | -2       | Hero number on the streak sheet    |
| title    | 30   | Black      | -0.6     | Screen titles                      |
| section  | 20   | Black      | -0.3     | Section headers                    |
| task     | 17   | ExtraBold  | -0.2     | Task card titles, body CTAs        |
| meta     | 16   | Bold       | 0        | Caption rows, metadata             |
| eyebrow  | 14   | Black      | +1 (uc)  | Uppercase eyebrow labels           |

All scales are `relativeTo:` a UIKit text style so Dynamic Type preserves the hierarchy at AX sizes.

## Core palette

| Name         | Hex       | Usage                                            |
| ------------ | --------- | ------------------------------------------------ |
| Violet       | `#8B5CF6` | Accent (every interactive surface)               |
| Surface      | `#EEE4FF` | Soft accent backdrop (cards on accent screens)   |
| Background   | `#F0E8FA` | App background tint                              |
| Ink          | `#1A1A2E` | Primary text                                     |
| Success      | `#16A34A` | Confirmation, completion                         |
| Warning      | `#EF4444` | Destructive actions, errors                      |
| Streak orange| `#FF9642` | Flame pill base                                  |
| Streak flame | `#FF4A00` | Flame pill highlight                             |
| Streak egg   | `#FFDA8A` | Streak sheet medal                               |
| Cheek        | `#FFB8C4` | Mascot blush                                     |

Praccy ships a single fixed violet theme. The accent-palette picker was removed 2026-04-23.

## Shadows

One style, used everywhere: a solid colour offset shadow (no blur). `View.praccySolidShadow(color:offset:)` is the only shadow helper. White-background cards (to-dos, goals, calendar) use the palette's `softShadow` (35% alpha).

## Voice

See [`Voice.md`](Voice.md) for the full rules. The headline ones:

- No exclamation marks. Anywhere.
- No "Oops!", no "Uh-oh". Plain language + next steps.
- Headlines ≤ 3 words; buttons ≤ 2 words.
- Teachers are named ("From Claire"), never "your teacher".
- No emojis in UI strings.
