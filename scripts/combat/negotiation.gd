extends CanvasLayer

## Negotiation UI — race-specific dialogue tree for creature recruitment.
## Created by BattleScene when player selects "Talk" and targets an enemy.

signal negotiation_ended(result: String, creature: Combatant)
# result: "success", "fail", "full" (party+reserve full)

enum NegState { INTRO, QUESTION, RESULT }

var target: Combatant = null
var party_corrupted: bool = false  # Is any party member corrupted?

var _state: int = NegState.INTRO
var _exchanges: Array = []
var _current_exchange: int = 0
var _affinity: int = 0
var _cursor: int = 0
var _intro_timer: float = 0.0
var _result_timer: float = 0.0

# UI nodes
var _bg: ColorRect
var _portrait: ColorRect
var _name_label: Label
var _prompt_label: Label
var _option_labels: Array = []
var _affinity_indicator: ColorRect  # subtle visual feedback
var _result_label: Label

const MAX_OPTIONS := 4


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Get dialogue exchanges for this creature's race
	_exchanges = CombatData.get_negotiation_exchanges(target.race, randi_range(2, 3))
	if _exchanges.is_empty():
		# No dialogue for this race — auto-fail
		negotiation_ended.emit("fail", target)
		queue_free()
		return

	# Apply alignment modifier to starting affinity
	_affinity = CombatData.get_alignment_affinity_mod(party_corrupted, target.element)

	# Mark creature as seen in compendium
	GameManager.mark_seen(target.creature_id)

	_build_ui()
	_start_intro()


func _build_ui() -> void:
	UITheme.build_panel(self, Vector2(40, 40), Vector2(560, 400))

	# Creature portrait (colored rectangle placeholder)
	var elem_color: Color = CombatData.ELEMENT_COLORS.get(target.element, Color.GRAY)
	_portrait = _make_rect(Vector2(260, 60), Vector2(120, 80), elem_color)

	# Creature name + race
	var race_name: String = CombatData.RACE_NAMES.get(target.race, "Unknown")
	_name_label = _make_label(Vector2(40, 150), Vector2(560, 24),
		target.display_name + "  (" + race_name + ")", 16, UITheme.TEXT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Prompt text
	_prompt_label = _make_label(Vector2(60, 190), Vector2(520, 60), "", 13, UITheme.TEXT)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Option labels
	for i in range(MAX_OPTIONS):
		var lbl := _make_label(
			Vector2(80, 270 + i * 28), Vector2(480, 26), "", 13, UITheme.TEXT)
		lbl.visible = false
		_option_labels.append(lbl)

	# Affinity indicator (shifts creature portrait position subtly)
	_affinity_indicator = _make_rect(Vector2(550, 60), Vector2(12, 80), Color(0.3, 0.3, 0.3, 0.5))

	# Result label (shown at end)
	_result_label = _make_label(Vector2(40, 200), Vector2(560, 40), "", 20, UITheme.TITLE)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.visible = false


func _start_intro() -> void:
	_state = NegState.INTRO
	_prompt_label.text = target.display_name + " regards you..."
	for lbl in _option_labels:
		lbl.visible = false
	_intro_timer = 1.5


func _show_question() -> void:
	if _current_exchange >= _exchanges.size():
		_show_result()
		return

	_state = NegState.QUESTION
	var exchange: Dictionary = _exchanges[_current_exchange]
	_prompt_label.text = exchange.prompt
	_cursor = 0

	var options: Array = exchange.options
	for i in range(MAX_OPTIONS):
		if i < options.size():
			_option_labels[i].text = "  " + options[i].text
			_option_labels[i].visible = true
		else:
			_option_labels[i].visible = false

	_update_cursor()


func _show_result() -> void:
	_state = NegState.RESULT
	_prompt_label.visible = false
	for lbl in _option_labels:
		lbl.visible = false

	var threshold: int = CombatData.get_recruitment_threshold(target.tier)

	if not target.is_recruitable:
		_result_label.text = target.display_name + " cannot be swayed."
		_result_label.add_theme_color_override("font_color", UITheme.CORRUPT)
		_result_label.visible = true
		_result_timer = 2.0
		return

	if _affinity >= threshold:
		# Check if party/reserve has room
		if GameManager.party.size() < GameManager.MAX_ACTIVE or \
		   GameManager.reserve.size() < GameManager.MAX_RESERVE:
			_result_label.text = target.display_name + " joins your party!"
			_result_label.add_theme_color_override("font_color", UITheme.TITLE)
			# Shift portrait closer (positive feedback)
			var tw := create_tween()
			tw.tween_property(_portrait, "position:y", 50.0, 0.4)
		else:
			_result_label.text = "Party and reserve are full!"
			_result_label.add_theme_color_override("font_color", UITheme.SECTION_HEADER)
	else:
		_result_label.text = target.display_name + " is unimpressed. It attacks!"
		_result_label.add_theme_color_override("font_color", UITheme.CORRUPT)
		# Shift portrait away (negative feedback)
		var tw := create_tween()
		tw.tween_property(_portrait, "position:y", 70.0, 0.4)

	_result_label.visible = true
	_result_timer = 2.5


func _update_cursor() -> void:
	var exchange: Dictionary = _exchanges[_current_exchange]
	var options: Array = exchange.options
	for i in range(mini(options.size(), MAX_OPTIONS)):
		if i == _cursor:
			_option_labels[i].text = "> " + options[i].text
			_option_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
		else:
			_option_labels[i].text = "  " + options[i].text
			_option_labels[i].add_theme_color_override("font_color", UITheme.TEXT)


func _update_affinity_visual() -> void:
	# Color the indicator based on current affinity
	if _affinity >= 3:
		_affinity_indicator.color = Color(0.3, 0.8, 0.3, 0.7)
	elif _affinity >= 1:
		_affinity_indicator.color = Color(0.7, 0.7, 0.3, 0.5)
	elif _affinity >= 0:
		_affinity_indicator.color = Color(0.5, 0.5, 0.5, 0.3)
	else:
		_affinity_indicator.color = Color(0.8, 0.3, 0.3, 0.5)


func _process(delta: float) -> void:
	match _state:
		NegState.INTRO:
			_intro_timer -= delta
			if _intro_timer <= 0:
				_show_question()

		NegState.QUESTION:
			var exchange: Dictionary = _exchanges[_current_exchange]
			var options: Array = exchange.options
			var option_count: int = options.size()

			if Input.is_action_just_pressed("ui_up"):
				_cursor = (_cursor - 1 + option_count) % option_count
				_update_cursor()
			elif Input.is_action_just_pressed("ui_down"):
				_cursor = (_cursor + 1) % option_count
				_update_cursor()
			elif Input.is_action_just_pressed("ui_accept"):
				# Apply score
				var score: int = options[_cursor].score
				_affinity += score
				_update_affinity_visual()

				# Brief feedback flash
				if score > 0:
					_portrait.modulate = Color(1.2, 1.2, 1.0)
				elif score < 0:
					_portrait.modulate = Color(0.7, 0.5, 0.5)
				var tw := create_tween()
				tw.tween_property(_portrait, "modulate", Color.WHITE, 0.5)

				_current_exchange += 1
				# Small delay before next question
				_state = NegState.INTRO
				if _current_exchange < _exchanges.size():
					_prompt_label.text = "..."
					for lbl in _option_labels:
						lbl.visible = false
					_intro_timer = 0.8
				else:
					_intro_timer = 0.5

		NegState.RESULT:
			_result_timer -= delta
			if _result_timer <= 0:
				_finish()


func _finish() -> void:
	var threshold: int = CombatData.get_recruitment_threshold(target.tier)
	var result: String

	if not target.is_recruitable:
		result = "fail"
	elif _affinity >= threshold:
		if GameManager.party.size() < GameManager.MAX_ACTIVE or \
		   GameManager.reserve.size() < GameManager.MAX_RESERVE:
			result = "success"
		else:
			result = "full"
	else:
		result = "fail"

	negotiation_ended.emit(result, target)
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
