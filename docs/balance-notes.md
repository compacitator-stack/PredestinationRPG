# Balance Notes — Phase 1 Combat Prototype

Date: 2026-04-11

## Damage Formula

`ATK * power / DEF * 10 * type_mult * variance(0.9-1.1)`

Physical uses ATK/DEF, magical uses MAG/RES.

### Sample Damage (post-tuning)

| Attacker | Skill | Target | Type Mult | Damage |
|----------|-------|--------|-----------|--------|
| Seer (ATK 12) | Attack (Mystic 1.0) | Shade (Corrupt, DEF 6) | 0.5x resist | ~10 |
| Seer (MAG 15) | Mystic Ray (1.5, 2 SP) | Stone Golem (Feral, RES 10) | 1.5x weak | ~34 |
| Seer (MAG 15) | Holy Light (Innocent 1.5) | Shade (Corrupt, RES 8) | 1.0x neutral | ~28 |
| Seraph (ATK 8) | Feral Strike (1.2, 2 SP) | Shade (Corrupt, DEF 6) | 1.5x weak | ~24 |
| Seer (ATK 12) | Attack (Mystic 1.0) | Will-o-Wisp (Mystic, DEF 4) | 1.0x neutral | ~30 |
| Stone Golem (ATK 15) | Attack (Feral 1.0) | Seer (DEF 10) | 0.5x resist | ~7.5 |
| Shade (ATK 12) | Attack (Corrupt 1.0) | Seer (Mystic, DEF 10) | 1.5x weak | ~18 |

### Healing (post-tuning: multiplier 5.0 -> 3.5)

| Caster | Heal Amount | With Innocence Bonus |
|--------|-------------|---------------------|
| Seer (MAG 15) | 52 | 65 |
| Seraph (MAG 14) | 49 | 61 |
| Dark Acolyte (MAG 11) | 38 | N/A (enemy) |

## Changes Applied

### Heal multiplier: 5.0 -> 3.5
**Why:** At 5.0, Seer healed 75 HP (75% of max) per cast. With innocence bonus, 93 HP — nearly full restore every time. Made SP a non-factor in attrition. At 3.5, Seer heals ~52 (65 with bonus). Still strong but requires 2 heals to fully recover from bad turns. Creates meaningful HP attrition across encounters.

### Shade HP: 45 -> 50
**Why:** Seraph's Feral Strike (24 weakness damage) two-shot Shades at 45 HP. At 50 HP, they survive 2 hits (48 total) and require a third hit or a follow-up basic attack. Shade encounters now last 1 more turn on average.

### Stone Golem ATK: 18 -> 15
**Why:** Stone Golem was both the tankiest (120 HP, 20 DEF) and hardest-hitting physical attacker. At 18 ATK, it dealt 18 damage to Seer (neutral). Combined with being a sponge (4+ hits to kill with weakness skills), it was frustrating not dangerous-interesting. At 15 ATK, damage drops to ~15 — still threatening but recoverable.

### Dark Acolyte MAG: 14 -> 11
**Why:** At MAG 14, the old heal formula (5.0 mult) healed 70 HP — a full self-restore on a 70 HP enemy. Even with the new 3.5 mult, MAG 14 would heal 49 (70% HP). At MAG 11, heal drops to 38 (54% HP). Dark Acolyte is still a high-priority kill target (support AI), but the heal is beatable without focusing exclusively.

### Support AI heal chance: 60% -> 45%
**Why:** At 60%, Dark Acolytes healed nearly every other turn when allies were hurt, making multi-enemy fights with a Dark Acolyte drag indefinitely. At 45%, they heal roughly once per 2-3 turns, still enough to be a nuisance but not a stalemate.

### Encounter step range: 12-20 -> 14-22
**Why:** Slightly lower encounter frequency. With the test map's size (~15 walkable tiles), 12-step minimum meant an encounter almost every corridor segment. At 14-22, the player gets a bit more exploration breathing room between fights. One extra step minimum, two extra steps maximum.

## Observations (no change applied, monitor in playtesting)

### SP Economy
Starting SP (Seer 10, Seraph 8) is generous. Weakness hits restore +1 SP. In a typical fight, the party spends 4-8 SP and restores 1-3 from weaknesses. SP attrition is slow but present. **Watch:** if SP never runs out, consider reducing starting SP to 6/5 or increasing skill costs.

### Corruption Temptation
Corrupt Boost costs 1 SP for 1.5x next attack. Good value proposition — 50% damage increase for 1 SP is mechanically tempting. The Still Small Voice warning + permanent flag create the right "this is a big deal" feel. **Watch:** is 1.5x enough to tempt players? If not, consider 1.75x for the first corruption (to make the first fall dramatic).

### Type Chart Gaps
Neither Seer nor Seraph has a natural Corrupt-element skill. This means Corrupt-type enemies (50% of encounters) have no weakness available unless a party member corrupts. This is intentional design pressure (corruption is tempting because it fills a gap) but could feel frustrating early. **Watch:** does Phase 2's creature recruitment solve this naturally? If not, consider adding a Feral physical skill to Seer's base kit (Feral beats Corrupt).

### Multi-Enemy Fights
3-enemy encounters are significantly harder than 1-enemy. Three Shades deal ~30+ combined damage per round to random targets. The party can focus fire one down per round but takes heavy attrition. **Watch:** should the encounter table cap at 2 enemies for now? Or add a "weak" variant (e.g. 1-2 enemies common, 3 enemies rare)?

### Guard + Innocence Bonus
Guard halves damage (50%). With Innocence Bonus, Guard DEF is boosted by 25%, making damage only 37.5% of normal. This is very strong defensively. **Watch:** is Guard ever worth using vs. just healing? If Guard is always dominated by Heal, consider making Guard restore 1 SP per turn.
