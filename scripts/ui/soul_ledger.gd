extends CanvasLayer

## Soul Ledger — pause menu showing party corruption status, Decree slots,
## reserve party, and the Innocence Bonus state. Toggled with Escape during exploration.
## Phase 2: Added party/reserve swap, compendium + Soul Investment access.

signal closed

enum LedgerState { VIEW, SWAP_SELECT_ACTIVE, SWAP_SELECT_RESERVE }

var party: Array = []
var _state: int = LedgerState.VIEW
var _swap_active_idx: int = -1
var _swap_cursor: int = 0
var _swap_labels: Array = []
var _action_labels: Array = []
var _action_cursor: int = 0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()


func _build_ui() -> void:
	# Clear existing children for rebuild
	for child in get_children():
		child.queue_free()
	_swap_labels.clear()
	_action_labels.clear()

	UITheme.build_overlay(self)
	UITheme.build_panel(self, Vector2(20, 20), Vector2(600, 440))

	# Title
	var title := Label.new()
	title.position = Vector2(20, 28)
	title.size = Vector2(600, 30)
	title.text = "SOUL LEDGER"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	UITheme.build_separator(self, Vector2(35, 60), 570)

	# --- Active Party ---
	_add_label(Vector2(40, 66), "Active Party", 13, UITheme.SECTION_HEADER)
	var corrupted_count: int = 0
	var y_off: int = 86

	for c in party:
		_draw_combatant_row(c, y_off)
		if c.is_corrupted:
			corrupted_count += 1
		y_off += 42

	# --- Reserve ---
	var reserve: Array = GameManager.reserve
	if not reserve.is_empty():
		UITheme.build_separator(self, Vector2(35, y_off), 570)
		y_off += 6
		_add_label(Vector2(40, y_off), "Reserve", 13, UITheme.SECTION_HEADER)
		y_off += 22
		for c in reserve:
			_draw_combatant_row(c, y_off)
			y_off += 42

	# Separator before status
	UITheme.build_separator(self, Vector2(35, y_off), 570)

	# Innocence bonus
	if corrupted_count == 0:
		_add_label(Vector2(40, y_off + 6),
			"Innocence Bonus ACTIVE:  +25% healing,  +25% Guard DEF",
			11, UITheme.INNOCENT_BONUS)
	else:
		_add_label(Vector2(40, y_off + 6),
			"Corrupted: %d / %d" % [corrupted_count, party.size()],
			11, UITheme.CORRUPT)

	# Decree status
	var decree_y: int = y_off + 26
	_add_label(Vector2(40, decree_y), "Active Decrees", 12, UITheme.SECTION_HEADER)
	for i in range(DecreeSystem.MAX_SLOTS):
		var d: Dictionary = DecreeSystem.decrees[i]
		var cond: int = int(d.condition)
		var d_text: String
		var d_color: Color
		if cond == DecreeSystem.Condition.NONE:
			d_text = "Slot %d:  -- Empty --" % (i + 1)
			d_color = UITheme.TEXT_DISABLED
		elif bool(d.spent):
			d_text = "Slot %d:  (spent)" % (i + 1)
			d_color = UITheme.TEXT_DISABLED
		else:
			var cond_name: String = DecreeSystem.get_condition_name(cond)
			d_text = "Slot %d:  %s -> %s uses %s" % [i + 1, cond_name, d.member_name, d.skill_name]
			d_color = UITheme.CURSOR
		_add_label(Vector2(55, decree_y + 18 + i * 18), d_text, 10, d_color)

	# Bottom action bar
	var action_y := 430
	var actions := ["[1] Swap", "[2] Invest", "[3] Compendium", "[Esc] Close"]
	var action_x := 40
	for a_text in actions:
		var lbl := _add_label(Vector2(action_x, action_y), a_text, 11, UITheme.HINT)
		_action_labels.append(lbl)
		action_x += 150


func _draw_combatant_row(c: Combatant, y: int) -> void:
	# Element dot
	var elem_color: Color = CombatData.ELEMENT_COLORS.get(c.element, Color.GRAY)
	var dot := ColorRect.new()
	dot.position = Vector2(45, y + 4)
	dot.size = Vector2(10, 10)
	dot.color = elem_color
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)

	# Name
	_add_label(Vector2(60, y), c.display_name, 13, UITheme.TEXT)

	# Race + Element
	var race_name: String = CombatData.RACE_NAMES.get(c.race, "")
	var elem_name: String = CombatData.ELEMENT_NAMES.get(c.element, "?")
	if race_name != "":
		_add_label(Vector2(60, y + 16), race_name + " / " + elem_name, 10, UITheme.TEXT_DIM)
	else:
		_add_label(Vector2(60, y + 16), elem_name, 10, UITheme.TEXT_DIM)

	# HP / SP
	_add_label(Vector2(250, y), "HP %d/%d" % [c.hp, c.max_hp], 11, UITheme.TEXT)
	_add_label(Vector2(370, y), "SP %d/%d" % [c.sp, c.max_sp], 11, UITheme.TEXT)

	# Stats
	_add_label(Vector2(250, y + 16),
		"ATK %d  DEF %d  MAG %d  RES %d  SPD %d" % [c.atk, c.defense, c.mag, c.res, c.spd],
		9, UITheme.TEXT_DIM)

	# Corruption status
	if c.is_corrupted:
		_add_label(Vector2(480, y), "CORRUPTED", 11, UITheme.CORRUPT)
	else:
		_add_label(Vector2(480, y), "INNOCENT", 11, UITheme.INNOCENT)


func _add_label(pos: Vector2, text: String, font_size: int, color: Color,
		width: int = 500) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = Vector2(width, 22)
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl


func _process(_delta: float) -> void:
	match _state:
		LedgerState.VIEW:
			if Input.is_action_just_pressed("ui_cancel"):
				_close()
			elif Input.is_action_just_pressed("swap_key"):
				if not GameManager.reserve.is_empty():
					_start_swap()
			elif Input.is_action_just_pressed("invest_key"):
				_close()
				GameManager.open_soul_invest()
			elif Input.is_action_just_pressed("compendium_key"):
				_close()
				GameManager.open_compendium()

		LedgerState.SWAP_SELECT_ACTIVE:
			_handle_swap_active_input()

		LedgerState.SWAP_SELECT_RESERVE:
			_handle_swap_reserve_input()


func _start_swap() -> void:
	_state = LedgerState.SWAP_SELECT_ACTIVE
	_swap_cursor = 0
	_build_swap_ui("Select ACTIVE member to swap:", party)


func _handle_swap_active_input() -> void:
	if Input.is_action_just_pressed("ui_up"):
		_swap_cursor = (_swap_cursor - 1 + party.size()) % party.size()
		_update_swap_cursor(party.size())
	elif Input.is_action_just_pressed("ui_down"):
		_swap_cursor = (_swap_cursor + 1) % party.size()
		_update_swap_cursor(party.size())
	elif Input.is_action_just_pressed("ui_accept"):
		_swap_active_idx = _swap_cursor
		_state = LedgerState.SWAP_SELECT_RESERVE
		_swap_cursor = 0
		_build_swap_ui("Select RESERVE member to swap in:", GameManager.reserve)
	elif Input.is_action_just_pressed("ui_cancel"):
		_state = LedgerState.VIEW
		_build_ui()


func _handle_swap_reserve_input() -> void:
	var reserve: Array = GameManager.reserve
	if Input.is_action_just_pressed("ui_up"):
		_swap_cursor = (_swap_cursor - 1 + reserve.size()) % reserve.size()
		_update_swap_cursor(reserve.size())
	elif Input.is_action_just_pressed("ui_down"):
		_swap_cursor = (_swap_cursor + 1) % reserve.size()
		_update_swap_cursor(reserve.size())
	elif Input.is_action_just_pressed("ui_accept"):
		GameManager.swap_party_member(_swap_active_idx, _swap_cursor)
		party = GameManager.party
		_state = LedgerState.VIEW
		_build_ui()
	elif Input.is_action_just_pressed("ui_cancel"):
		_state = LedgerState.SWAP_SELECT_ACTIVE
		_swap_cursor = _swap_active_idx
		_build_swap_ui("Select ACTIVE member to swap:", party)


func _build_swap_ui(title_text: String, list: Array) -> void:
	for child in get_children():
		child.queue_free()
	_swap_labels.clear()

	UITheme.build_overlay(self)
	UITheme.build_panel(self, Vector2(80, 60), Vector2(480, 360))

	_add_label(Vector2(80, 70), title_text, 16, UITheme.TITLE, 480)

	var y := 110
	for i in range(list.size()):
		var c: Combatant = list[i]
		var elem_name: String = CombatData.ELEMENT_NAMES.get(c.element, "?")
		var text := "%s  (%s)  HP %d/%d  ATK %d  DEF %d  SPD %d" % [
			c.display_name, elem_name, c.hp, c.max_hp, c.atk, c.defense, c.spd]
		var lbl := _add_label(Vector2(100, y + i * 30), text, 13, UITheme.TEXT, 440)
		_swap_labels.append(lbl)

	_add_label(Vector2(80, 390), "Up/Down to select, Enter to confirm, Esc to cancel",
		11, UITheme.HINT, 480)

	_update_swap_cursor(list.size())


func _update_swap_cursor(count: int) -> void:
	for i in range(_swap_labels.size()):
		if i == _swap_cursor:
			_swap_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
			_swap_labels[i].text = "> " + _swap_labels[i].text.lstrip("> ")
		else:
			_swap_labels[i].add_theme_color_override("font_color", UITheme.TEXT)
			_swap_labels[i].text = "  " + _swap_labels[i].text.lstrip("> ")


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
