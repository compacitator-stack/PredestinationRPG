extends Node

## Global combat data — element types, type effectiveness, damage formulas,
## skill/enemy/party definitions, encounter tables.
## Autoloaded as "CombatData".

enum Element { MYSTIC, FERAL, CORRUPT, INNOCENT }
enum Race { BEAST, SERPENT, DRAGON, SEER, CELESTIALITE, DARKNESS, INSECT, SEA_CREATURE }
enum Tier { TRASH, COMMON, MID, STRONG, BOSS, SUPERBOSS }

var ELEMENT_COLORS := {
	Element.MYSTIC: Color(0.3, 0.4, 0.9),
	Element.FERAL: Color(0.2, 0.75, 0.3),
	Element.CORRUPT: Color(0.6, 0.15, 0.6),
	Element.INNOCENT: Color(0.95, 0.85, 0.3),
}

var ELEMENT_NAMES := {
	Element.MYSTIC: "Mystic",
	Element.FERAL: "Feral",
	Element.CORRUPT: "Corrupt",
	Element.INNOCENT: "Innocent",
}

var RACE_NAMES := {
	Race.BEAST: "Beast",
	Race.SERPENT: "Serpent",
	Race.DRAGON: "Dragon",
	Race.SEER: "Seer",
	Race.CELESTIALITE: "Celestialite",
	Race.DARKNESS: "Darkness",
	Race.INSECT: "Insect",
	Race.SEA_CREATURE: "Sea Creature",
}

var TIER_NAMES := {
	Tier.TRASH: "Trash",
	Tier.COMMON: "Common",
	Tier.MID: "Mid",
	Tier.STRONG: "Strong",
	Tier.BOSS: "Boss",
	Tier.SUPERBOSS: "Superboss",
}

# TYPE_CHART[attacker_element][defender_element] -> multiplier
# 1.5 = weakness (super effective, +1 SP to attacker)
# 0.5 = resisted
# 1.0 = neutral
var TYPE_CHART := {
	Element.MYSTIC:   { Element.MYSTIC: 1.0, Element.FERAL: 1.5, Element.CORRUPT: 0.5, Element.INNOCENT: 1.0 },
	Element.FERAL:    { Element.MYSTIC: 0.5, Element.FERAL: 1.0, Element.CORRUPT: 1.5, Element.INNOCENT: 1.0 },
	Element.CORRUPT:  { Element.MYSTIC: 1.5, Element.FERAL: 1.0, Element.CORRUPT: 1.0, Element.INNOCENT: 0.5 },
	Element.INNOCENT: { Element.MYSTIC: 1.0, Element.FERAL: 0.5, Element.CORRUPT: 1.0, Element.INNOCENT: 1.5 },
}


func get_effectiveness(atk_elem: int, def_elem: int) -> float:
	return TYPE_CHART[atk_elem][def_elem]


func is_weakness(atk_elem: int, def_elem: int) -> bool:
	return get_effectiveness(atk_elem, def_elem) >= 1.5


func is_resist(atk_elem: int, def_elem: int) -> bool:
	return get_effectiveness(atk_elem, def_elem) <= 0.5


# --- Damage & Healing ---

func calc_damage(attacker: Combatant, skill: Dictionary, defender: Combatant) -> int:
	var atk_stat: int
	var def_stat: int
	if skill.get("is_magical", false):
		atk_stat = attacker.mag
		def_stat = defender.res
	else:
		atk_stat = attacker.atk
		def_stat = defender.defense
	var def_factor := maxf(1.0, float(def_stat))
	var raw: float = float(atk_stat) * float(skill.power) / def_factor * 10.0
	var type_mult := get_effectiveness(skill.element, defender.element)
	var variance := randf_range(0.9, 1.1)
	# Posture-break window: +50% incoming damage while broken.
	var broken_mult := 1.5 if defender.is_posture_broken else 1.0
	return maxi(1, int(raw * type_mult * variance * broken_mult))


func calc_heal(caster: Combatant, skill: Dictionary, innocence_bonus: bool) -> int:
	var base := int(float(caster.mag) * float(skill.power) * 3.5)
	if innocence_bonus:
		base = int(float(base) * 1.25)
	return maxi(1, base)


# --- Skill Factory ---

func make_skill(skill_name: String, element: int, power: float, sp_cost: int,
		is_magical: bool = false, is_heal: bool = false,
		posture_dmg: float = 0.3, resolve_dmg: int = 0,
		cooldown: int = 0, trigger: String = "always",
		tags_applied: Array = [], tags_consumed: Array = []) -> Dictionary:
	return {
		"name": skill_name,
		"element": element,
		"power": power,
		"sp_cost": sp_cost,
		"is_magical": is_magical,
		"is_heal": is_heal,
		# Phase A additions — scaffolding, not yet consumed by battle logic.
		"posture_dmg": posture_dmg,
		"resolve_dmg": resolve_dmg,
		"cooldown": cooldown,
		"trigger": trigger,
		"tags_applied": tags_applied.duplicate(),
		"tags_consumed": tags_consumed.duplicate(),
	}


# --- Enemy Templates ---

func create_enemy(template: String) -> Combatant:
	var c := Combatant.new()
	match template:
		"shade":
			c.creature_id = "shade"
			c.display_name = "Shade"
			c.race = Race.DARKNESS; c.element = Element.CORRUPT; c.tier = Tier.TRASH
			c.max_hp = 50; c.hp = 50
			c.max_sp = 3; c.sp = 3
			c.atk = 12; c.defense = 6; c.mag = 10; c.res = 8; c.spd = 9
			c.max_posture = 15; c.posture = 15
			c.awareness = 1; c.behavior_family = "Striker"
			c.lore_text = "A wisp of corrupted shadow. It lurks in the cracks between realms."
			c.skills = [
				make_skill("Attack", Element.CORRUPT, 1.0, 0),
				make_skill("Shadow Bolt", Element.CORRUPT, 1.5, 3, true),
			]
			c.ai_type = "aggressive"
		"stone_golem":
			c.creature_id = "stone_golem"
			c.display_name = "Stone Golem"
			c.race = Race.BEAST; c.element = Element.FERAL; c.tier = Tier.COMMON
			c.max_hp = 120; c.hp = 120
			c.max_sp = 0; c.sp = 0
			c.atk = 15; c.defense = 20; c.mag = 3; c.res = 10; c.spd = 3
			c.lore_text = "Animated stone, given purpose by the earth itself. Slow but unyielding."
			c.skills = [make_skill("Attack", Element.FERAL, 1.0, 0)]
			c.ai_type = "aggressive"
		"will_o_wisp":
			c.creature_id = "will_o_wisp"
			c.display_name = "Will-o-Wisp"
			c.race = Race.SEER; c.element = Element.MYSTIC; c.tier = Tier.TRASH
			c.max_hp = 30; c.hp = 30
			c.max_sp = 6; c.sp = 6
			c.atk = 5; c.defense = 4; c.mag = 16; c.res = 12; c.spd = 14
			c.max_posture = 9; c.posture = 9
			c.awareness = 2; c.behavior_family = "Striker"
			c.lore_text = "A fragment of a Seer's abandoned vision. It flickers with lost knowledge."
			c.skills = [
				make_skill("Mystic Ray", Element.MYSTIC, 1.5, 2, true),
				make_skill("Attack", Element.MYSTIC, 1.0, 0),
			]
			c.ai_type = "aggressive"
		"dark_acolyte":
			c.creature_id = "dark_acolyte"
			c.display_name = "Dark Acolyte"
			c.race = Race.DARKNESS; c.element = Element.CORRUPT; c.tier = Tier.COMMON
			c.max_hp = 70; c.hp = 70
			c.max_sp = 8; c.sp = 8
			c.atk = 10; c.defense = 10; c.mag = 11; c.res = 14; c.spd = 8
			c.lore_text = "A devotee of darkness who channels corrupt healing. Dangerous in groups."
			c.skills = [
				make_skill("Shadow Bolt", Element.CORRUPT, 1.5, 3, true),
				make_skill("Heal", Element.CORRUPT, 1.0, 3, true, true),
				make_skill("Attack", Element.CORRUPT, 1.0, 0),
			]
			c.ai_type = "support"
	return c


# --- Player Party ---

func create_party() -> Array:
	var seer := Combatant.new()
	seer.creature_id = "player_seer"
	seer.display_name = "Seer"
	seer.race = Race.SEER
	seer.element = Element.MYSTIC
	seer.tier = Tier.MID
	seer.max_hp = 100; seer.hp = 100
	seer.max_sp = 10; seer.sp = 10
	seer.atk = 12; seer.defense = 10; seer.mag = 15; seer.res = 12; seer.spd = 10
	# Phase A — Innocent-path party member. Medium Posture, high Resolve, high Awareness.
	seer.max_posture = 50; seer.posture = 50
	seer.max_resolve = 100; seer.resolve = 100
	seer.awareness = 3
	seer.is_player_controlled = true
	seer.lore_text = "The player character. A young Seer drawn to the fracture in the Firmament."
	seer.skills = [
		make_skill("Mystic Ray", Element.MYSTIC, 1.5, 2, true),
		make_skill("Holy Light", Element.INNOCENT, 1.5, 2, true),
		make_skill("Heal", Element.INNOCENT, 1.0, 3, true, true),
	]

	var seraph := Combatant.new()
	seraph.creature_id = "starter_seraph"
	seraph.display_name = "Seraph"
	seraph.race = Race.CELESTIALITE
	seraph.element = Element.INNOCENT
	seraph.tier = Tier.MID
	seraph.max_hp = 80; seraph.hp = 80
	seraph.max_sp = 8; seraph.sp = 8
	seraph.atk = 8; seraph.defense = 8; seraph.mag = 14; seraph.res = 16; seraph.spd = 11
	# Phase A — Innocent Celestialite. Medium Posture, high Resolve (very resistant to drain).
	seraph.max_posture = 40; seraph.posture = 40
	seraph.max_resolve = 80; seraph.resolve = 80
	seraph.awareness = 1
	seraph.is_player_controlled = true
	seraph.lore_text = "A Celestialite companion who chose to descend with the Seer."
	seraph.skills = [
		make_skill("Holy Light", Element.INNOCENT, 1.5, 2, true),
		make_skill("Heal", Element.INNOCENT, 1.0, 3, true, true),
		make_skill("Feral Strike", Element.FERAL, 1.2, 2),
	]

	return [seer, seraph]


# --- Encounter Rolling ---

var ENCOUNTER_TABLE := [
	{ "template": "shade", "weight": 15 },
	{ "template": "stone_golem", "weight": 15 },
	{ "template": "will_o_wisp", "weight": 15 },
	{ "template": "dark_acolyte", "weight": 10 },
	{ "template": "pipers_boot", "weight": 20 },
	{ "template": "amygdala", "weight": 10 },
	{ "template": "caphilim", "weight": 8 },
	{ "template": "nisoro", "weight": 7 },
]


func roll_encounter(table_override: Array = []) -> Array:
	var table: Array = table_override if table_override.size() > 0 else ENCOUNTER_TABLE
	var result: Array = []
	var count := randi_range(1, 3)
	for i in count:
		var template_id: String = _weighted_pick(table)
		if CREATURE_DB.has(template_id):
			result.append(create_creature(template_id))
		else:
			result.append(create_enemy(template_id))
	return result


func _weighted_pick(table: Array) -> String:
	var total := 0
	for e in table:
		total += e.weight
	var roll := randi_range(1, total)
	var cum := 0
	for e in table:
		cum += e.weight
		if roll <= cum:
			return e.template
	return table[0].template


# ==========================================================================
#  CREATURE DATABASE
# ==========================================================================

## All prototype creatures. Each entry defines a template that create_creature() builds from.
var CREATURE_DB := {
	"feral_hound": {
		"name": "Feral Hound", "race": Race.BEAST, "element": Element.FERAL,
		"tier": Tier.COMMON, "card_game_ref": "Feral Hound",
		"hp": 65, "sp": 3, "atk": 20, "defense": 8, "mag": 5, "res": 7, "spd": 13,
		# Phase A — Common-tier Striker. Brittle glass cannon; opens turn 1 with a big hit.
		"posture": 18, "resolve": 0, "threat": 110, "awareness": 1,
		"behavior_family": "Striker",
		"skills": [["Rending Bite", Element.FERAL, 1.3, 0, false, false],
				   ["Feral Strike", Element.FERAL, 1.2, 2, false, false],
				   ["Quick Dash", Element.FERAL, 1.0, 1, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "A lean predator from the wilds beyond the Cathedral. It strikes once, hard — before you know it is there.",
	},
	"pipers_boot": {
		"name": "Piper's Boot", "race": Race.BEAST, "element": Element.FERAL,
		"tier": Tier.TRASH, "card_game_ref": "Piper's Boot",
		"hp": 45, "sp": 2, "atk": 8, "defense": 6, "mag": 5, "res": 5, "spd": 5,
		# Phase A — MVP Striker stats
		"posture": 13, "resolve": 0, "threat": 100, "awareness": 1,
		"behavior_family": "Striker",
		"skills": [["Bite", Element.FERAL, 1.0, 0, false, false],
				   ["Growl", Element.FERAL, 0.8, 0, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "A scrappy creature that clings to the boots of wandering Pipers. Small but tenacious.",
	},
	"amygdala": {
		"name": "Amygdala", "race": Race.DARKNESS, "element": Element.CORRUPT,
		"tier": Tier.COMMON, "card_game_ref": "Amygdala",
		"hp": 90, "sp": 5, "atk": 14, "defense": 10, "mag": 16, "res": 12, "spd": 7,
		"skills": [["Fear Pulse", Element.CORRUPT, 1.4, 2, true, false],
				   ["Shadow Bolt", Element.CORRUPT, 1.5, 3, true, false],
				   ["Attack", Element.CORRUPT, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "Born from the collective dread of the Heap. It feeds on fear and grows stronger in darkness.",
	},
	"cecil": {
		"name": "Cecil", "race": Race.CELESTIALITE, "element": Element.INNOCENT,
		"tier": Tier.MID, "card_game_ref": "Cecil",
		"hp": 220, "sp": 8, "atk": 15, "defense": 22, "mag": 25, "res": 20, "spd": 9,
		"skills": [["Holy Light", Element.INNOCENT, 1.5, 2, true, false],
				   ["Heal", Element.INNOCENT, 1.0, 3, true, true],
				   ["Blessing", Element.INNOCENT, 1.2, 2, true, false]],
		"ai_type": "support", "recruitable": true,
		"lore": "A gentle Celestialite who serves as a shepherd in the Firmament. Heals with quiet devotion.",
	},
	"nisoro": {
		"name": "Nisoro", "race": Race.SEER, "element": Element.MYSTIC,
		"tier": Tier.MID, "card_game_ref": "Nisoro",
		"hp": 200, "sp": 10, "atk": 12, "defense": 14, "mag": 30, "res": 18, "spd": 11,
		"skills": [["Mystic Ray", Element.MYSTIC, 1.5, 2, true, false],
				   ["Mind Rend", Element.MYSTIC, 2.0, 4, true, false],
				   ["Attack", Element.MYSTIC, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "A Seer who turned inward, seeking visions in the patterns of starlight. Powerful but aloof.",
	},
	"jormundangr": {
		"name": "Jormundangr", "race": Race.SERPENT, "element": Element.CORRUPT,
		"tier": Tier.BOSS, "card_game_ref": "Jormundangr",
		"hp": 1200, "sp": 12, "atk": 55, "defense": 40, "mag": 45, "res": 35, "spd": 16,
		"skills": [["Coil Crush", Element.FERAL, 2.0, 3, false, false],
				   ["Venom Fang", Element.CORRUPT, 1.8, 3, false, false],
				   ["Shadow Bolt", Element.CORRUPT, 1.5, 3, true, false],
				   ["Attack", Element.CORRUPT, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": false,
		"lore": "The World Serpent, coiled beneath the Heap. Its venom corrupts the very earth it touches.",
	},
	"holy_diver": {
		"name": "Holy Diver", "race": Race.CELESTIALITE, "element": Element.INNOCENT,
		"tier": Tier.STRONG, "card_game_ref": "Holy Diver",
		"hp": 600, "sp": 8, "atk": 38, "defense": 45, "mag": 30, "res": 40, "spd": 12,
		"skills": [["Divine Shield", Element.INNOCENT, 1.0, 2, false, false],
				   ["Holy Light", Element.INNOCENT, 1.5, 2, true, false],
				   ["Heal", Element.INNOCENT, 1.2, 3, true, true],
				   ["Attack", Element.INNOCENT, 1.0, 0, false, false]],
		"ai_type": "support", "recruitable": true,
		"lore": "A Celestialite warrior who descended from the Firmament to protect the Middle Lands. Unyielding.",
	},
	"legendary_pika": {
		"name": "The Legendary Pika", "race": Race.BEAST, "element": Element.FERAL,
		"tier": Tier.STRONG, "card_game_ref": "The Legendary Pika",
		"hp": 500, "sp": 6, "atk": 42, "defense": 25, "mag": 20, "res": 22, "spd": 16,
		"skills": [["Thunder Paw", Element.FERAL, 1.8, 2, false, false],
				   ["Feral Strike", Element.FERAL, 1.2, 2, false, false],
				   ["Quick Dash", Element.FERAL, 1.0, 1, false, false],
				   ["Attack", Element.FERAL, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "A mythical beast said to be as fast as lightning. Few have seen it and fewer have caught it.",
	},
	"caphilim": {
		"name": "Caphilim", "race": Race.DARKNESS, "element": Element.CORRUPT,
		"tier": Tier.MID, "card_game_ref": "Caphilim",
		"hp": 280, "sp": 7, "atk": 28, "defense": 18, "mag": 22, "res": 15, "spd": 10,
		"skills": [["Fallen Strike", Element.CORRUPT, 1.6, 2, false, false],
				   ["Shadow Bolt", Element.CORRUPT, 1.5, 3, true, false],
				   ["Attack", Element.CORRUPT, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "Once a Celestialite, now fallen. It remembers the Firmament and hates what it has become.",
	},
	"ezekiel": {
		"name": "Ezekiel", "race": Race.SEER, "element": Element.INNOCENT,
		"tier": Tier.STRONG, "card_game_ref": "Ezekiel",
		"hp": 520, "sp": 12, "atk": 22, "defense": 30, "mag": 42, "res": 38, "spd": 13,
		"skills": [["Prophet's Fire", Element.INNOCENT, 2.0, 4, true, false],
				   ["Holy Light", Element.INNOCENT, 1.5, 2, true, false],
				   ["Heal", Element.INNOCENT, 1.2, 3, true, true],
				   ["Blessing", Element.INNOCENT, 1.0, 2, true, false]],
		"ai_type": "support", "recruitable": true,
		"lore": "The prophet who saw the wheel within a wheel. His visions burn with Innocent fire.",
	},
	"shade": {
		"name": "Shade", "race": Race.DARKNESS, "element": Element.CORRUPT,
		"tier": Tier.TRASH, "card_game_ref": "",
		"hp": 50, "sp": 3, "atk": 12, "defense": 6, "mag": 10, "res": 8, "spd": 9,
		# Phase A — MVP Striker stats
		"posture": 15, "resolve": 0, "threat": 100, "awareness": 1,
		"behavior_family": "Striker",
		"skills": [["Attack", Element.CORRUPT, 1.0, 0, false, false],
				   ["Shadow Bolt", Element.CORRUPT, 1.5, 3, true, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "A wisp of corrupted shadow. It lurks in the cracks between realms.",
	},
	"stone_golem": {
		"name": "Stone Golem", "race": Race.BEAST, "element": Element.FERAL,
		"tier": Tier.COMMON, "card_game_ref": "",
		"hp": 120, "sp": 0, "atk": 15, "defense": 20, "mag": 3, "res": 10, "spd": 3,
		"skills": [["Attack", Element.FERAL, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "Animated stone, given purpose by the earth itself. Slow but unyielding.",
	},
	"will_o_wisp": {
		"name": "Will-o-Wisp", "race": Race.SEER, "element": Element.MYSTIC,
		"tier": Tier.TRASH, "card_game_ref": "",
		"hp": 30, "sp": 6, "atk": 5, "defense": 4, "mag": 16, "res": 12, "spd": 14,
		# Phase A — MVP Striker stats (MAG-based; highest SPD in MVP pool)
		"posture": 9, "resolve": 0, "threat": 100, "awareness": 2,
		"behavior_family": "Striker",
		"skills": [["Mystic Ray", Element.MYSTIC, 1.5, 2, true, false],
				   ["Attack", Element.MYSTIC, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": true,
		"lore": "A fragment of a Seer's abandoned vision. It flickers with lost knowledge.",
	},
	"dark_acolyte": {
		"name": "Dark Acolyte", "race": Race.DARKNESS, "element": Element.CORRUPT,
		"tier": Tier.COMMON, "card_game_ref": "",
		"hp": 70, "sp": 8, "atk": 10, "defense": 10, "mag": 11, "res": 14, "spd": 8,
		"skills": [["Shadow Bolt", Element.CORRUPT, 1.5, 3, true, false],
				   ["Heal", Element.CORRUPT, 1.0, 3, true, true],
				   ["Attack", Element.CORRUPT, 1.0, 0, false, false]],
		"ai_type": "support", "recruitable": true,
		"lore": "A devotee of darkness who channels corrupt healing. Dangerous in groups.",
	},
	"eotentos": {
		"name": "Eotentos", "race": Race.DARKNESS, "element": Element.CORRUPT,
		"tier": Tier.SUPERBOSS, "card_game_ref": "Eotentos",
		"hp": 5000, "sp": 20, "atk": 85, "defense": 60, "mag": 80, "res": 55, "spd": 22,
		"skills": [["Abyssal Crush", Element.CORRUPT, 2.5, 5, false, false],
				   ["Fear Pulse", Element.CORRUPT, 1.8, 3, true, false],
				   ["Shadow Bolt", Element.CORRUPT, 1.5, 3, true, false],
				   ["Attack", Element.CORRUPT, 1.0, 0, false, false]],
		"ai_type": "aggressive", "recruitable": false,
		"lore": "The titan of the Heap, older than memory. Its very presence warps reality.",
	},
	"corrupted_seraph": {
		"name": "Corrupted Seraph", "race": Race.CELESTIALITE, "element": Element.CORRUPT,
		"tier": Tier.BOSS, "card_game_ref": "",
		"hp": 400, "sp": 12, "atk": 25, "defense": 22, "mag": 30, "res": 25, "spd": 11,
		"skills": [["Fallen Grace", Element.CORRUPT, 1.8, 3, true, false],
				   ["Shadow Bolt", Element.CORRUPT, 1.5, 3, true, false],
				   ["Tarnished Wings", Element.FERAL, 1.5, 2, false, false],
				   ["Corrupt Heal", Element.CORRUPT, 0.8, 4, true, true]],
		"ai_type": "boss", "recruitable": false,
		"lore": "Once a guardian of the Shattered Cathedral, now twisted by the Corruption leaking from the Heap. Golden wings tarnished violet. It remembers what it was.",
	},
}

## All creature IDs — for compendium iteration
var ALL_CREATURE_IDS: Array = []


func _ready() -> void:
	ALL_CREATURE_IDS = CREATURE_DB.keys()
	ALL_CREATURE_IDS.sort()


func create_creature(creature_id: String) -> Combatant:
	## Build a Combatant from the creature database.
	if not CREATURE_DB.has(creature_id):
		push_error("Unknown creature_id: " + creature_id)
		return Combatant.new()
	var data: Dictionary = CREATURE_DB[creature_id]
	var c := Combatant.new()
	c.creature_id = creature_id
	c.display_name = data.name
	c.race = data.race
	c.element = data.element
	c.tier = data.tier
	c.card_game_ref = data.get("card_game_ref", "")
	c.lore_text = data.get("lore", "")
	c.is_recruitable = data.get("recruitable", true)
	c.max_hp = data.hp; c.hp = data.hp
	c.max_sp = data.sp; c.sp = data.sp
	c.atk = data.atk; c.defense = data.defense
	c.mag = data.mag; c.res = data.res; c.spd = data.spd
	c.ai_type = data.get("ai_type", "aggressive")
	# Phase A — new fields with safe defaults for unstatted creatures.
	c.max_posture = data.get("posture", 0); c.posture = c.max_posture
	c.max_resolve = data.get("resolve", 0); c.resolve = c.max_resolve
	c.threat = data.get("threat", 100)
	c.awareness = data.get("awareness", 0)
	c.behavior_family = data.get("behavior_family", "")

	c.skills.clear()
	for s_arr in data.skills:
		c.skills.append(make_skill(s_arr[0], s_arr[1], s_arr[2], s_arr[3], s_arr[4], s_arr[5]))
	return c


# ==========================================================================
#  FUSION — RACE TABLE & ALIGNMENT MIXING
# ==========================================================================

## Symmetric race fusion table. Key = sorted pair of Race enums -> result Race.
var RACE_FUSION_TABLE := {}


func _init_fusion_table() -> void:
	## Build the symmetric race fusion table from mechanics.md.
	var rules := [
		[Race.BEAST, Race.BEAST, Race.BEAST],
		[Race.BEAST, Race.SERPENT, Race.SERPENT],
		[Race.BEAST, Race.DRAGON, Race.DRAGON],
		[Race.BEAST, Race.SEER, Race.SEER],
		[Race.BEAST, Race.CELESTIALITE, Race.BEAST],
		[Race.BEAST, Race.DARKNESS, Race.DARKNESS],
		[Race.BEAST, Race.INSECT, Race.INSECT],
		[Race.BEAST, Race.SEA_CREATURE, Race.SEA_CREATURE],
		[Race.SERPENT, Race.SERPENT, Race.SERPENT],
		[Race.SERPENT, Race.DRAGON, Race.DRAGON],
		[Race.SERPENT, Race.SEER, Race.SEER],
		[Race.SERPENT, Race.CELESTIALITE, Race.SERPENT],
		[Race.SERPENT, Race.DARKNESS, Race.DARKNESS],
		[Race.SERPENT, Race.INSECT, Race.INSECT],
		[Race.SERPENT, Race.SEA_CREATURE, Race.SEA_CREATURE],
		[Race.DRAGON, Race.DRAGON, Race.DRAGON],
		[Race.DRAGON, Race.SEER, Race.DRAGON],
		[Race.DRAGON, Race.CELESTIALITE, Race.CELESTIALITE],
		[Race.DRAGON, Race.DARKNESS, Race.DRAGON],
		[Race.DRAGON, Race.INSECT, Race.DRAGON],
		[Race.DRAGON, Race.SEA_CREATURE, Race.SEA_CREATURE],
		[Race.SEER, Race.SEER, Race.SEER],
		[Race.SEER, Race.CELESTIALITE, Race.CELESTIALITE],
		[Race.SEER, Race.DARKNESS, Race.DARKNESS],
		[Race.SEER, Race.INSECT, Race.SEER],
		[Race.SEER, Race.SEA_CREATURE, Race.SEER],
		[Race.CELESTIALITE, Race.CELESTIALITE, Race.CELESTIALITE],
		[Race.CELESTIALITE, Race.DARKNESS, Race.SEER],
		[Race.CELESTIALITE, Race.INSECT, Race.SEER],
		[Race.CELESTIALITE, Race.SEA_CREATURE, Race.CELESTIALITE],
		[Race.DARKNESS, Race.DARKNESS, Race.DARKNESS],
		[Race.DARKNESS, Race.INSECT, Race.INSECT],
		[Race.DARKNESS, Race.SEA_CREATURE, Race.DARKNESS],
		[Race.INSECT, Race.INSECT, Race.INSECT],
		[Race.INSECT, Race.SEA_CREATURE, Race.INSECT],
		[Race.SEA_CREATURE, Race.SEA_CREATURE, Race.SEA_CREATURE],
	]
	for r in rules:
		var key_a := _fusion_key(r[0], r[1])
		RACE_FUSION_TABLE[key_a] = r[2]


func _fusion_key(race_a: int, race_b: int) -> String:
	var lo := mini(race_a, race_b)
	var hi := maxi(race_a, race_b)
	return "%d_%d" % [lo, hi]


func get_fusion_result_race(race_a: int, race_b: int) -> int:
	_ensure_fusion_table()
	var key := _fusion_key(race_a, race_b)
	if RACE_FUSION_TABLE.has(key):
		return RACE_FUSION_TABLE[key]
	return race_a  # fallback


var _fusion_table_ready := false
func _ensure_fusion_table() -> void:
	if not _fusion_table_ready:
		_init_fusion_table()
		_fusion_table_ready = true


func get_alignment_mix(elem_a: int, elem_b: int) -> int:
	## Alignment mixing rules from mechanics.md.
	if elem_a == elem_b:
		return elem_a
	# Sort for symmetric matching
	var pair := [elem_a, elem_b]
	pair.sort()
	var lo: int = pair[0]
	var hi: int = pair[1]

	# MYSTIC=0, FERAL=1, CORRUPT=2, INNOCENT=3
	if lo == Element.CORRUPT and hi == Element.INNOCENT:
		return Element.MYSTIC
	if lo == Element.MYSTIC and hi == Element.CORRUPT:
		return Element.CORRUPT
	if lo == Element.MYSTIC and hi == Element.INNOCENT:
		return Element.INNOCENT
	if lo == Element.MYSTIC and hi == Element.FERAL:
		return Element.FERAL
	if lo == Element.FERAL and hi == Element.CORRUPT:
		return Element.CORRUPT
	if lo == Element.FERAL and hi == Element.INNOCENT:
		return Element.FERAL
	return Element.MYSTIC  # fallback


func calculate_fusion(creature_a: Combatant, creature_b: Combatant) -> Combatant:
	## Calculate the fusion result. Does NOT consume the parents — caller does that.
	var result := Combatant.new()
	result.race = get_fusion_result_race(creature_a.race, creature_b.race)
	result.element = get_alignment_mix(creature_a.element, creature_b.element)
	result.display_name = _fusion_result_name(result.race, result.element)
	result.creature_id = "fused_%d" % randi()
	result.tier = maxi(creature_a.tier, creature_b.tier) as int
	result.is_player_controlled = true
	result.is_corrupted = creature_a.is_corrupted or creature_b.is_corrupted
	result.lore_text = "Born from the fusion of %s and %s. This union was ordained." % [
		creature_a.display_name, creature_b.display_name]

	# Stats: average * 1.1 bonus
	result.max_hp = int((creature_a.max_hp + creature_b.max_hp) / 2.0 * 1.1)
	result.hp = result.max_hp
	result.max_sp = int((creature_a.max_sp + creature_b.max_sp) / 2.0 * 1.1)
	result.sp = result.max_sp
	result.atk = int((creature_a.atk + creature_b.atk) / 2.0 * 1.1)
	result.defense = int((creature_a.defense + creature_b.defense) / 2.0 * 1.1)
	result.mag = int((creature_a.mag + creature_b.mag) / 2.0 * 1.1)
	result.res = int((creature_a.res + creature_b.res) / 2.0 * 1.1)
	result.spd = int((creature_a.spd + creature_b.spd) / 2.0 * 1.1)

	# Skill inheritance: 2 from each parent (highest power preferred), max 4
	var skills_a := creature_a.skills.duplicate(true)
	var skills_b := creature_b.skills.duplicate(true)
	skills_a.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.power > b.power)
	skills_b.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.power > b.power)

	result.skills.clear()
	var skill_names_used: Array = []
	for s in skills_a.slice(0, 2):
		if not skill_names_used.has(s.name):
			result.skills.append(s.duplicate())
			skill_names_used.append(s.name)
	for s in skills_b.slice(0, 2):
		if result.skills.size() >= 4:
			break
		if not skill_names_used.has(s.name):
			result.skills.append(s.duplicate())
			skill_names_used.append(s.name)

	# If corrupted, strip Innocent skills
	if result.is_corrupted:
		result.skills = result.skills.filter(
			func(s: Dictionary) -> bool: return int(s.element) != Element.INNOCENT)

	return result


func _fusion_result_name(result_race: int, result_element: int) -> String:
	## Generate a name for a fusion result based on race + element.
	var race_name: String = RACE_NAMES.get(result_race, "Unknown")
	var elem_name: String = ELEMENT_NAMES.get(result_element, "Unknown")
	return elem_name + " " + race_name


# ==========================================================================
#  NEGOTIATION DIALOGUE
# ==========================================================================

## Each race has an array of dialogue exchanges.
## Each exchange: { "prompt": String, "options": [{ "text": String, "score": int }, ...] }
var NEGOTIATION_DIALOGUES := {
	Race.BEAST: [
		{ "prompt": "The creature snarls and paws the ground, sizing you up.",
		  "options": [
			{ "text": "Stand tall and meet its gaze.", "score": 2 },
			{ "text": "Offer food from your pack.", "score": 1 },
			{ "text": "Back away slowly.", "score": -1 },
			{ "text": "Try to trick it into submission.", "score": -2 },
		  ] },
		{ "prompt": "It growls low, testing your resolve.",
		  "options": [
			{ "text": "Growl back — show you are not prey.", "score": 2 },
			{ "text": "Hold still and wait patiently.", "score": 1 },
			{ "text": "Plead for mercy.", "score": -2 },
			{ "text": "Whistle a calming tune.", "score": 0 },
		  ] },
		{ "prompt": "The beast circles you once, then stops. It seems to be deciding.",
		  "options": [
			{ "text": "Show your battle scars proudly.", "score": 2 },
			{ "text": "Lower your weapon as a sign of respect.", "score": 1 },
			{ "text": "Shout to intimidate it.", "score": -1 },
			{ "text": "Run away screaming.", "score": -2 },
		  ] },
		{ "prompt": "It sniffs the air around you, curious.",
		  "options": [
			{ "text": "Let it approach — show no fear.", "score": 2 },
			{ "text": "Toss it something to eat.", "score": 1 },
			{ "text": "Swat at it nervously.", "score": -1 },
			{ "text": "Try to leash it.", "score": -2 },
		  ] },
	],
	Race.CELESTIALITE: [
		{ "prompt": "\"Mortal, why do you disturb the ordained order?\"",
		  "options": [
			{ "text": "\"I come humbly, seeking guidance.\"", "score": 2 },
			{ "text": "\"The Firmament itself is fractured — I must act.\"", "score": 1 },
			{ "text": "\"I need your power for my quest.\"", "score": -1 },
			{ "text": "\"Step aside or be moved.\"", "score": -2 },
		  ] },
		{ "prompt": "\"Do you understand what it means to serve a purpose greater than yourself?\"",
		  "options": [
			{ "text": "\"I am but a vessel for what was ordained.\"", "score": 2 },
			{ "text": "\"I try to, though I am imperfect.\"", "score": 1 },
			{ "text": "\"I serve only myself.\"", "score": -2 },
			{ "text": "\"Purpose is a chain. I choose freedom.\"", "score": -1 },
		  ] },
		{ "prompt": "\"Your soul... I sense no Corruption. Is this true?\"",
		  "options": [
			{ "text": "\"By grace alone, I remain Innocent.\"", "score": 2 },
			{ "text": "\"I strive to remain pure, though it is hard.\"", "score": 1 },
			{ "text": "\"What does it matter to you?\"", "score": -1 },
			{ "text": "\"Corruption is just another kind of strength.\"", "score": -2 },
		  ] },
		{ "prompt": "\"Many seek the Firmament for power. What do you seek?\"",
		  "options": [
			{ "text": "\"To restore what was broken, if it is ordained.\"", "score": 2 },
			{ "text": "\"To protect those who cannot protect themselves.\"", "score": 1 },
			{ "text": "\"Knowledge. The truth of this world.\"", "score": 0 },
			{ "text": "\"The power to crush my enemies.\"", "score": -2 },
		  ] },
	],
	Race.SEER: [
		{ "prompt": "\"I saw you coming. Tell me — what do you see when you close your eyes?\"",
		  "options": [
			{ "text": "\"I see the threads of fate, woven before time.\"", "score": 2 },
			{ "text": "\"Darkness. But I press forward anyway.\"", "score": 1 },
			{ "text": "\"Nothing. Visions are a waste of time.\"", "score": -2 },
			{ "text": "\"I see... myself, winning this negotiation.\"", "score": -1 },
		  ] },
		{ "prompt": "\"A riddle: I am always coming but never arrive. What am I?\"",
		  "options": [
			{ "text": "\"Tomorrow.\"", "score": 2 },
			{ "text": "\"The future... which is already ordained.\"", "score": 2 },
			{ "text": "\"I don't have time for riddles.\"", "score": -2 },
			{ "text": "\"A Serpent's promise.\"", "score": 0 },
		  ] },
		{ "prompt": "\"Patience is the root of all prophecy. Can you wait?\"",
		  "options": [
			{ "text": "\"As long as it takes.\"", "score": 2 },
			{ "text": "\"I will try.\"", "score": 1 },
			{ "text": "\"No. There is no time.\"", "score": -1 },
			{ "text": "\"Prophecy is nonsense.\"", "score": -2 },
		  ] },
		{ "prompt": "\"I have foreseen two paths for you. Which do you choose — the easy road or the true one?\"",
		  "options": [
			{ "text": "\"The true one, even if it costs me everything.\"", "score": 2 },
			{ "text": "\"Tell me more before I decide.\"", "score": 1 },
			{ "text": "\"The easy road. I'm no fool.\"", "score": -1 },
			{ "text": "\"I'll make my own path.\"", "score": 0 },
		  ] },
	],
	Race.SERPENT: [
		{ "prompt": "\"Ssso... you want something from me. Everyone does. What will you offer?\"",
		  "options": [
			{ "text": "\"Your scales are magnificent — a creature of rare beauty.\"", "score": 2 },
			{ "text": "\"A fair partnership. We both gain.\"", "score": 1 },
			{ "text": "\"I offer nothing. Join me or don't.\"", "score": -2 },
			{ "text": "\"I know your kind — I won't be deceived.\"", "score": -1 },
		  ] },
		{ "prompt": "\"I could tell you a secret... for a price. Just a small Soul offering?\"",
		  "options": [
			{ "text": "\"Your secrets are surely worth the price.\"", "score": 2 },
			{ "text": "\"I'll listen, but I make no promises.\"", "score": 1 },
			{ "text": "\"I'd never trade my soul to a Serpent.\"", "score": -1 },
			{ "text": "\"Keep your secrets. I don't need them.\"", "score": -2 },
		  ] },
		{ "prompt": "\"Trust is such a fragile thing, don't you think?\"",
		  "options": [
			{ "text": "\"Between clever creatures, trust is earned through mutual benefit.\"", "score": 2 },
			{ "text": "\"I'll trust you if you prove worthy.\"", "score": 1 },
			{ "text": "\"I don't trust you at all.\"", "score": -1 },
			{ "text": "\"Trust is for fools.\"", "score": 0 },
		  ] },
		{ "prompt": "\"Tell me — do you think you're smarter than me?\"",
		  "options": [
			{ "text": "\"Smarter? No. But together we'd be unstoppable.\"", "score": 2 },
			{ "text": "\"I think we are equally cunning.\"", "score": 1 },
			{ "text": "\"Obviously.\"", "score": -2 },
			{ "text": "\"Intelligence is overrated.\"", "score": -1 },
		  ] },
	],
	Race.DARKNESS: [
		{ "prompt": "\"You dare approach me? Show me your darkness, mortal.\"",
		  "options": [
			{ "text": "\"I have tasted Corruption. I know its power.\"", "score": 2 },
			{ "text": "\"I do not fear the dark — I walk through it.\"", "score": 1 },
			{ "text": "\"I come in the name of Innocence!\"", "score": -2 },
			{ "text": "\"I don't want to show you anything.\"", "score": -1 },
		  ] },
		{ "prompt": "\"Give me your Soul Points. One... just one. To prove your commitment.\"",
		  "options": [
			{ "text": "\"Take it. Power requires sacrifice.\"", "score": 2 },
			{ "text": "\"A small price for an ally like you.\"", "score": 1 },
			{ "text": "\"My SP is not for sale.\"", "score": -1 },
			{ "text": "\"Never! Back, creature of shadow!\"", "score": -2 },
		  ] },
		{ "prompt": "\"The Heap is my home. The Firmament rejected me. Why should I help YOU?\"",
		  "options": [
			{ "text": "\"Because I understand rejection. We are alike.\"", "score": 2 },
			{ "text": "\"Because the Firmament is cracking — even the Heap will fall.\"", "score": 1 },
			{ "text": "\"Because I'll destroy you if you refuse.\"", "score": 0 },
			{ "text": "\"I pity you, creature.\"", "score": -2 },
		  ] },
		{ "prompt": "\"Weakness disgusts me. Are you strong enough to walk with Darkness?\"",
		  "options": [
			{ "text": "\"I have crushed your kind before. I am strong enough.\"", "score": 2 },
			{ "text": "\"Strength comes in many forms.\"", "score": 1 },
			{ "text": "\"I don't need to prove myself to you.\"", "score": -1 },
			{ "text": "\"True strength is in gentleness.\"", "score": -2 },
		  ] },
	],
	Race.INSECT: [
		{ "prompt": "Thousands of tiny eyes regard you from the swarm. Click-click-click.",
		  "options": [
			{ "text": "Extend your hand into the swarm fearlessly.", "score": 2 },
			{ "text": "Stand still and let them investigate you.", "score": 1 },
			{ "text": "Swat at the nearest ones.", "score": -2 },
			{ "text": "Try to address the largest one individually.", "score": -1 },
		  ] },
		{ "prompt": "The swarm pulses in unison, forming a shape — a question mark.",
		  "options": [
			{ "text": "Mirror the shape with your hands.", "score": 2 },
			{ "text": "Nod slowly to show understanding.", "score": 1 },
			{ "text": "Try to scatter them.", "score": -2 },
			{ "text": "Shrug in confusion.", "score": 0 },
		  ] },
		{ "prompt": "A cluster breaks off and orbits you. They seem to be counting you.",
		  "options": [
			{ "text": "Hold perfectly still — be one with the many.", "score": 2 },
			{ "text": "Hum softly — a shared frequency.", "score": 1 },
			{ "text": "Brush them off.", "score": -1 },
			{ "text": "Light a torch to drive them away.", "score": -2 },
		  ] },
	],
	Race.DRAGON: [
		{ "prompt": "The dragon lowers its massive head to your level. Smoke curls from its nostrils.",
		  "options": [
			{ "text": "Kneel and present your weapon as tribute.", "score": 2 },
			{ "text": "Bow your head in respect.", "score": 1 },
			{ "text": "Stare it down — you will not be cowed.", "score": 0 },
			{ "text": "\"You're smaller than I expected.\"", "score": -2 },
		  ] },
		{ "prompt": "\"SPEAK, MORTAL. WHY SHOULD I NOT REDUCE YOU TO ASH?\"",
		  "options": [
			{ "text": "\"Because my quest serves the same purpose as your vigil, great one.\"", "score": 2 },
			{ "text": "\"Because I bring tribute worthy of your magnificence.\"", "score": 1 },
			{ "text": "\"Because you can't.\"", "score": -2 },
			{ "text": "\"Please don't!\"", "score": -1 },
		  ] },
		{ "prompt": "The dragon exhales a ring of fire around you. A test.",
		  "options": [
			{ "text": "Walk through the flames without flinching.", "score": 2 },
			{ "text": "Wait calmly inside the ring.", "score": 1 },
			{ "text": "Jump through desperately.", "score": -1 },
			{ "text": "Beg it to stop.", "score": -2 },
		  ] },
	],
	Race.SEA_CREATURE: [
		{ "prompt": "The creature ripples and shifts, its form fluid as water.",
		  "options": [
			{ "text": "Match its fluidity — sway gently.", "score": 2 },
			{ "text": "Wait patiently, like the tide.", "score": 1 },
			{ "text": "Try to pin it down.", "score": -2 },
			{ "text": "Splash at it.", "score": -1 },
		  ] },
		{ "prompt": "A low, melodic hum emanates from the creature. It seems to be asking something.",
		  "options": [
			{ "text": "Hum back in harmony.", "score": 2 },
			{ "text": "Listen quietly and nod.", "score": 1 },
			{ "text": "Shout over the humming.", "score": -2 },
			{ "text": "Cover your ears.", "score": -1 },
		  ] },
		{ "prompt": "The water around it stills. It seems to be waiting for something.",
		  "options": [
			{ "text": "Be calm. Let the moment flow.", "score": 2 },
			{ "text": "Gently ripple the water toward it.", "score": 1 },
			{ "text": "Throw a stone into the water.", "score": -1 },
			{ "text": "Demand its attention.", "score": -2 },
		  ] },
	],
}


func get_negotiation_exchanges(creature_race: int, count: int = 2) -> Array:
	## Return 'count' random dialogue exchanges for the given race.
	var pool: Array = NEGOTIATION_DIALOGUES.get(creature_race, [])
	if pool.is_empty():
		return []
	pool = pool.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func get_recruitment_threshold(creature_tier: int) -> int:
	## Affinity needed to recruit, based on tier.
	match creature_tier:
		Tier.TRASH: return 2
		Tier.COMMON: return 3
		Tier.MID: return 4
		Tier.STRONG: return 5
		_: return 99  # Boss/superboss: not recruitable


func get_alignment_affinity_mod(player_corrupted: bool, creature_element: int) -> int:
	## Corruption/Innocence modifiers to negotiation affinity.
	if player_corrupted:
		if creature_element == Element.INNOCENT:
			return -3  # Almost impossible
		if creature_element == Element.CORRUPT:
			return 2  # Easier
	else:
		if creature_element == Element.INNOCENT:
			return 1  # Slightly easier
		if creature_element == Element.CORRUPT:
			return -1  # Slightly harder
	return 0
