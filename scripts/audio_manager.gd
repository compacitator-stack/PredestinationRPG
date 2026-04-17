extends Node

## Manages all game audio: music, jingles, and SFX.
## Autoloaded as "AudioManager".

# --- Music tracks (looping) ---
const MUSIC_TRACKS := {
	"cathedral": "res://assets/audio/music/crumbling_altar.ogg",
	"overgrown": "res://assets/audio/music/overgrown_wilds.ogg",
	"battle": "res://assets/audio/music/standard_battle.ogg",
	"boss_seraph": "res://assets/audio/music/boss_corrupted_seraph.ogg",
	"broken_sanctuary": "res://assets/audio/music/broken_sanctuary.ogg",
	"save_altar": "res://assets/audio/music/save_altar.ogg",
}

# --- Floor name -> music track mapping ---
const FLOOR_MUSIC := {
	"The Shattered Cathedral": "cathedral",
	"The Overgrown Wilds": "overgrown",
}

# --- Players ---
var _music_player: AudioStreamPlayer
var _jingle_player: AudioStreamPlayer

# --- State ---
var _current_track: String = ""
var _paused_track: String = ""
var _paused_position: float = 0.0
var _fade_tween: Tween = null

const FADE_DURATION := 0.8
const MUSIC_VOLUME_DB := 0.0
const JINGLE_VOLUME_DB := 0.0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)

	_jingle_player = AudioStreamPlayer.new()
	_jingle_player.bus = "Master"
	_jingle_player.volume_db = JINGLE_VOLUME_DB
	add_child(_jingle_player)


func play_music(track_name: String, fade_in: bool = true) -> void:
	if track_name == _current_track and _music_player.playing:
		return  # Already playing this track

	var path: String = MUSIC_TRACKS.get(track_name, "")
	if path == "":
		push_warning("AudioManager: unknown track '%s'" % track_name)
		return

	# Stop any fade in progress
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	# Load and configure stream
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("AudioManager: failed to load '%s'" % path)
		return

	# Enable looping on OGG streams
	if stream is AudioStreamOggVorbis:
		stream.loop = true

	_current_track = track_name
	_music_player.stream = stream

	if fade_in:
		_music_player.volume_db = -40.0
		_music_player.play()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_music_player, "volume_db", MUSIC_VOLUME_DB, FADE_DURATION)
	else:
		_music_player.volume_db = MUSIC_VOLUME_DB
		_music_player.play()


func stop_music(fade_out: bool = true) -> void:
	if not _music_player.playing:
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if fade_out:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_music_player, "volume_db", -40.0, FADE_DURATION)
		_fade_tween.tween_callback(_music_player.stop)
		_fade_tween.tween_callback(func() -> void: _current_track = "")
	else:
		_music_player.stop()
		_current_track = ""


func pause_music() -> void:
	if _music_player.playing:
		_paused_track = _current_track
		_paused_position = _music_player.get_playback_position()
		_music_player.stop()


func resume_music() -> void:
	if _paused_track == "":
		return

	var path: String = MUSIC_TRACKS.get(_paused_track, "")
	if path == "":
		_paused_track = ""
		return

	var stream: AudioStream = load(path)
	if stream == null:
		_paused_track = ""
		return

	if stream is AudioStreamOggVorbis:
		stream.loop = true

	_current_track = _paused_track
	_music_player.stream = stream
	_music_player.volume_db = MUSIC_VOLUME_DB
	_music_player.play(_paused_position)
	_paused_track = ""
	_paused_position = 0.0


func play_music_for_floor(floor_name: String) -> void:
	var track: String = FLOOR_MUSIC.get(floor_name, "")
	if track != "":
		play_music(track)
	else:
		stop_music(false)


func play_altar_music() -> void:
	pause_music()
	play_music("save_altar", true)


func stop_altar_music() -> void:
	stop_music(false)
	resume_music()


func play_battle_music() -> void:
	pause_music()
	play_music("battle", false)


func play_boss_music(boss_id: String) -> void:
	pause_music()
	if boss_id == "corrupted_seraph":
		play_music("boss_seraph", false)
	else:
		play_music("battle", false)


func on_battle_ended() -> void:
	stop_music(false)
	resume_music()
