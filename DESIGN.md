# Sidur — Design System

## Concept
"Sidur" — a daily spiritual companion app (halachic times, prayers, blessings, Psalms) for observant Jews. Design language: **quiet luxury**, inspired by Apple, Hermès, and Aman resorts. Restrained, warm, minimal. NOT a typical "religious app" — no clip-art, no gaudy ornamentation, no bright saturated colors.

## Color palette
Colors are defined as light/dark pairs (hex), auto-switching with system appearance.

| Token   | Light     | Dark      | Usage                                  |
|---------|-----------|-----------|-----------------------------------------|
| paper   | `#FAFAF9` | `#13110E` | app background                          |
| card    | `#FFFFFF` | `#1E1B16` | card / surface background               |
| cream   | `#F1EFEA` | `#262119` | secondary surface, chips                |
| gold    | `#A16207` | `#CBA250` | primary accent (active states, icons)   |
| goldL   | `#BFA46F` | `#9C8350` | secondary/lighter gold accent           |
| ink     | `#1C1917` | `#F0EBE1` | primary text                            |
| soft    | `#57534E` | `#A8A096` | secondary text                          |
| faint   | `#A8A29E` | `#6E6759` | tertiary text / placeholders            |
| line    | `#E3DFD8` | `#322C23` | hairline borders / dividers             |

Gold is used **sparingly** — accents, active nav states, key numerals — never as a large fill.

## Typography
- **Display / headings:** system serif (New York), semibold — supports Cyrillic (Russian UI).
- **Hebrew liturgical text:** Frank Ruhl Libre (regular/weighted) — must render niqqud (vowel points) cleanly, RTL.
- **Numerals / times:** Bodoni Moda, semibold — used for zmanim times and psalm numbers, Latin/digits only.
- **UI body / labels:** system sans-serif, regular.

Font files attached: `FrankRuhlLibre.ttf`, `BodoniModa.ttf`.

## Spacing scale
`xs=6, sm=10, md=14, lg=20, xl=28` (points) — consistent vertical rhythm across all screens.

## Surface treatment
- Rounded corners, generous whitespace, soft shadows — no harsh borders (use `line` color at low weight only).
- Bottom navigation bar and modals use **Liquid Glass** (iOS 26 native `.glassEffect`, fallback `.ultraThinMaterial`): frosted, translucent, with a sliding "lens" highlight under the active tab.
- Cards float on `paper` background using `card` surface color with subtle shadow, not heavy borders.

## Layout / structure
- Bottom tab bar, 5 tabs: **Today · Zmanim · Prayers · Brachot · Tehillim**. Prayers/Brachot icons are emphasized as gold circular buttons in the center.
- Full RTL mirroring required for Hebrew UI (including tab bar order and card alignment).
- Key screens: Today (next-prayer card w/ tabs, quick actions, draggable favorites grid), Zmanim (list + detail w/ variants), Reader (full-screen overlay, Hebrew/Transliteration/Russian segmented control, font-size + background sheet, "prayer mode" that hides all chrome), Tehillim (book/day segmented view, favorites), Compass ("direction to Jerusalem"), Tzedakah (QR + bank details card), Settings.

## Tone
Calm, reverent, expensive-feeling — like opening a beautifully bound leather siddur or a boutique hotel app. Never cartoonish or cluttered.
