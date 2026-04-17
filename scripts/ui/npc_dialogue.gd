extends CanvasLayer

## NPC dialogue box — shows sequential text lines with press-to-advance.
## Used for NPC conversations, boss pre/post-battle text, and sealed passages.

signal closed

var npc_name: String = "???"
# Array of { "text": String, "kind": String (optional) }
# kind = "system" renders as a centered, all-caps game annotation (no speaker),
# distinct from diegetic character speech. Anything else / omitted = dialogue.
var dialogue_lines: Array = []

var _current_line: int = 0
var _text_label: Label = null
var _name_label: Label = null
var _prompt_label: Label = null
var _input_cooldown: float = 0.0  # Prevent instant-skip on open


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_input_cooldown = 0.15
	_build_ui()
	_show_line()


func _build_ui() -> void:
	# Dim overlay
	UITheme.build_overlay(self)

	# Dialogue box — bottom of screen with themed panel
	UITheme.build_panel(self, Vector2(30, 320), Vector2(580, 150))

	# NPC name label — top of dialogue box
	_name_label = Label.new()
	_name_label.position = Vector2(42, 325)
	_name_label.size = Vector2(400, 24)
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", UITheme.TITLE)
	add_child(_name_label)

	# Separator line
	UITheme.build_separator(self, Vector2(40, 345), 560)

	# Dialogue text
	_text_label = Label.new()
	_text_label.position = Vector2(42, 352)
	_text_label.size = Vector2(556, 90)
	_text_label.add_theme_font_size_override("font_size", 13)
	_text_label.add_theme_color_override("font_color", UITheme.TEXT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text_label)

	# "Press E / Space" prompt
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(42, 448)
	_prompt_label.size = Vector2(556, 20)
	_prompt_label.add_theme_font_size_override("font_size", 11)
	_prompt_label.add_theme_color_override("font_color", UITheme.HINT)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_prompt_label)


func _show_line() -> void:
	if _current_line >= dialogue_lines.size():
		_close()
		return
	var line_data: Dictionary = dialogue_lines[_current_line]
	var is_system := String(line_data.get("kind", "")) == "system"

	if is_system:
		_name_label.visible = false
		_text_label.text = String(line_data.get("text", "")).to_upper()
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text_label.add_theme_color_override("font_color", UITheme.TITLE)
		_text_label.add_theme_font_size_override("font_size", 16)
	else:
		_name_label.visible = true
		_name_label.text = npc_name
		_text_label.text = line_data.get("text", "")
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_text_label.add_theme_color_override("font_color", UITheme.TEXT)
		_text_label.add_theme_font_size_override("font_size", 13)

	if _current_line < dialogue_lines.size() - 1:
		_prompt_label.text = "[E / Space] Next"
	else:
		_prompt_label.text = "[E / Space] Close"


func _process(delta: float) -> void:
	if _input_cooldown > 0.0:
		_input_cooldown -= delta
		return

	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_current_line += 1
		_input_cooldown = 0.1
		_show_line()
	elif Input.is_action_just_pressed("ui_cancel"):
		_close()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
