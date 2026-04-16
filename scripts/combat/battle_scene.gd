extends CanvasLayer

## Turn-based SMT-style battle system with SP economy and Corruption mechanic.
## Created by GameManager; added to scene tree when an encounter triggers.

signal battle_ended(result: String)  # "victory", "defeat", "fled"

const NegotiationScript = preload("res://scripts/combat/negotiation.gd")

enum State {
	INTRO,
	PLAYER_CHOOSING,
	SKILL_SELECT,
	TARGET_SELECT,
	CORRUPT_CONFIRM,
	EXECUTING,
	ENEMY_TURN,
	DECREE_FIRING,
	NEGOTIATING,
	VICTORY,
	DEFEAT,
}

# --- State ---
var state: int = State.INTRO
var party: Array = []
var enemies: Array = []
var turn_order: Array = []
var turn_idx: int = -1
var actor: Combatant = null

# --- Menu ---
var menu_cursor: int = 0
var menu_items: Array = []
var target_cursor: int = 0
var target_list: Array = []
var targeting_allies: bool = false
var pending_action: String = ""
var pending_skill: Dictionary = {}
var skill_list: Array = []
var corrupt_cursor: int = 1  # 0=Yes, 1=No (default No)

# --- Timers ---
var intro_timer: float = 0.0
var exec_timer: float = 0.0
var enemy_timer: float = 0.0
var end_timer: float = 0.0
var _fled: bool = false
var _was_enemy_action: bool = false
var _enemy_targeted_healer: bool = false

# --- Decrees ---
var _decree_queue: Array = []
var _decree_timer: float = 0.0
var _decree_resume: String = ""  # Method name to call after decrees finish

# --- Innocence ---
var party_innocent: bool = true

# --- UI node refs ---
var _bg: ColorRect
var _flash: ColorRect
var _msg_label: Label
var _sub_msg: Label
var _menu_title: Label
var _menu_labels: Array = []
var _target_indicator: Label

# Per-enemy UI: { sprite, name_lbl, hp_bg, hp_fill, hp_text, center_x }
var _enemy_ui: Array = []
# Per-party UI: { name_lbl, hp_bg, hp_fill, hp_text, sp_bg, sp_fill, sp_text, y_pos }
var _party_ui: Array = []

const MENU_X := 370
const MENU_Y := 280
const MENU_LINE_H := 22
const PARTY_X := 15
const PARTY_Y := 262
const PARTY_ROW_H := 62
const HP_BAR_W := 130.0
const SP_BAR_W := 100.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in party:
		if c.is_corrupted:
			party_innocent = false
			break
	_build_ui()
	_start_intro()


# ==========================================================================
#  UI CONSTRUCTION
# ==========================================================================

func _make_rect(pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _make_label(pos: Vector2, sz: Vector2, text: String,
		font_size: int = 14, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _element_color(elem: int) -> Color:
	return CombatData.ELEMENT_COLORS.get(elem, Color.GRAY)


const SPRITE_DIR := "res://assets/sprites/battle/"

func _load_creature_sprite(creature_id: String, sz: Vector2, pos: Vector2) -> TextureRect:
	## Load a creature battle sprite. Falls back to a colored rect if file missing.
	var tex_rect := TextureRect.new()
	tex_rect.position = pos
	tex_rect.size = sz
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := SPRITE_DIR + creature_id + ".png"
	if ResourceLoader.exists(path):
		tex_rect.texture = load(path)
	else:
		# Fallback: try without fused_ prefix or use a placeholder
		var fallback := SPRITE_DIR + "shade.png"
		if ResourceLoader.exists(fallback):
			tex_rect.texture = load(fallback)
			tex_rect.modulate = _element_color(0)  # tint as hint
	add_child(tex_rect)
	return tex_rect


func _build_ui() -> void:
	_bg = _make_rect(Vector2.ZERO, Vector2(640, 480), UITheme.BATTLE_BG)
	_flash = _make_rect(Vector2.ZERO, Vector2(640, 480), Color(1, 1, 1, 0))

	_build_enemy_display()

	# Separator line
	_make_rect(Vector2(0, 248), Vector2(640, 2), UITheme.BATTLE_SEPARATOR)

	_build_party_display()
	_build_menu()

	# Central message (BATTLE!, VICTORY!, etc.)
	_msg_label = _make_label(Vector2(0, 160), Vector2(640, 50), "", 28, UITheme.TEXT)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.visible = false

	# Sub-message (WEAKNESS!, skill names, etc.)
	_sub_msg = _make_label(Vector2(0, 215), Vector2(640, 26), "", 15, UITheme.TEXT)
	_sub_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_msg.visible = false

	# Target selection arrow
	_target_indicator = _make_label(Vector2(0, 0), Vector2(30, 22), "▼", 18, UITheme.CURSOR)
	_target_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_indicator.visible = false


func _build_enemy_display() -> void:
	var count := enemies.size()
	if count == 0:
		return
	var spacing := 640.0 / float(count + 1)

	for i in range(count):
		var e: Combatant = enemies[i]
		var cx := spacing * float(i + 1)
		var ui := {}

		ui["name_lbl"] = _make_label(
			Vector2(cx - 55, 30), Vector2(110, 18),
			e.display_name, 12, UITheme.TEXT)
		ui["name_lbl"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Creature sprite (loaded from assets/sprites/battle/)
		var sprite_size := Vector2(72, 72)
		ui["sprite"] = _load_creature_sprite(
			e.creature_id, sprite_size, Vector2(cx - 36, 46))

		# Element indicator — small colored dot below sprite
		var dot_color := _element_color(e.element)
		var elem_dot := _make_rect(Vector2(cx - 4, 120), Vector2(8, 8), dot_color)
		elem_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# HP bar
		ui["hp_bg"] = _make_rect(Vector2(cx - 40, 132), Vector2(80, 6), UITheme.HP_BG)
		ui["hp_fill"] = _make_rect(Vector2(cx - 40, 132), Vector2(80, 6), UITheme.HP_RED)
		ui["hp_text"] = _make_label(
			Vector2(cx - 40, 140), Vector2(80, 16),
			"%d/%d" % [e.hp, e.max_hp], 10, UITheme.TEXT_DIM)
		ui["hp_text"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		ui["center_x"] = cx
		_enemy_ui.append(ui)


func _build_party_display() -> void:
	for i in range(party.size()):
		var c: Combatant = party[i]
		var y := PARTY_Y + i * PARTY_ROW_H
		var ui := {}

		# Element dot + name
		_make_rect(Vector2(PARTY_X, y + 3), Vector2(10, 10), _element_color(c.element))
		ui["name_lbl"] = _make_label(
			Vector2(PARTY_X + 14, y), Vector2(120, 18), c.display_name, 13, UITheme.TEXT)

		# HP row
		_make_label(Vector2(PARTY_X + 10, y + 19), Vector2(25, 14), "HP", 10, UITheme.INNOCENT_BONUS)
		ui["hp_bg"] = _make_rect(Vector2(PARTY_X + 38, y + 21), Vector2(HP_BAR_W, 8), UITheme.HP_BG)
		ui["hp_fill"] = _make_rect(Vector2(PARTY_X + 38, y + 21), Vector2(HP_BAR_W, 8), UITheme.HP_GREEN)
		ui["hp_text"] = _make_label(
			Vector2(PARTY_X + HP_BAR_W + 42, y + 17), Vector2(80, 14),
			"%d/%d" % [c.hp, c.max_hp], 10, UITheme.TEXT_DIM)

		# SP row
		_make_label(Vector2(PARTY_X + 10, y + 35), Vector2(25, 14), "SP", 10, Color(0.6, 0.6, 0.9))
		ui["sp_bg"] = _make_rect(Vector2(PARTY_X + 38, y + 37), Vector2(SP_BAR_W, 8), UITheme.SP_BG)
		ui["sp_fill"] = _make_rect(Vector2(PARTY_X + 38, y + 37), Vector2(SP_BAR_W, 8), UITheme.SP_BLUE)
		ui["sp_text"] = _make_label(
			Vector2(PARTY_X + SP_BAR_W + 42, y + 33), Vector2(80, 14),
			"%d/%d" % [c.sp, c.max_sp], 10, UITheme.TEXT_DIM)

		ui["y_pos"] = y
		_party_ui.append(ui)


func _build_menu() -> void:
	_menu_title = _make_label(
		Vector2(MENU_X, PARTY_Y), Vector2(250, 18), "", 12, UITheme.SECTION_HEADER)
	for i in range(8):
		var label := _make_label(
			Vector2(MENU_X, MENU_Y + i * MENU_LINE_H), Vector2(250, MENU_LINE_H),
			"", 14, Color.WHITE)
		label.visible = false
		_menu_labels.append(label)


# ==========================================================================
#  MAIN LOOP
# ==========================================================================

func _process(delta: float) -> void:
	match state:
		State.INTRO:
			intro_timer -= delta
			if intro_timer <= 0:
				_msg_label.visible = false
				_check_opening_decrees()
		State.PLAYER_CHOOSING:
			_handle_menu_input()
		State.SKILL_SELECT:
			_handle_skill_input()
		State.TARGET_SELECT:
			_handle_target_input()
		State.CORRUPT_CONFIRM:
			_handle_corrupt_input()
		State.EXECUTING:
			exec_timer -= delta
			if exec_timer <= 0:
				_sub_msg.visible = false
				if _was_enemy_action:
					_was_enemy_action = false
					_check_reactive_decrees()
				else:
					_advance_turn()
		State.DECREE_FIRING:
			_decree_timer -= delta
			if _decree_timer <= 0:
				_msg_label.visible = false
				_sub_msg.visible = false
				_fire_next_decree()
		State.ENEMY_TURN:
			enemy_timer -= delta
			if enemy_timer <= 0:
				_execute_enemy_action()
		State.VICTORY, State.DEFEAT:
			end_timer -= delta
			if end_timer <= 0:
				battle_ended.emit("victory" if state == State.VICTORY else "defeat")


# ==========================================================================
#  INTRO
# ==========================================================================

func _start_intro() -> void:
	state = State.INTRO
	_msg_label.text = "BATTLE!"
	_msg_label.add_theme_color_override("font_color", Color.WHITE)
	_msg_label.visible = true
	_flash.color = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.4)
	intro_timer = 1.2


# ==========================================================================
#  TURN MANAGEMENT
# ==========================================================================

func _begin_turns() -> void:
	_calculate_turn_order()
	turn_idx = -1
	_advance_turn()


func _calculate_turn_order() -> void:
	turn_order.clear()
	for c in party:
		if c.is_alive():
			turn_order.append(c)
	for c in enemies:
		if c.is_alive():
			turn_order.append(c)
	turn_order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.spd != b.spd:
			return a.spd > b.spd
		return a.is_player_controlled and not b.is_player_controlled
	)


func _advance_turn() -> void:
	if _fled:
		battle_ended.emit("fled")
		return
	if _all_dead(enemies):
		_show_victory()
		return
	if _all_dead(party):
		_show_defeat()
		return

	turn_idx += 1
	if turn_idx >= turn_order.size():
		turn_idx = 0
		_calculate_turn_order()

	actor = turn_order[turn_idx]
	var loops := 0
	while not actor.is_alive():
		turn_idx += 1
		if turn_idx >= turn_order.size():
			turn_idx = 0
			_calculate_turn_order()
		actor = turn_order[turn_idx]
		loops += 1
		if loops > turn_order.size() + 2:
			return

	# Reset guard at start of own turn
	actor.is_guarding = false

	if actor.is_player_controlled:
		_start_player_turn()
	else:
		_start_enemy_turn()


func _all_dead(group: Array) -> bool:
	for c in group:
		if c.is_alive():
			return false
	return true


# ==========================================================================
#  PLAYER TURN — ACTION MENU
# ==========================================================================

func _start_player_turn() -> void:
	state = State.PLAYER_CHOOSING
	_sub_msg.visible = false
	_highlight_active_party_member()

	var items: Array = ["Attack", "Skill", "Guard", "Talk", "Item"]
	if actor.sp > 0:
		items.append("Corrupt")
	items.append("Flee")

	_show_action_menu(items)
	_menu_title.text = actor.display_name + "'s Turn"


func _show_action_menu(items: Array) -> void:
	menu_items = items
	menu_cursor = 0
	for i in range(_menu_labels.size()):
		if i < items.size():
			_menu_labels[i].visible = true
		else:
			_menu_labels[i].visible = false
	_update_menu_cursor()


func _update_menu_cursor() -> void:
	for i in range(menu_items.size()):
		if i >= _menu_labels.size():
			break
		if i == menu_cursor:
			_menu_labels[i].text = "\u25b6 " + menu_items[i]
			_menu_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
		else:
			_menu_labels[i].text = "  " + menu_items[i]
			_menu_labels[i].add_theme_color_override("font_color", UITheme.TEXT)


func _handle_menu_input() -> void:
	if Input.is_action_just_pressed("ui_up"):
		menu_cursor = (menu_cursor - 1 + menu_items.size()) % menu_items.size()
		_update_menu_cursor()
	elif Input.is_action_just_pressed("ui_down"):
		menu_cursor = (menu_cursor + 1) % menu_items.size()
		_update_menu_cursor()
	elif Input.is_action_just_pressed("ui_accept"):
		_select_action(menu_items[menu_cursor])


func _select_action(action: String) -> void:
	pending_action = action
	match action:
		"Attack":
			_enter_target_select(false)
		"Skill":
			_enter_skill_select()
		"Guard":
			_execute_guard()
		"Talk":
			pending_action = "Talk"
			_enter_target_select(false)
		"Item":
			_show_sub_message("No items yet...")
		"Corrupt":
			_enter_corrupt()
		"Flee":
			_attempt_flee()


# ==========================================================================
#  SKILL SELECT
# ==========================================================================

func _enter_skill_select() -> void:
	state = State.SKILL_SELECT
	_sub_msg.visible = false
	skill_list = actor.skills.duplicate()
	var items: Array = []
	for s in skill_list:
		var suffix := ""
		if s.sp_cost > 0:
			suffix = " (%d SP)" % s.sp_cost
		var prefix := ""
		if s.sp_cost > actor.sp:
			prefix = "x "  # Mark as unavailable
		else:
			prefix = "  "
		items.append(prefix.strip_edges() + " " + s.name + suffix if prefix.strip_edges() != "" else s.name + suffix)
	# Simpler: just show name + cost, grey out in cursor update
	items.clear()
	for s in skill_list:
		var cost_str: String = " (%d SP)" % int(s.sp_cost) if s.sp_cost > 0 else ""
		items.append(s.name + cost_str)
	_show_action_menu(items)
	_menu_title.text = "Skills"
	_update_skill_cursor()


func _update_skill_cursor() -> void:
	for i in range(menu_items.size()):
		if i >= _menu_labels.size() or i >= skill_list.size():
			break
		var affordable: bool = skill_list[i].sp_cost <= actor.sp
		if i == menu_cursor:
			_menu_labels[i].text = "\u25b6 " + menu_items[i]
			_menu_labels[i].add_theme_color_override("font_color",
				UITheme.CURSOR if affordable else UITheme.TEXT_DIM)
		else:
			_menu_labels[i].text = "  " + menu_items[i]
			_menu_labels[i].add_theme_color_override("font_color",
				UITheme.TEXT if affordable else UITheme.TEXT_DISABLED)


func _handle_skill_input() -> void:
	if Input.is_action_just_pressed("ui_up"):
		menu_cursor = (menu_cursor - 1 + menu_items.size()) % menu_items.size()
		_update_skill_cursor()
	elif Input.is_action_just_pressed("ui_down"):
		menu_cursor = (menu_cursor + 1) % menu_items.size()
		_update_skill_cursor()
	elif Input.is_action_just_pressed("ui_accept"):
		if menu_cursor < skill_list.size():
			var skill: Dictionary = skill_list[menu_cursor]
			if skill.sp_cost > actor.sp:
				_show_sub_message("Not enough SP!")
				return
			pending_skill = skill
			pending_action = "Skill"
			if skill.is_heal:
				_enter_target_select(true)
			else:
				_enter_target_select(false)
	elif Input.is_action_just_pressed("ui_cancel"):
		_start_player_turn()


# ==========================================================================
#  TARGET SELECT
# ==========================================================================

func _enter_target_select(allies: bool) -> void:
	state = State.TARGET_SELECT
	_sub_msg.visible = false
	targeting_allies = allies
	target_list.clear()

	if allies:
		for c in party:
			if c.is_alive():
				target_list.append(c)
	else:
		for c in enemies:
			if c.is_alive():
				target_list.append(c)

	if target_list.is_empty():
		_start_player_turn()
		return

	target_cursor = 0
	_hide_menu()
	_menu_title.text = "Select Target"
	_update_target_indicator()


func _handle_target_input() -> void:
	var changed := false
	if targeting_allies:
		if Input.is_action_just_pressed("ui_up"):
			target_cursor = (target_cursor - 1 + target_list.size()) % target_list.size()
			changed = true
		elif Input.is_action_just_pressed("ui_down"):
			target_cursor = (target_cursor + 1) % target_list.size()
			changed = true
	else:
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up"):
			target_cursor = (target_cursor - 1 + target_list.size()) % target_list.size()
			changed = true
		elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down"):
			target_cursor = (target_cursor + 1) % target_list.size()
			changed = true

	if changed:
		_update_target_indicator()

	if Input.is_action_just_pressed("ui_accept"):
		_target_indicator.visible = false
		_reset_party_name_colors()
		if pending_action == "Talk":
			_start_negotiation(target_list[target_cursor])
		else:
			_execute_player_action(target_list[target_cursor])
	elif Input.is_action_just_pressed("ui_cancel"):
		_target_indicator.visible = false
		_reset_party_name_colors()
		if pending_action == "Skill":
			_enter_skill_select()
		else:
			_start_player_turn()


func _update_target_indicator() -> void:
	if targeting_allies:
		_target_indicator.visible = false
		for i in range(party.size()):
			var is_selected: bool = target_list.size() > target_cursor and target_list[target_cursor] == party[i]
			if i < _party_ui.size():
				_party_ui[i]["name_lbl"].add_theme_color_override("font_color",
					UITheme.CURSOR if is_selected else UITheme.TEXT)
		if target_cursor < target_list.size():
			_menu_title.text = target_list[target_cursor].display_name
	else:
		_target_indicator.visible = true
		if target_cursor < target_list.size():
			var target: Combatant = target_list[target_cursor]
			var enemy_idx := enemies.find(target)
			if enemy_idx >= 0 and enemy_idx < _enemy_ui.size():
				var cx: float = _enemy_ui[enemy_idx]["center_x"]
				_target_indicator.position = Vector2(cx - 15, 18)
			_menu_title.text = target.display_name + " (" + CombatData.ELEMENT_NAMES.get(target.element, "?") + ")"


func _reset_party_name_colors() -> void:
	for i in range(party.size()):
		if i < _party_ui.size():
			_party_ui[i]["name_lbl"].add_theme_color_override("font_color", UITheme.TEXT)


# ==========================================================================
#  CORRUPTION
# ==========================================================================

func _enter_corrupt() -> void:
	if not actor.is_corrupted:
		state = State.CORRUPT_CONFIRM
		corrupt_cursor = 1  # Default to No
		_hide_menu()
		_show_message("...You don't have to do this.", Color(0.7, 0.7, 0.9))
		_sub_msg.text = "This is permanent.   Yes   [No]"
		_sub_msg.visible = true
	else:
		_apply_corrupt_boost()


func _handle_corrupt_input() -> void:
	if Input.is_action_just_pressed("ui_left"):
		corrupt_cursor = 0
		_update_corrupt_cursor()
	elif Input.is_action_just_pressed("ui_right"):
		corrupt_cursor = 1
		_update_corrupt_cursor()
	elif Input.is_action_just_pressed("ui_accept"):
		_msg_label.visible = false
		_sub_msg.visible = false
		if corrupt_cursor == 0:
			_apply_corruption()
		else:
			_start_player_turn()
	elif Input.is_action_just_pressed("ui_cancel"):
		_msg_label.visible = false
		_sub_msg.visible = false
		_start_player_turn()


func _update_corrupt_cursor() -> void:
	if corrupt_cursor == 0:
		_sub_msg.text = "This is permanent.  [Yes]   No "
	else:
		_sub_msg.text = "This is permanent.   Yes   [No]"


func _apply_corruption() -> void:
	actor.is_corrupted = true
	party_innocent = false

	# Red flash
	_flash.color = Color(0.6, 0.0, 0.1, 0.7)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.6)

	# Lock Innocent skills on this character
	actor.skills = actor.skills.filter(func(s: Dictionary) -> bool:
		return s.element != CombatData.Element.INNOCENT)

	_apply_corrupt_boost()


func _apply_corrupt_boost() -> void:
	if not actor.spend_sp(1):
		_show_sub_message("Not enough SP!")
		_start_player_turn()
		return

	actor.corrupt_boost_active = true
	state = State.EXECUTING
	_show_sub_message(actor.display_name + " channels dark power...")
	_update_all_bars()
	exec_timer = 1.0


# ==========================================================================
#  ACTION EXECUTION
# ==========================================================================

func _execute_player_action(target: Combatant) -> void:
	state = State.EXECUTING
	_was_enemy_action = false

	match pending_action:
		"Attack":
			var atk_skill := CombatData.make_skill("Attack", actor.element, 1.0, 0)
			if actor.corrupt_boost_active:
				atk_skill.power *= 1.5
				actor.corrupt_boost_active = false
			var damage := CombatData.calc_damage(actor, atk_skill, target)
			var actual := target.take_damage(damage)
			var is_weak := CombatData.is_weakness(actor.element, target.element)
			var is_res := CombatData.is_resist(actor.element, target.element)
			if is_weak:
				actor.restore_sp(1)
				_show_sub_message("WEAKNESS! +1 SP")
			elif is_res:
				_show_sub_message("Resisted...")
			else:
				_show_sub_message(actor.display_name + " attacks!")
			_show_damage_on_enemy(target, actual, is_weak)
			_update_all_bars()
			exec_timer = 1.2

		"Skill":
			var skill := pending_skill
			actor.spend_sp(skill.sp_cost)
			if skill.is_heal:
				var amount := CombatData.calc_heal(actor, skill, party_innocent)
				var healed := target.heal_hp(amount)
				_show_heal_number(target, healed)
				_show_sub_message(actor.display_name + " heals " + target.display_name + "!")
			else:
				if actor.corrupt_boost_active:
					skill = skill.duplicate()
					skill.power *= 1.5
					actor.corrupt_boost_active = false
				var damage := CombatData.calc_damage(actor, skill, target)
				var actual := target.take_damage(damage)
				var is_weak := CombatData.is_weakness(skill.element, target.element)
				var is_res := CombatData.is_resist(skill.element, target.element)
				if is_weak:
					actor.restore_sp(1)
					_show_sub_message(skill.name + "! WEAKNESS! +1 SP")
				elif is_res:
					_show_sub_message(skill.name + " — Resisted...")
				else:
					_show_sub_message(actor.display_name + " uses " + skill.name + "!")
				_show_damage_on_enemy(target, actual, is_weak)
			_update_all_bars()
			exec_timer = 1.2


func _execute_guard() -> void:
	state = State.EXECUTING
	_was_enemy_action = false
	actor.is_guarding = true
	var bonus := ""
	if party_innocent:
		bonus = " (Innocence +25%!)"
	_show_sub_message(actor.display_name + " guards!" + bonus)
	_hide_menu()
	exec_timer = 0.8


func _attempt_flee() -> void:
	var party_spd := 0.0
	var p_count := 0
	for c in party:
		if c.is_alive():
			party_spd += c.spd
			p_count += 1
	var enemy_spd := 0.0
	var e_count := 0
	for c in enemies:
		if c.is_alive():
			enemy_spd += c.spd
			e_count += 1

	var flee_chance := 0.5
	if p_count > 0 and e_count > 0:
		flee_chance = clampf((party_spd / p_count) / (enemy_spd / e_count) * 0.5, 0.2, 0.8)

	state = State.EXECUTING
	_was_enemy_action = false
	_hide_menu()
	if randf() < flee_chance:
		_show_sub_message("Escaped!")
		_fled = true
	else:
		_show_sub_message("Can't escape!")
	exec_timer = 0.8


# ==========================================================================
#  ENEMY AI
# ==========================================================================

func _start_enemy_turn() -> void:
	state = State.ENEMY_TURN
	_hide_menu()
	_menu_title.text = actor.display_name + "'s turn..."
	_highlight_active_party_member()
	enemy_timer = 0.6


func _execute_enemy_action() -> void:
	state = State.EXECUTING
	_was_enemy_action = true
	_enemy_targeted_healer = false

	var alive_party: Array = party.filter(func(c: Combatant) -> bool: return c.is_alive())
	if alive_party.is_empty():
		exec_timer = 0.1
		return

	var alive_enemies: Array = enemies.filter(func(c: Combatant) -> bool: return c.is_alive())

	# Boss AI: aggressive skill usage, self-heal when low, targets healers
	if actor.ai_type == "boss":
		# Self-heal if below 30% HP
		if actor.hp < actor.max_hp * 0.3:
			var heal_skills: Array = actor.skills.filter(
				func(s: Dictionary) -> bool: return s.is_heal and s.sp_cost <= actor.sp)
			if not heal_skills.is_empty() and randf() < 0.6:
				var skill: Dictionary = heal_skills[0]
				actor.spend_sp(skill.sp_cost)
				var amount := CombatData.calc_heal(actor, skill, false)
				actor.heal_hp(amount)
				_show_heal_number(actor, amount)
				_show_sub_message(actor.display_name + " channels corrupt healing!")
				_update_all_bars()
				exec_timer = 1.2
				return
		# Prefer offensive skills (70% chance)
		var boss_off: Array = actor.skills.filter(
			func(s: Dictionary) -> bool: return not s.is_heal and s.sp_cost > 0 and s.sp_cost <= actor.sp)
		if not boss_off.is_empty() and randf() < 0.7:
			var skill: Dictionary = boss_off[randi() % boss_off.size()]
			actor.spend_sp(skill.sp_cost)
			# Target healer 50% of the time if one exists
			var healers: Array = alive_party.filter(func(c: Combatant) -> bool: return _is_healer(c))
			var target: Combatant
			if not healers.is_empty() and randf() < 0.5:
				target = healers[randi() % healers.size()]
			else:
				target = alive_party[randi() % alive_party.size()]
			_enemy_targeted_healer = _is_healer(target)
			var damage := CombatData.calc_damage(actor, skill, target)
			if target.is_guarding and target.is_player_controlled and party_innocent:
				damage = maxi(1, int(float(damage) * 0.75))
			var actual := target.take_damage(damage)
			var is_weak := CombatData.is_weakness(skill.element, target.element)
			if is_weak:
				actor.restore_sp(1)
			_show_damage_on_party(target, actual, is_weak)
			_show_sub_message(actor.display_name + " uses " + skill.name + "!")
			_update_all_bars()
			exec_timer = 1.2
			return

	# Support AI: try healing first
	if actor.ai_type == "support":
		var hurt: Array = alive_enemies.filter(
			func(c: Combatant) -> bool: return c.hp < c.max_hp * 0.5)
		var heal_skills: Array = actor.skills.filter(
			func(s: Dictionary) -> bool: return s.is_heal and s.sp_cost <= actor.sp)
		if not hurt.is_empty() and not heal_skills.is_empty() and randf() < 0.45:
			var skill: Dictionary = heal_skills[0]
			actor.spend_sp(skill.sp_cost)
			var target: Combatant = hurt[0]
			var amount := CombatData.calc_heal(actor, skill, false)
			target.heal_hp(amount)
			_show_heal_number(target, amount)
			_show_sub_message(actor.display_name + " heals " + target.display_name + "!")
			_update_all_bars()
			exec_timer = 1.2
			return

	# Offensive skill or basic attack
	var off_skills: Array = actor.skills.filter(
		func(s: Dictionary) -> bool: return not s.is_heal and s.sp_cost > 0 and s.sp_cost <= actor.sp)

	if not off_skills.is_empty() and randf() < 0.5:
		var skill: Dictionary = off_skills[randi() % off_skills.size()]
		actor.spend_sp(skill.sp_cost)
		var target: Combatant = alive_party[randi() % alive_party.size()]
		_enemy_targeted_healer = _is_healer(target)
		var damage := CombatData.calc_damage(actor, skill, target)
		# Innocence guard bonus
		if target.is_guarding and target.is_player_controlled and party_innocent:
			damage = maxi(1, int(float(damage) * 0.75))
		var actual := target.take_damage(damage)
		var is_weak := CombatData.is_weakness(skill.element, target.element)
		if is_weak:
			actor.restore_sp(1)
		_show_damage_on_party(target, actual, is_weak)
		_show_sub_message(actor.display_name + " uses " + skill.name + "!")
		_update_all_bars()
	else:
		# Basic attack (0-cost skill or fallback)
		var basic: Array = actor.skills.filter(
			func(s: Dictionary) -> bool: return s.sp_cost == 0 and not s.is_heal)
		var atk_skill: Dictionary
		if basic.is_empty():
			atk_skill = CombatData.make_skill("Attack", actor.element, 1.0, 0)
		else:
			atk_skill = basic[0]
		var target: Combatant = alive_party[randi() % alive_party.size()]
		_enemy_targeted_healer = _is_healer(target)
		var damage := CombatData.calc_damage(actor, atk_skill, target)
		if target.is_guarding and target.is_player_controlled and party_innocent:
			damage = maxi(1, int(float(damage) * 0.75))
		var actual := target.take_damage(damage)
		var is_weak := CombatData.is_weakness(atk_skill.element, target.element)
		if is_weak:
			actor.restore_sp(1)
		_show_damage_on_party(target, actual, is_weak)
		_show_sub_message(actor.display_name + " attacks " + target.display_name + "!")
		_update_all_bars()

	exec_timer = 1.2


# ==========================================================================
#  UI UPDATES
# ==========================================================================

func _update_all_bars() -> void:
	_update_enemy_bars()
	_update_party_bars()


func _update_enemy_bars() -> void:
	for i in range(enemies.size()):
		if i >= _enemy_ui.size():
			break
		var e: Combatant = enemies[i]
		var ui: Dictionary = _enemy_ui[i]
		var ratio := clampf(float(e.hp) / maxf(1.0, float(e.max_hp)), 0.0, 1.0)
		ui["hp_fill"].size.x = 80.0 * ratio
		ui["hp_text"].text = "%d/%d" % [e.hp, e.max_hp]
		if not e.is_alive():
			ui["sprite"].modulate = Color(0.3, 0.3, 0.3, 0.4)
			ui["name_lbl"].modulate = Color(0.5, 0.5, 0.5, 0.5)


func _update_party_bars() -> void:
	for i in range(party.size()):
		if i >= _party_ui.size():
			break
		var c: Combatant = party[i]
		var ui: Dictionary = _party_ui[i]

		var hp_ratio := clampf(float(c.hp) / maxf(1.0, float(c.max_hp)), 0.0, 1.0)
		ui["hp_fill"].size.x = HP_BAR_W * hp_ratio
		ui["hp_text"].text = "%d/%d" % [c.hp, c.max_hp]

		var sp_ratio := clampf(float(c.sp) / maxf(1.0, float(c.max_sp)), 0.0, 1.0)
		ui["sp_fill"].size.x = SP_BAR_W * sp_ratio
		ui["sp_text"].text = "%d/%d" % [c.sp, c.max_sp]

		# HP bar color: green -> yellow -> red
		if hp_ratio > 0.5:
			ui["hp_fill"].color = UITheme.HP_GREEN
		elif hp_ratio > 0.25:
			ui["hp_fill"].color = Color(0.85, 0.75, 0.2)
		else:
			ui["hp_fill"].color = UITheme.HP_RED


func _highlight_active_party_member() -> void:
	for i in range(party.size()):
		if i >= _party_ui.size():
			break
		if party[i] == actor:
			_party_ui[i]["name_lbl"].add_theme_color_override("font_color", UITheme.CURSOR)
		else:
			_party_ui[i]["name_lbl"].add_theme_color_override("font_color", UITheme.TEXT)


func _hide_menu() -> void:
	for l in _menu_labels:
		l.visible = false


# ==========================================================================
#  VISUAL EFFECTS
# ==========================================================================

func _show_message(text: String, color: Color = Color.WHITE) -> void:
	_msg_label.text = text
	_msg_label.add_theme_color_override("font_color", color)
	_msg_label.visible = true


func _show_sub_message(text: String) -> void:
	_sub_msg.text = text
	_sub_msg.visible = true


func _show_damage_on_enemy(target: Combatant, amount: int, is_weakness: bool) -> void:
	var idx := enemies.find(target)
	if idx < 0 or idx >= _enemy_ui.size():
		return
	var cx: float = _enemy_ui[idx]["center_x"]
	var color := Color.GOLD if is_weakness else Color(1.0, 0.4, 0.3)
	_spawn_floating_number(Vector2(cx - 15, 45), str(amount), color)


func _show_damage_on_party(target: Combatant, amount: int, is_weakness: bool) -> void:
	var idx := party.find(target)
	if idx < 0 or idx >= _party_ui.size():
		return
	var y: float = _party_ui[idx]["y_pos"]
	var color := Color.GOLD if is_weakness else Color(1.0, 0.4, 0.3)
	_spawn_floating_number(Vector2(PARTY_X + 200, y), str(amount), color)


func _show_heal_number(target: Combatant, amount: int) -> void:
	var party_idx := party.find(target)
	if party_idx >= 0 and party_idx < _party_ui.size():
		var y: float = _party_ui[party_idx]["y_pos"]
		_spawn_floating_number(Vector2(PARTY_X + 200, y), "+" + str(amount), Color(0.3, 1.0, 0.4))
		return
	var enemy_idx := enemies.find(target)
	if enemy_idx >= 0 and enemy_idx < _enemy_ui.size():
		var cx: float = _enemy_ui[enemy_idx]["center_x"]
		_spawn_floating_number(Vector2(cx - 15, 45), "+" + str(amount), Color(0.3, 1.0, 0.4))


func _spawn_floating_number(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", pos.y - 35.0, 0.7)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tw.tween_callback(label.queue_free)


# ==========================================================================
#  NEGOTIATION
# ==========================================================================

var _negotiation_scene: CanvasLayer = null

func _start_negotiation(target: Combatant) -> void:
	state = State.NEGOTIATING
	_hide_menu()
	_menu_title.text = "Negotiating..."
	_sub_msg.visible = false

	_negotiation_scene = NegotiationScript.new()
	_negotiation_scene.target = target
	_negotiation_scene.party_corrupted = not party_innocent
	_negotiation_scene.negotiation_ended.connect(_on_negotiation_ended)
	get_tree().root.add_child(_negotiation_scene)


func _on_negotiation_ended(result: String, creature: Combatant) -> void:
	_negotiation_scene = null
	match result:
		"success":
			# Remove from enemies, recruit
			var recruit := creature.duplicate_combatant()
			recruit.is_player_controlled = true
			recruit.hp = recruit.max_hp
			recruit.sp = recruit.max_sp
			var idx := enemies.find(creature)
			if idx >= 0:
				# Mark as dead so it's removed from combat
				creature.hp = 0
				if idx < _enemy_ui.size():
					_enemy_ui[idx]["sprite"].modulate = Color(0.3, 0.8, 0.3, 0.4)
					_enemy_ui[idx]["name_lbl"].text = "Recruited!"
			GameManager.recruit_creature(recruit)
			_show_sub_message(recruit.display_name + " joined the party!")
			_update_all_bars()
			state = State.EXECUTING
			_was_enemy_action = false
			exec_timer = 1.5
		"full":
			_show_sub_message("No room in party or reserve!")
			state = State.EXECUTING
			_was_enemy_action = false
			exec_timer = 1.2
		"fail":
			# Failed negotiation — enemy gets a free attack
			_show_sub_message(creature.display_name + " is angered!")
			state = State.EXECUTING
			_was_enemy_action = false
			exec_timer = 1.0


# ==========================================================================
#  BATTLE END
# ==========================================================================

func _show_victory() -> void:
	state = State.VICTORY
	_hide_menu()
	_target_indicator.visible = false
	_sub_msg.visible = false
	_show_message("VICTORY!", UITheme.TITLE)
	end_timer = 2.0


func _show_defeat() -> void:
	state = State.DEFEAT
	_hide_menu()
	_target_indicator.visible = false
	_sub_msg.visible = false
	_show_message("DEFEAT...", UITheme.CORRUPT)
	end_timer = 2.5


# ==========================================================================
#  DECREE SYSTEM
# ==========================================================================

func _is_healer(member: Combatant) -> bool:
	for s in member.skills:
		if s.is_heal:
			return true
	return false


func _check_opening_decrees() -> void:
	## Called after battle intro — checks FIRST_TURN and ENCOUNTER_CORRUPT.
	_decree_queue.clear()
	var triggers: Array = [
		DecreeSystem.Condition.FIRST_TURN,
		DecreeSystem.Condition.ENCOUNTER_CORRUPT,
	]
	for trigger in triggers:
		var slots: Array = DecreeSystem.get_triggered(int(trigger), party, enemies)
		for slot_idx in slots:
			if not _decree_queue.has(slot_idx):
				_decree_queue.append(slot_idx)
	if _decree_queue.is_empty():
		_begin_turns()
	else:
		_decree_resume = "_begin_turns"
		_fire_next_decree()


func _check_reactive_decrees() -> void:
	## Called after enemy action — checks ALLY_HP_CRITICAL, SP_BELOW_3, ENEMY_TARGETS_HEALER.
	_decree_queue.clear()
	var context: Dictionary = { "target_is_healer": _enemy_targeted_healer }
	var triggers: Array = [
		DecreeSystem.Condition.ALLY_HP_CRITICAL,
		DecreeSystem.Condition.SP_BELOW_3,
		DecreeSystem.Condition.ENEMY_TARGETS_HEALER,
	]
	for trigger in triggers:
		var slots: Array = DecreeSystem.get_triggered(int(trigger), party, enemies, context)
		for slot_idx in slots:
			if not _decree_queue.has(slot_idx):
				_decree_queue.append(slot_idx)
	if _decree_queue.is_empty():
		_advance_turn()
	else:
		_decree_resume = "_advance_turn"
		_fire_next_decree()


func _fire_next_decree() -> void:
	if _decree_queue.is_empty():
		# All decrees fired — resume normal flow
		call(_decree_resume)
		return

	state = State.DECREE_FIRING
	var slot: int = _decree_queue.pop_front()
	var decree: Dictionary = DecreeSystem.decrees[slot]
	var result: Dictionary = DecreeSystem.find_member_and_skill(decree, party)

	if result.is_empty():
		# Can't execute (member dead, out of SP, or skill locked) — skip
		DecreeSystem.mark_spent(slot)
		_fire_next_decree()
		return

	var member: Combatant = result.member
	var skill: Dictionary = result.skill
	var sp_cost: int = int(skill.sp_cost)

	member.spend_sp(sp_cost)

	if skill.is_heal:
		# Heal the most hurt ally
		var best_target: Combatant = _find_most_hurt_ally()
		var amount: int = CombatData.calc_heal(member, skill, party_innocent)
		var healed: int = best_target.heal_hp(amount)
		_show_heal_number(best_target, healed)
		_show_sub_message("Decree: " + member.display_name + " uses " + String(skill.name) + "!")
	else:
		# Damage a random living enemy
		var alive_enemies: Array = enemies.filter(
			func(c: Combatant) -> bool: return c.is_alive())
		if alive_enemies.is_empty():
			DecreeSystem.mark_spent(slot)
			_fire_next_decree()
			return
		var target: Combatant = alive_enemies[randi() % alive_enemies.size()]
		var damage: int = CombatData.calc_damage(member, skill, target)
		var actual: int = target.take_damage(damage)
		var is_weak: bool = CombatData.is_weakness(int(skill.element), target.element)
		if is_weak:
			member.restore_sp(1)
		_show_damage_on_enemy(target, actual, is_weak)
		_show_sub_message("Decree: " + member.display_name + " uses " + String(skill.name) + "!")

	_show_message("DECREE FULFILLED!", Color(0.9, 0.8, 0.3))
	DecreeSystem.mark_spent(slot)
	_update_all_bars()
	_decree_timer = 1.8


func _find_most_hurt_ally() -> Combatant:
	var best: Combatant = null
	var best_ratio: float = 1.0
	for c in party:
		if c.is_alive():
			var ratio: float = float(c.hp) / maxf(1.0, float(c.max_hp))
			if ratio < best_ratio or best == null:
				best_ratio = ratio
				best = c
	if best == null:
		best = party[0]
	return best
