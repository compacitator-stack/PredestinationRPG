extends CanvasLayer

## Book of Decrees — UI overlay opened at save altars.
## Allows the player to set/clear Decrees in their 2 slots.
## Pauses the game tree while open.

const FusionMenuScript = preload("res://scripts/ui/fusion_menu.gd")

signal closed

enum MenuState {
	MAIN,
	SELECT_CONDITION,
	SELECT_MEMBER,
	SELECT_SKILL,
}

var _state: int = MenuState.MAIN
var _cursor: int = 0
var _editing_slot: int = -1
var _selected_condition: int = 0
var _selected_member_idx: int = -1
var party: Array = []

# UI nodes
var _title: Label
var _labels: Array = []
var _slot_labels: Array = []
var _info_label: Label
var _menu_items: Array = []

const MENU_X := 100
const MENU_Y := 210
const LINE_H := 24
const MAX_LABELS := 10


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()
	_show_main()


func _build_ui() -> void:
	UITheme.build_panel(self, Vector2(60, 40), Vector2(520, 400))

	# Title
	_title = Label.new()
	_title.position = Vector2(60, 52)
	_title.size = Vector2(520, 30)
	_title.text = "Book of Decrees"
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UITheme.TITLE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	UITheme.build_separator(self, Vector2(90, 88), 460)

	# Slot display labels
	for i in 2:
		var lbl := Label.new()
		lbl.position = Vector2(MENU_X, 100 + i * 45)
		lbl.size = Vector2(440, 36)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", UITheme.TEXT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		_slot_labels.append(lbl)

	# Menu option labels
	for i in MAX_LABELS:
		var lbl := Label.new()
		lbl.position = Vector2(MENU_X, MENU_Y + i * LINE_H)
		lbl.size = Vector2(440, LINE_H)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", UITheme.TEXT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.visible = false
		add_child(lbl)
		_labels.append(lbl)

	# Info text
	_info_label = Label.new()
	_info_label.position = Vector2(60, 420)
	_info_label.size = Vector2(520, 20)
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", UITheme.HINT)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_label)


func _show_main() -> void:
	_state = MenuState.MAIN
	_title.text = "Book of Decrees"
	_update_slot_display()

	_menu_items = ["Set Decree 1", "Set Decree 2", "Clear Decree 1", "Clear Decree 2", "Predestination Rites", "Close"]
	_cursor = 0
	_show_menu_items()
	_info_label.text = "Decrees fire automatically in combat when their condition is met."


func _update_slot_display() -> void:
	for i in 2:
		var d: Dictionary = DecreeSystem.decrees[i]
		var cond: int = int(d.condition)
		if cond == DecreeSystem.Condition.NONE:
			_slot_labels[i].text = "Slot %d:  -- Empty --" % (i + 1)
			_slot_labels[i].add_theme_color_override("font_color", UITheme.TEXT_DISABLED)
		else:
			var cond_name: String = DecreeSystem.get_condition_name(cond)
			var member: String = d.member_name
			var skill: String = d.skill_name
			_slot_labels[i].text = "Slot %d:  WHEN %s  ->  %s uses %s" % [i + 1, cond_name, member, skill]
			_slot_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)


func _show_menu_items() -> void:
	for i in MAX_LABELS:
		if i < _menu_items.size():
			_labels[i].visible = true
		else:
			_labels[i].visible = false
	_update_cursor()


func _update_cursor() -> void:
	for i in range(_menu_items.size()):
		if i >= MAX_LABELS:
			break
		if i == _cursor:
			_labels[i].text = "> " + _menu_items[i]
			_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
		else:
			_labels[i].text = "  " + _menu_items[i]
			_labels[i].add_theme_color_override("font_color", UITheme.TEXT)


func _process(_delta: float) -> void:
	match _state:
		MenuState.MAIN:
			_handle_main_input()
		MenuState.SELECT_CONDITION:
			_handle_condition_input()
		MenuState.SELECT_MEMBER:
			_handle_member_input()
		MenuState.SELECT_SKILL:
			_handle_skill_input()


func _handle_main_input() -> void:
	if Input.is_action_just_pressed("ui_up"):
		_cursor = (_cursor - 1 + _menu_items.size()) % _menu_items.size()
		_update_cursor()
	elif Input.is_action_just_pressed("ui_down"):
		_cursor = (_cursor + 1) % _menu_items.size()
		_update_cursor()
	elif Input.is_action_just_pressed("ui_accept"):
		match _cursor:
			0:
				_start_editing(0)
			1:
				_start_editing(1)
			2:
				DecreeSystem.clear_decree(0)
				_update_slot_display()
			3:
				DecreeSystem.clear_decree(1)
				_update_slot_display()
			4:
				_open_fusion()
			5:
				_close()
	elif Input.is_action_just_pressed("ui_cancel"):
		_close()


func _start_editing(slot: int) -> void:
	_editing_slot = slot
	_state = MenuState.SELECT_CONDITION
	_title.text = "Select Condition  -  Slot %d" % (slot + 1)
	_cursor = 0

	_menu_items.clear()
	for cond in DecreeSystem.CONDITION_LIST:
		var cond_name: String = DecreeSystem.get_condition_name(int(cond))
		_menu_items.append(cond_name)
	_show_menu_items()
	_info_label.text = "WHEN this condition is true, the Decree fires."


func _handle_condition_input() -> void:
	var count: int = _menu_items.size()
	if Input.is_action_just_pressed("ui_up"):
		_cursor = (_cursor - 1 + count) % count
		_update_cursor()
	elif Input.is_action_just_pressed("ui_down"):
		_cursor = (_cursor + 1) % count
		_update_cursor()
	elif Input.is_action_just_pressed("ui_accept"):
		_selected_condition = int(DecreeSystem.CONDITION_LIST[_cursor])
		_enter_member_select()
	elif Input.is_action_just_pressed("ui_cancel"):
		_show_main()


func _enter_member_select() -> void:
	_state = MenuState.SELECT_MEMBER
	_title.text = "Select Party Member"
	_cursor = 0
	_menu_items.clear()
	for c in party:
		var elem_name: String = CombatData.ELEMENT_NAMES.get(c.element, "?")
		_menu_items.append(c.display_name + " (" + elem_name + ")")
	_show_menu_items()
	_info_label.text = "WHO will carry out the Decree?"


func _handle_member_input() -> void:
	var count: int = _menu_items.size()
	if Input.is_action_just_pressed("ui_up"):
		_cursor = (_cursor - 1 + count) % count
		_update_cursor()
	elif Input.is_action_just_pressed("ui_down"):
		_cursor = (_cursor + 1) % count
		_update_cursor()
	elif Input.is_action_just_pressed("ui_accept"):
		_selected_member_idx = _cursor
		_enter_skill_select()
	elif Input.is_action_just_pressed("ui_cancel"):
		_start_editing(_editing_slot)


func _enter_skill_select() -> void:
	_state = MenuState.SELECT_SKILL
	_title.text = "Select Skill"
	_cursor = 0
	var member: Combatant = party[_selected_member_idx]
	_menu_items.clear()
	for s in member.skills:
		var cost: int = int(s.sp_cost)
		var cost_str: String = " (%d SP)" % cost if cost > 0 else ""
		var s_name: String = s.name
		_menu_items.append(s_name + cost_str)
	_show_menu_items()
	_info_label.text = "WHAT action will be pre-ordained?"


func _handle_skill_input() -> void:
	var member: Combatant = party[_selected_member_idx]
	var count: int = member.skills.size()
	if Input.is_action_just_pressed("ui_up"):
		_cursor = (_cursor - 1 + count) % count
		_update_cursor()
	elif Input.is_action_just_pressed("ui_down"):
		_cursor = (_cursor + 1) % count
		_update_cursor()
	elif Input.is_action_just_pressed("ui_accept"):
		var skill: Dictionary = member.skills[_cursor]
		var s_name: String = skill.name
		DecreeSystem.set_decree(
			_editing_slot,
			_selected_condition,
			member.display_name,
			s_name
		)
		_show_main()
	elif Input.is_action_just_pressed("ui_cancel"):
		_enter_member_select()


func _open_fusion() -> void:
	# Open fusion menu (it handles its own pause state)
	var fusion := FusionMenuScript.new()
	fusion.party = party
	fusion.reserve = GameManager.reserve
	fusion.closed.connect(_on_fusion_closed)
	get_tree().root.add_child(fusion)


func _on_fusion_closed() -> void:
	# Fusion menu unpauses tree on close — re-pause for altar menu
	get_tree().paused = true
	# Refresh party reference after fusion may have changed it
	party = GameManager.party
	_show_main()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
