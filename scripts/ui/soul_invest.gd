extends CanvasLayer

## Soul Investment — spend SP to permanently boost creature stats.
## Accessible from Soul Ledger (pause menu) via [2] key.

signal closed

enum InvestState { SELECT_CREATURE, SELECT_STAT, CONFIRM }

var party: Array = []
var reserve: Array = []

var _state: int = InvestState.SELECT_CREATURE
var _cursor: int = 0
var _all_creatures: Array = []
var _selected: Combatant = null
var _stat_cursor: int = 0

var _labels: Array = []
var _stat_labels: Array = []
var _title_label: Label
var _info_label: Label

const MAX_LABELS := 12
const STAT_NAMES := ["HP", "ATK", "DEF", "MAG", "RES", "SPD"]
const STAT_KEYS := ["hp", "atk", "defense", "mag", "res", "spd"]
# Exchange rates: SP cost -> stat gain
const INVEST_RATES := {
	"hp": 10,    # 1 SP -> +10 HP
	"atk": 1,    # 1 SP -> +1 ATK
	"defense": 1,
	"mag": 1,
	"res": 1,
	"spd": 1,    # SPD is 1:1 but powerful — capped by tier
}
# Note: mechanics.md says SPD is 0.5 per SP, but that creates fractional stats.
# Using 1:1 with the tier cap as the balancing lever instead.


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_all_creatures = party + reserve
	_build_ui()
	_show_creature_select()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_labels.clear()
	_stat_labels.clear()

	UITheme.build_panel(self, Vector2(40, 40), Vector2(560, 400))

	_title_label = _make_label(Vector2(40, 48), Vector2(560, 28),
		"Soul Investment", 20, UITheme.TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_info_label = _make_label(Vector2(40, 76), Vector2(560, 20),
		"Spend SP to permanently strengthen a creature.",
		11, UITheme.TEXT_DIM)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.build_separator(self, Vector2(60, 100), 520)

	for i in range(MAX_LABELS):
		var lbl := _make_label(
			Vector2(70, 108 + i * 24), Vector2(500, 24), "", 13, UITheme.TEXT)
		lbl.visible = false
		_labels.append(lbl)

	for i in range(8):
		var lbl := _make_label(
			Vector2(70, 108 + i * 28), Vector2(500, 28), "", 14, UITheme.TEXT)
		lbl.visible = false
		_stat_labels.append(lbl)


func _show_creature_select() -> void:
	_state = InvestState.SELECT_CREATURE
	_title_label.text = "Soul Investment — Select Creature"
	_cursor = 0
	_hide_stat_labels()

	_all_creatures = GameManager.party + GameManager.reserve
	for i in range(MAX_LABELS):
		if i < _all_creatures.size():
			var c: Combatant = _all_creatures[i]
			var invested := c.total_invested()
			var cap := c.get_investment_cap()
			var sp_text := "SP %d/%d" % [c.sp, c.max_sp]
			var inv_text := "Invested: %d/%d" % [invested, cap]
			_labels[i].text = "  %s  %s  %s" % [c.display_name, sp_text, inv_text]
			_labels[i].visible = true

			# Grey out if no SP or at cap
			if c.sp <= 0 or invested >= cap:
				_labels[i].add_theme_color_override("font_color", UITheme.TEXT_DISABLED)
			else:
				_labels[i].add_theme_color_override("font_color", UITheme.TEXT)
		else:
			_labels[i].visible = false

	_update_list_cursor(_all_creatures.size())
	_info_label.text = "SP spent is permanent — it cannot be recovered."


func _show_stat_select() -> void:
	_state = InvestState.SELECT_STAT
	_title_label.text = "Invest in " + _selected.display_name
	_stat_cursor = 0

	for lbl in _labels:
		lbl.visible = false

	var invested := _selected.total_invested()
	var cap := _selected.get_investment_cap()
	var remaining := cap - invested
	_info_label.text = "SP: %d   Invested: %d/%d   (%d slots remaining)" % [
		_selected.sp, invested, cap, remaining]

	_update_stat_display()


func _update_stat_display() -> void:
	for i in range(STAT_NAMES.size()):
		var stat_key: String = STAT_KEYS[i]
		var current_val: int = _get_stat(_selected, stat_key)
		var inv_amount: int = _selected.invested.get(stat_key, 0)
		var rate: int = INVEST_RATES[stat_key]
		var gain_text := "+%d" % rate

		var text := "  %s: %d" % [STAT_NAMES[i], current_val]
		if inv_amount > 0:
			text += "  (invested: +%d)" % (inv_amount * rate)
		text += "     [1 SP -> %s]" % gain_text

		_stat_labels[i].text = text
		_stat_labels[i].visible = true

	# Close option
	_stat_labels[STAT_NAMES.size()].text = "  Back"
	_stat_labels[STAT_NAMES.size()].visible = true

	_update_stat_cursor()


func _update_stat_cursor() -> void:
	var count: int = STAT_NAMES.size() + 1  # +1 for Back
	for i in range(count):
		if i >= _stat_labels.size():
			break
		if i == _stat_cursor:
			_stat_labels[i].text = "> " + _stat_labels[i].text.lstrip("> ")
			_stat_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
		else:
			_stat_labels[i].text = "  " + _stat_labels[i].text.lstrip("> ")
			_stat_labels[i].add_theme_color_override("font_color", UITheme.TEXT)


func _hide_stat_labels() -> void:
	for lbl in _stat_labels:
		lbl.visible = false


func _get_stat(c: Combatant, key: String) -> int:
	match key:
		"hp": return c.max_hp
		"atk": return c.atk
		"defense": return c.defense
		"mag": return c.mag
		"res": return c.res
		"spd": return c.spd
	return 0


func _set_stat(c: Combatant, key: String, val: int) -> void:
	match key:
		"hp":
			c.max_hp = val
			c.hp = mini(c.hp, c.max_hp)  # Don't auto-heal
		"atk": c.atk = val
		"defense": c.defense = val
		"mag": c.mag = val
		"res": c.res = val
		"spd": c.spd = val


func _invest_stat(stat_idx: int) -> void:
	if stat_idx >= STAT_KEYS.size():
		return
	var stat_key: String = STAT_KEYS[stat_idx]
	var invested := _selected.total_invested()
	var cap := _selected.get_investment_cap()

	if _selected.sp <= 0:
		_info_label.text = "Not enough SP!"
		return
	if invested >= cap:
		_info_label.text = "Investment cap reached!"
		return

	# Spend 1 SP
	_selected.sp -= 1
	_selected.max_sp = maxi(_selected.max_sp, 0)  # SP pool doesn't shrink for max

	# Apply stat gain
	var rate: int = INVEST_RATES[stat_key]
	var current := _get_stat(_selected, stat_key)
	_set_stat(_selected, stat_key, current + rate)

	# Track investment
	_selected.invested[stat_key] = _selected.invested.get(stat_key, 0) + 1

	# Refresh display
	var new_invested := _selected.total_invested()
	var remaining := cap - new_invested
	_info_label.text = "SP: %d   Invested: %d/%d   (%d slots remaining)" % [
		_selected.sp, new_invested, cap, remaining]
	_update_stat_display()


func _update_list_cursor(count: int) -> void:
	for i in range(_labels.size()):
		if i < count:
			var base_text: String = _labels[i].text.lstrip("> ")
			if i == _cursor:
				_labels[i].text = "> " + base_text
				# Keep dim if unaffordable
				var c: Combatant = _all_creatures[i] if i < _all_creatures.size() else null
				if c and (c.sp <= 0 or c.total_invested() >= c.get_investment_cap()):
					_labels[i].add_theme_color_override("font_color", UITheme.TEXT_DIM)
				else:
					_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
			else:
				_labels[i].text = "  " + base_text
				# Restore correct color: grey if unavailable, white otherwise
				var c: Combatant = _all_creatures[i] if i < _all_creatures.size() else null
				if c and (c.sp <= 0 or c.total_invested() >= c.get_investment_cap()):
					_labels[i].add_theme_color_override("font_color", UITheme.TEXT_DISABLED)
				else:
					_labels[i].add_theme_color_override("font_color", UITheme.TEXT)


func _process(_delta: float) -> void:
	match _state:
		InvestState.SELECT_CREATURE:
			var count: int = _all_creatures.size()
			if count == 0:
				if Input.is_action_just_pressed("ui_cancel"):
					_close()
				return
			if Input.is_action_just_pressed("ui_up"):
				_cursor = (_cursor - 1 + count) % count
				_update_list_cursor(count)
			elif Input.is_action_just_pressed("ui_down"):
				_cursor = (_cursor + 1) % count
				_update_list_cursor(count)
			elif Input.is_action_just_pressed("ui_accept"):
				_selected = _all_creatures[_cursor]
				if _selected.sp > 0 and _selected.total_invested() < _selected.get_investment_cap():
					_show_stat_select()
				else:
					_info_label.text = "No SP available or investment cap reached."
			elif Input.is_action_just_pressed("ui_cancel"):
				_close()

		InvestState.SELECT_STAT:
			var count: int = STAT_NAMES.size() + 1
			if Input.is_action_just_pressed("ui_up"):
				_stat_cursor = (_stat_cursor - 1 + count) % count
				_update_stat_cursor()
			elif Input.is_action_just_pressed("ui_down"):
				_stat_cursor = (_stat_cursor + 1) % count
				_update_stat_cursor()
			elif Input.is_action_just_pressed("ui_accept"):
				if _stat_cursor < STAT_NAMES.size():
					_invest_stat(_stat_cursor)
				else:
					# Back
					_build_ui()
					_show_creature_select()
			elif Input.is_action_just_pressed("ui_cancel"):
				_build_ui()
				_show_creature_select()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


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
