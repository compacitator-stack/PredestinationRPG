extends Node

## Manages the Decree system — pre-ordained combat actions set at save altars.
## Autoloaded as "DecreeSystem".
##
## Each Decree has a Condition (WHEN) and an Action (party member uses a skill).
## Decrees fire automatically in combat as free actions, then are spent.
## Set new Decrees at save altars via the Book of Decrees.

enum Condition {
	NONE,
	FIRST_TURN,
	ALLY_HP_CRITICAL,
	SP_BELOW_3,
	ENEMY_TARGETS_HEALER,
	ENCOUNTER_CORRUPT,
}

const CONDITION_NAMES: Dictionary = {
	Condition.NONE: "-- Empty --",
	Condition.FIRST_TURN: "First turn of battle",
	Condition.ALLY_HP_CRITICAL: "Ally HP below 25%",
	Condition.SP_BELOW_3: "Any ally SP below 3",
	Condition.ENEMY_TARGETS_HEALER: "Enemy targets healer",
	Condition.ENCOUNTER_CORRUPT: "Fighting Corrupt enemy",
}

const CONDITION_LIST: Array = [
	Condition.FIRST_TURN,
	Condition.ALLY_HP_CRITICAL,
	Condition.SP_BELOW_3,
	Condition.ENEMY_TARGETS_HEALER,
	Condition.ENCOUNTER_CORRUPT,
]

const MAX_SLOTS: int = 2

## Each decree: { "condition": int, "member_name": String, "skill_name": String, "spent": bool }
var decrees: Array = []


func _ready() -> void:
	clear_all()


func clear_all() -> void:
	decrees.clear()
	for i in MAX_SLOTS:
		decrees.append(_empty_decree())


func _empty_decree() -> Dictionary:
	return { "condition": Condition.NONE, "member_name": "", "skill_name": "", "spent": false }


func set_decree(slot: int, condition: int, member_name: String, skill_name: String) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	decrees[slot] = {
		"condition": condition,
		"member_name": member_name,
		"skill_name": skill_name,
		"spent": false,
	}


func clear_decree(slot: int) -> void:
	if slot >= 0 and slot < MAX_SLOTS:
		decrees[slot] = _empty_decree()


func grant_gallant_decree() -> void:
	## Flavor-named preset granted by the Wounded Celestialite on floor 1.
	## Writes to slot 0; player can overwrite at the first altar like any decree.
	set_decree(0, Condition.FIRST_TURN, "Seer", "Mystic Ray")


func reset_spent() -> void:
	for d in decrees:
		d.spent = false


func get_triggered(trigger: int, party: Array, enemies: Array,
		context: Dictionary = {}) -> Array:
	var result: Array = []
	for i in range(decrees.size()):
		var d: Dictionary = decrees[i]
		var cond: int = int(d.condition)
		if cond == Condition.NONE or bool(d.spent):
			continue
		if _check_condition(cond, trigger, party, enemies, context):
			result.append(i)
	return result


func _check_condition(condition: int, trigger: int, party: Array,
		enemies: Array, context: Dictionary) -> bool:
	if condition != trigger:
		return false
	match condition:
		Condition.FIRST_TURN:
			return true
		Condition.ALLY_HP_CRITICAL:
			for c in party:
				if c.is_alive() and float(c.hp) < float(c.max_hp) * 0.25:
					return true
			return false
		Condition.SP_BELOW_3:
			for c in party:
				if c.is_alive() and c.sp < 3:
					return true
			return false
		Condition.ENEMY_TARGETS_HEALER:
			return context.get("target_is_healer", false)
		Condition.ENCOUNTER_CORRUPT:
			for e in enemies:
				if e.element == CombatData.Element.CORRUPT:
					return true
			return false
	return false


func mark_spent(slot: int) -> void:
	if slot >= 0 and slot < decrees.size():
		decrees[slot].spent = true


func find_member_and_skill(decree: Dictionary, party: Array) -> Dictionary:
	## Returns { "member": Combatant, "skill": Dictionary } or empty dict.
	var member_name: String = decree.member_name
	var skill_name: String = decree.skill_name
	for c in party:
		if c.display_name == member_name and c.is_alive():
			for s in c.skills:
				var s_name: String = s.name
				var s_cost: int = int(s.sp_cost)
				if s_name == skill_name and s_cost <= c.sp:
					return { "member": c, "skill": s }
	return {}


func get_condition_name(condition: int) -> String:
	var name: String = CONDITION_NAMES.get(condition, "Unknown")
	return name


func has_any_active() -> bool:
	for d in decrees:
		if int(d.condition) != Condition.NONE and not bool(d.spent):
			return true
	return false
