extends Node

## Manages encounter system, battle lifecycle, altar interactions,
## soul ledger, and save/load.
## Autoloaded as "GameManager".

const BattleSceneScript = preload("res://scripts/combat/battle_scene.gd")
const AltarMenuScript = preload("res://scripts/ui/altar_menu.gd")
const SoulLedgerScript = preload("res://scripts/ui/soul_ledger.gd")
const NpcDialogueScript = preload("res://scripts/ui/npc_dialogue.gd")

const CompendiumScript = preload("res://scripts/ui/compendium.gd")
const SoulInvestScript = preload("res://scripts/ui/soul_invest.gd")

var party: Array = []  # Active party (up to 4)
var reserve: Array = []  # Reserve creatures (up to 8)
var compendium_seen: Dictionary = {}  # creature_id -> true for all encountered creatures
var _player: Node = null
var _automap: Control = null
var _dungeon_map: Node = null
var _battle_active: bool = false
var _battle_scene: CanvasLayer = null
var _steps_to_encounter: int = 0
var _menu_open: bool = false
var _input_guard: int = 0  # Skip input processing for N frames after menu close

# Load-from-save state
var _pending_load: bool = false
var _load_data: ConfigFile = null

const MAX_ACTIVE := 4
const MAX_RESERVE := 8


func _ready() -> void:
	party = CombatData.create_party()
	# Mark starter creatures as seen in compendium
	for c in party:
		if c.creature_id != "":
			compendium_seen[c.creature_id] = true
	_reset_step_counter()
	# Start floor music
	var floor_info: Dictionary = FloorData.get_floor(FloorData.current_floor)
	var floor_name: String = floor_info.get("name", "")
	AudioManager.play_music_for_floor(floor_name)


func _process(_delta: float) -> void:
	# Discover player and dungeon map
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		if _player and _player.has_signal("step_completed"):
			if not _player.step_completed.is_connected(_on_player_step):
				_player.step_completed.connect(_on_player_step)
			_automap = _player.get_node_or_null("../Automap")

	if not _dungeon_map:
		_dungeon_map = get_tree().get_first_node_in_group("dungeon_map")
		if not _dungeon_map and _player:
			_dungeon_map = _player.get_node_or_null("../DungeonMap")

	# Apply saved game after scene reload
	if _pending_load and _player and _load_data:
		_apply_load_data()
		_pending_load = false
		_load_data = null

	# Input guard — prevents Escape re-trigger after menu close
	if _input_guard > 0:
		_input_guard -= 1
		return

	# Exploration input (not in battle, not paused by a menu)
	if not _battle_active and _player and not _menu_open:
		if Input.is_action_just_pressed("interact"):
			_try_interact()
		elif Input.is_action_just_pressed("ui_cancel"):
			_open_soul_ledger()


func _reset_step_counter() -> void:
	_steps_to_encounter = randi_range(14, 22)


func _on_player_step() -> void:
	if _battle_active:
		return
	# No random encounters on special tiles (altars, NPCs, stairs, boss)
	if _player and _dungeon_map:
		var tile: int = _dungeon_map.get_tile_type(_player.grid_pos)
		if tile != 0:
			return
		# No encounters in declared safe zones (e.g. altar room sanctuary)
		if _dungeon_map.is_safe_zone(_player.grid_pos):
			return
	_steps_to_encounter -= 1
	if _steps_to_encounter <= 0:
		_start_encounter()


# ==========================================================================
#  ENCOUNTERS & BATTLES
# ==========================================================================

func _start_encounter() -> void:
	_battle_active = true
	if _player:
		_player.battle_active = true
	if _automap:
		_automap.visible = false
	AudioManager.play_battle_music()

	# Use zone-specific encounter table if the player's tile has one, else floor default
	var table: Array = []
	if _dungeon_map:
		if _player:
			table = _dungeon_map.get_zone_encounter_table(_player.grid_pos)
		if table.is_empty() and _dungeon_map.floor_encounter_table.size() > 0:
			table = _dungeon_map.floor_encounter_table
	var enemies := CombatData.roll_encounter(table)
	# Mark all encountered enemies in compendium
	for e in enemies:
		mark_seen(e.creature_id)
	_battle_scene = BattleSceneScript.new()
	_battle_scene.party = party
	_battle_scene.enemies = enemies
	_battle_scene.battle_ended.connect(_on_battle_ended)
	get_tree().root.add_child(_battle_scene)


func _on_battle_ended(result: String) -> void:
	if _battle_scene:
		_battle_scene.queue_free()
		_battle_scene = null

	_battle_active = false
	AudioManager.on_battle_ended()

	match result:
		"victory", "fled":
			if _player:
				_player.battle_active = false
			if _automap:
				_automap.visible = true
			_reset_step_counter()
		"defeat":
			_load_from_save()


# ==========================================================================
#  ALTAR INTERACTION
# ==========================================================================

func _try_interact() -> void:
	if not _player or not _dungeon_map:
		return
	# Check tile the player is standing on (stairs, boss — still walkable)
	var tile_type: int = _dungeon_map.get_tile_type(_player.grid_pos)
	match tile_type:
		4:
			_interact_stairs()
			return
		5:
			_interact_boss()
			return
	# Check tile the player is facing (altars, NPCs are solid — interact by facing)
	var faced_pos: Vector2i = _player.grid_pos + _player.DIRECTIONS[_player.facing]
	var faced_tile: int = _dungeon_map.get_tile_type(faced_pos)
	match faced_tile:
		2: _interact_altar()
		3: _interact_npc(faced_pos)


func _interact_altar() -> void:
	# Heal HP (not SP) at the altar — both active and reserve
	for c in party:
		c.hp = c.max_hp
	for c in reserve:
		c.hp = c.max_hp

	# Reset decree spent flags for new altar visit
	DecreeSystem.reset_spent()

	# Save game state
	save_game()

	# Open Book of Decrees
	_open_altar_menu()


func _interact_npc(npc_pos: Vector2i) -> void:
	var npc_data: Dictionary = _dungeon_map.floor_npcs.get(npc_pos, {})
	if npc_data.is_empty():
		return
	_menu_open = true
	var dlg := NpcDialogueScript.new()
	dlg.npc_name = npc_data.get("name", "???")
	dlg.dialogue_lines = npc_data.get("dialogue", [])
	dlg.closed.connect(_on_menu_closed)
	get_tree().root.add_child(dlg)


func _interact_stairs() -> void:
	if not FloorData.is_boss_defeated(FloorData.current_floor):
		# Can't descend until boss is defeated — show a message
		_menu_open = true
		var dlg := NpcDialogueScript.new()
		dlg.npc_name = "Sealed Passage"
		dlg.dialogue_lines = [
			{"text": "The way forward is sealed by a dark presence.\nYou must defeat the guardian of this floor\nbefore you can descend."},
		]
		dlg.closed.connect(_on_menu_closed)
		get_tree().root.add_child(dlg)
		return
	# Transition to next floor
	_transition_to_floor(FloorData.current_floor + 1)


func _interact_boss() -> void:
	if FloorData.is_boss_defeated(FloorData.current_floor):
		return  # Already defeated
	var boss_data: Dictionary = _dungeon_map.floor_boss
	if boss_data.is_empty():
		return

	# Show pre-battle text, then start boss fight
	var pre_text: Array = boss_data.get("pre_text", [])
	if pre_text.is_empty():
		_start_boss_fight()
		return

	_menu_open = true
	var dlg := NpcDialogueScript.new()
	dlg.npc_name = "???"
	dlg.dialogue_lines = []
	for line in pre_text:
		dlg.dialogue_lines.append({"text": line})
	dlg.closed.connect(_on_boss_dialogue_done)
	get_tree().root.add_child(dlg)


func _on_boss_dialogue_done() -> void:
	_menu_open = false
	_input_guard = 2
	_start_boss_fight()


func _start_boss_fight() -> void:
	var boss_data: Dictionary = _dungeon_map.floor_boss
	var creature_id: String = boss_data.get("creature_id", "")
	if creature_id == "":
		return

	_battle_active = true
	if _player:
		_player.battle_active = true
	if _automap:
		_automap.visible = false
	AudioManager.play_boss_music(creature_id)

	var boss := CombatData.create_creature(creature_id)
	boss.is_player_controlled = false
	mark_seen(boss.creature_id)

	_battle_scene = BattleSceneScript.new()
	_battle_scene.party = party
	_battle_scene.enemies = [boss]
	_battle_scene.battle_ended.connect(_on_boss_battle_ended)
	get_tree().root.add_child(_battle_scene)


func _on_boss_battle_ended(result: String) -> void:
	if _battle_scene:
		_battle_scene.queue_free()
		_battle_scene = null

	_battle_active = false
	AudioManager.on_battle_ended()

	match result:
		"victory":
			FloorData.mark_boss_defeated(FloorData.current_floor)
			if _player:
				_player.battle_active = false
			if _automap:
				_automap.visible = true
			_reset_step_counter()
			# Show post-battle text
			var boss_data: Dictionary = _dungeon_map.floor_boss
			var post_text: Array = boss_data.get("post_text", [])
			if not post_text.is_empty():
				_menu_open = true
				var dlg := NpcDialogueScript.new()
				dlg.npc_name = "..."
				dlg.dialogue_lines = []
				for line in post_text:
					dlg.dialogue_lines.append({"text": line})
				dlg.closed.connect(_on_menu_closed)
				get_tree().root.add_child(dlg)
		"fled":
			if _player:
				_player.battle_active = false
			if _automap:
				_automap.visible = true
			_reset_step_counter()
		"defeat":
			_load_from_save()


func _transition_to_floor(floor_index: int) -> void:
	FloorData.current_floor = floor_index
	save_game()
	AudioManager.stop_music(false)
	_player = null
	_automap = null
	_dungeon_map = null
	_reset_step_counter()
	get_tree().reload_current_scene()


func _open_altar_menu() -> void:
	_menu_open = true
	var menu := AltarMenuScript.new()
	menu.party = party
	menu.closed.connect(_on_menu_closed)
	get_tree().root.add_child(menu)


func _open_soul_ledger() -> void:
	_menu_open = true
	var ledger := SoulLedgerScript.new()
	ledger.party = party
	ledger.closed.connect(_on_menu_closed)
	get_tree().root.add_child(ledger)


func _on_menu_closed() -> void:
	_menu_open = false
	_input_guard = 2  # Prevent Escape re-trigger for 2 frames


# ==========================================================================
#  PARTY MANAGEMENT
# ==========================================================================

func recruit_creature(creature: Combatant) -> bool:
	## Add a recruited creature to party or reserve. Returns false if both are full.
	creature.is_player_controlled = true
	if creature.creature_id != "":
		compendium_seen[creature.creature_id] = true
	if party.size() < MAX_ACTIVE:
		party.append(creature)
		return true
	elif reserve.size() < MAX_RESERVE:
		reserve.append(creature)
		return true
	return false


func swap_party_member(party_idx: int, reserve_idx: int) -> void:
	## Swap an active party member with a reserve creature.
	if party_idx < 0 or party_idx >= party.size():
		return
	if reserve_idx < 0 or reserve_idx >= reserve.size():
		return
	var temp: Combatant = party[party_idx]
	party[party_idx] = reserve[reserve_idx]
	reserve[reserve_idx] = temp


func remove_from_party(creature: Combatant) -> void:
	## Remove a creature from active party or reserve (for fusion consumption).
	var idx := party.find(creature)
	if idx >= 0:
		party.remove_at(idx)
		return
	idx = reserve.find(creature)
	if idx >= 0:
		reserve.remove_at(idx)


func get_all_creatures() -> Array:
	## Return all active + reserve creatures.
	return party + reserve


func mark_seen(creature_id: String) -> void:
	if creature_id != "":
		compendium_seen[creature_id] = true


func open_compendium() -> void:
	_menu_open = true
	var comp := CompendiumScript.new()
	comp.compendium_seen = compendium_seen
	comp.closed.connect(_on_menu_closed)
	get_tree().root.add_child(comp)


func open_soul_invest() -> void:
	_menu_open = true
	var invest := SoulInvestScript.new()
	invest.party = party
	invest.reserve = reserve
	invest.closed.connect(_on_menu_closed)
	get_tree().root.add_child(invest)


# ==========================================================================
#  SAVE / LOAD
# ==========================================================================

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "party_size", party.size())
	cfg.set_value("meta", "reserve_size", reserve.size())
	cfg.set_value("meta", "current_floor", FloorData.current_floor)
	# Save boss defeat flags
	var defeated_floors: Array = FloorData.boss_defeated.keys()
	cfg.set_value("meta", "boss_defeated", defeated_floors)

	# Save active party
	for i in range(party.size()):
		_save_combatant(cfg, "party_%d" % i, party[i])

	# Save reserve
	for i in range(reserve.size()):
		_save_combatant(cfg, "reserve_%d" % i, reserve[i])

	# Save compendium
	var seen_list: Array = compendium_seen.keys()
	cfg.set_value("compendium", "seen", seen_list)

	if _player:
		cfg.set_value("player", "grid_pos_x", _player.grid_pos.x)
		cfg.set_value("player", "grid_pos_y", _player.grid_pos.y)
		cfg.set_value("player", "facing", _player.facing)

	for i in range(DecreeSystem.MAX_SLOTS):
		var d: Dictionary = DecreeSystem.decrees[i]
		var sec: String = "decree_%d" % i
		cfg.set_value(sec, "condition", int(d.condition))
		cfg.set_value(sec, "member_name", String(d.member_name))
		cfg.set_value(sec, "skill_name", String(d.skill_name))

	cfg.save("user://save.cfg")


func _save_combatant(cfg: ConfigFile, sec: String, c: Combatant) -> void:
	cfg.set_value(sec, "display_name", c.display_name)
	cfg.set_value(sec, "creature_id", c.creature_id)
	cfg.set_value(sec, "element", c.element)
	cfg.set_value(sec, "race", c.race)
	cfg.set_value(sec, "tier", c.tier)
	cfg.set_value(sec, "hp", c.hp)
	cfg.set_value(sec, "max_hp", c.max_hp)
	cfg.set_value(sec, "sp", c.sp)
	cfg.set_value(sec, "max_sp", c.max_sp)
	cfg.set_value(sec, "atk", c.atk)
	cfg.set_value(sec, "defense", c.defense)
	cfg.set_value(sec, "mag", c.mag)
	cfg.set_value(sec, "res", c.res)
	cfg.set_value(sec, "spd", c.spd)
	cfg.set_value(sec, "is_corrupted", c.is_corrupted)
	cfg.set_value(sec, "invested", c.invested)
	cfg.set_value(sec, "lore_text", c.lore_text)
	# Save skills array (needed for fused/starter creatures not in CREATURE_DB)
	var skill_data: Array = []
	for s in c.skills:
		skill_data.append({
			"name": s.name,
			"element": int(s.element),
			"power": int(s.power),
			"sp_cost": int(s.sp_cost),
			"is_magical": bool(s.get("is_magical", false)),
			"is_heal": bool(s.get("is_heal", false)),
		})
	cfg.set_value(sec, "skills", skill_data)


func _load_from_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		_load_data = cfg
		_pending_load = true
		# Restore floor before reloading scene
		FloorData.current_floor = cfg.get_value("meta", "current_floor", 0)
		var defeated: Array = cfg.get_value("meta", "boss_defeated", [])
		FloorData.boss_defeated.clear()
		for f in defeated:
			FloorData.boss_defeated[f] = true
		_player = null
		_automap = null
		_dungeon_map = null
		_reset_step_counter()
		get_tree().reload_current_scene()
	else:
		# No save file — fresh start
		party = CombatData.create_party()
		reserve.clear()
		compendium_seen.clear()
		DecreeSystem.clear_all()
		_player = null
		_automap = null
		_dungeon_map = null
		_reset_step_counter()
		get_tree().reload_current_scene()


func _apply_load_data() -> void:
	var cfg := _load_data

	# Restore floor state
	FloorData.current_floor = cfg.get_value("meta", "current_floor", 0)
	var defeated: Array = cfg.get_value("meta", "boss_defeated", [])
	FloorData.boss_defeated.clear()
	for f in defeated:
		FloorData.boss_defeated[f] = true

	# Restore active party
	var party_count: int = cfg.get_value("meta", "party_size", 2)
	party.clear()
	for i in range(party_count):
		var c := _load_combatant(cfg, "party_%d" % i)
		if c:
			party.append(c)

	# Fallback if no party loaded
	if party.is_empty():
		party = CombatData.create_party()

	# Restore reserve
	var reserve_count: int = cfg.get_value("meta", "reserve_size", 0)
	reserve.clear()
	for i in range(reserve_count):
		var c := _load_combatant(cfg, "reserve_%d" % i)
		if c:
			reserve.append(c)

	# Restore compendium
	var seen_list: Array = cfg.get_value("compendium", "seen", [])
	compendium_seen.clear()
	for cid in seen_list:
		compendium_seen[cid] = true

	# Restore player position
	var gx: int = cfg.get_value("player", "grid_pos_x", _player.grid_pos.x)
	var gy: int = cfg.get_value("player", "grid_pos_y", _player.grid_pos.y)
	var facing: int = cfg.get_value("player", "facing", _player.facing)
	_player.grid_pos = Vector2i(gx, gy)
	_player.facing = facing
	_player._snap_to_grid()

	# Restore decrees
	for i in range(DecreeSystem.MAX_SLOTS):
		var sec: String = "decree_%d" % i
		if cfg.has_section(sec):
			var cond: int = cfg.get_value(sec, "condition", 0)
			var member: String = cfg.get_value(sec, "member_name", "")
			var skill: String = cfg.get_value(sec, "skill_name", "")
			if cond != DecreeSystem.Condition.NONE:
				DecreeSystem.set_decree(i, cond, member, skill)


func _load_combatant(cfg: ConfigFile, sec: String) -> Combatant:
	if not cfg.has_section(sec):
		return null
	var creature_id: String = cfg.get_value(sec, "creature_id", "")
	var c: Combatant
	# Try to build from creature database for full skill/data restoration
	if creature_id != "" and CombatData.CREATURE_DB.has(creature_id):
		c = CombatData.create_creature(creature_id)
	else:
		c = Combatant.new()
		c.creature_id = creature_id
	c.display_name = cfg.get_value(sec, "display_name", c.display_name)
	c.element = cfg.get_value(sec, "element", c.element)
	c.race = cfg.get_value(sec, "race", c.race)
	c.tier = cfg.get_value(sec, "tier", c.tier)
	c.max_hp = cfg.get_value(sec, "max_hp", c.max_hp)
	c.hp = cfg.get_value(sec, "hp", c.hp)
	c.max_sp = cfg.get_value(sec, "max_sp", c.max_sp)
	c.sp = cfg.get_value(sec, "sp", c.sp)
	c.atk = cfg.get_value(sec, "atk", c.atk)
	c.defense = cfg.get_value(sec, "defense", c.defense)
	c.mag = cfg.get_value(sec, "mag", c.mag)
	c.res = cfg.get_value(sec, "res", c.res)
	c.spd = cfg.get_value(sec, "spd", c.spd)
	c.is_corrupted = cfg.get_value(sec, "is_corrupted", false)
	c.invested = cfg.get_value(sec, "invested", c.invested)
	c.lore_text = cfg.get_value(sec, "lore_text", c.lore_text)
	c.is_player_controlled = true
	# Restore skills from save data if creature wasn't rebuilt from CREATURE_DB
	var saved_skills: Array = cfg.get_value(sec, "skills", [])
	if saved_skills.size() > 0 and (not CombatData.CREATURE_DB.has(creature_id)):
		c.skills.clear()
		for sd in saved_skills:
			c.skills.append({
				"name": String(sd.name),
				"element": int(sd.element),
				"power": int(sd.power),
				"sp_cost": int(sd.sp_cost),
				"is_magical": bool(sd.get("is_magical", false)),
				"is_heal": bool(sd.get("is_heal", false)),
			})
	if c.is_corrupted:
		c.skills = c.skills.filter(func(s: Dictionary) -> bool:
			return int(s.element) != CombatData.Element.INNOCENT)
	return c
