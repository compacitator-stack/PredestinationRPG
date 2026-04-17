class_name Combatant
extends RefCounted

## A single combat participant — party member or enemy.
## Extended in Phase 2 with race, tier, lore, fusion, and Soul Investment tracking.

var display_name: String = ""
var element: int = 0  # CombatData.Element value
var race: int = 0  # CombatData.Race value
var tier: int = 0  # CombatData.Tier value
var creature_id: String = ""  # Unique ID for creature database lookup / compendium
var lore_text: String = ""
var card_game_ref: String = ""  # Which card this creature comes from

var max_hp: int = 1
var hp: int = 1
var max_sp: int = 0
var sp: int = 0
var atk: int = 1
var defense: int = 1
var mag: int = 1
var res: int = 1
var spd: int = 1

# Phase A stat additions — scaffolding only, no behavior applied yet.
# 0 max = "system inactive for this combatant" (preserves legacy behavior).
var max_posture: int = 0
var posture: int = 0
var max_resolve: int = 0
var resolve: int = 0
var threat: int = 100
var awareness: int = 0
var behavior_family: String = ""  # "Striker" | "Warden" | "Ritualist" | "Bulwark" | "" (legacy)
var is_posture_broken: bool = false
# Tracks damage between the combatant's own turns (for Posture regen gate).
var took_damage_since_last_turn: bool = false
# Transient flag set by take_damage — true only immediately after the call
# that *just* broke posture, for single-site UI reporting.
var _last_hit_broke_posture: bool = false

# Soul Investment tracking — how many points invested per stat
var invested: Dictionary = { "hp": 0, "atk": 0, "defense": 0, "mag": 0, "res": 0, "spd": 0 }

var skills: Array = []  # Array of skill dictionaries
var is_player_controlled: bool = false
var is_corrupted: bool = false
var is_guarding: bool = false
var corrupt_boost_active: bool = false
var ai_type: String = "aggressive"  # aggressive, support (legacy; superseded by behavior_family)
var is_recruitable: bool = true  # Boss/superboss = false


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int, posture_dmg_amount: int = 0) -> int:
	_last_hit_broke_posture = false
	var actual := amount
	if is_guarding:
		actual = maxi(1, int(float(amount) * 0.5))
	hp = maxi(0, hp - actual)
	took_damage_since_last_turn = true
	if max_posture > 0 and posture_dmg_amount > 0 and not is_posture_broken:
		posture = maxi(0, posture - posture_dmg_amount)
		if posture == 0:
			is_posture_broken = true
			_last_hit_broke_posture = true
	return actual


func just_broke_posture() -> bool:
	return _last_hit_broke_posture


func heal_hp(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + amount)
	return hp - before


func restore_sp(amount: int) -> void:
	sp = mini(max_sp, sp + amount)


func spend_sp(amount: int) -> bool:
	if sp >= amount:
		sp -= amount
		return true
	return false


func duplicate_combatant() -> Combatant:
	var c := Combatant.new()
	c.display_name = display_name
	c.element = element
	c.race = race
	c.tier = tier
	c.creature_id = creature_id
	c.lore_text = lore_text
	c.card_game_ref = card_game_ref
	c.max_hp = max_hp; c.hp = hp
	c.max_sp = max_sp; c.sp = sp
	c.atk = atk; c.defense = defense; c.mag = mag; c.res = res; c.spd = spd
	c.max_posture = max_posture; c.posture = posture
	c.max_resolve = max_resolve; c.resolve = resolve
	c.threat = threat
	c.awareness = awareness
	c.behavior_family = behavior_family
	c.is_posture_broken = is_posture_broken
	c.invested = invested.duplicate()
	c.skills = skills.duplicate(true)
	c.is_player_controlled = is_player_controlled
	c.is_corrupted = is_corrupted
	c.ai_type = ai_type
	c.is_recruitable = is_recruitable
	return c


func get_investment_cap() -> int:
	## Max total SP that can be invested, based on tier.
	match tier:
		CombatData.Tier.TRASH: return 5
		CombatData.Tier.COMMON: return 10
		CombatData.Tier.MID: return 20
		CombatData.Tier.STRONG: return 30
		CombatData.Tier.BOSS: return 50
		_: return 10


func total_invested() -> int:
	var total := 0
	for v in invested.values():
		total += v
	return total
