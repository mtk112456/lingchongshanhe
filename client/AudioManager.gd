extends Node

## Global audio: music + polyphonic SFX + persisted volumes.
## Safe in headless: all playback no-ops if the stream is missing.

const SFX_DIR := "res://assets/audio/sfx/"
const BGM_DIR := "res://assets/audio/bgm/"
const SETTINGS_PATH := "user://settings.cfg"
const SFX_VOICES := 8

var _music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _bgm_cache: Dictionary = {}
var _sfx_index := 0

var master_volume := 1.0
var music_volume := 0.7
var sfx_volume := 0.9
var is_reduced_motion := false

const SFX_ALIASES := {
	"wall_break": "wall",
	"stamp": "victory",
	"confirm": "play",
	"card_withdraw": "draw",
}

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_load_settings()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = _linear_to_db(music_volume * master_volume)
	add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.volume_db = _linear_to_db(sfx_volume * master_volume)
		add_child(p)
		_sfx_players.append(p)
	# Keep autoload alive when scenes change.
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_sfx(name: String, pitch: float = 1.0) -> void:
	if name == "" or _sfx_players.is_empty():
		return
	var stream := _load_sfx(name)
	if stream == null:
		return
	var p := _sfx_players[_sfx_index % _sfx_players.size()]
	_sfx_index += 1
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.6, 1.6)
	p.play()

func play_bgm(name: String, fade: float = 0.4) -> void:
	if name == "" or _music == null:
		return
	if _music.playing and _music.stream != null and _music.stream.resource_path.ends_with(name + ".wav"):
		return
	var stream := _load_bgm(name)
	if stream == null:
		return
	if _music.playing:
		var tw := create_tween()
		tw.tween_property(_music, "volume_db", -40.0, fade)
		tw.tween_callback(func():
			_music.stream = stream
			_music.volume_db = _linear_to_db(music_volume * master_volume)
			_music.play()
		)
	else:
		_music.stream = stream
		_music.volume_db = _linear_to_db(music_volume * master_volume)
		_music.play()

func stop_bgm() -> void:
	if _music != null:
		_music.stop()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_reduced_motion(v: bool) -> void:
	is_reduced_motion = v
	_save_settings()

func _apply_volumes() -> void:
	if _music != null:
		_music.volume_db = _linear_to_db(music_volume * master_volume)
	for p in _sfx_players:
		p.volume_db = _linear_to_db(sfx_volume * master_volume)

func _load_sfx(name: String) -> AudioStream:
	if _sfx_cache.has(name):
		return _sfx_cache[name]
	var file := str(SFX_ALIASES.get(name, name))
	var path := SFX_DIR + file + ".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_sfx_cache[name] = stream
	return stream

func _load_bgm(name: String) -> AudioStream:
	if _bgm_cache.has(name):
		return _bgm_cache[name]
	var path := BGM_DIR + name + ".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	# 导入参数里 edit/loop_mode 仍是 0，这里兜底开循环，否则播完一遍就静音停住。
	var wav := stream as AudioStreamWAV
	if wav != null:
		var frames := int(wav.get_length() * wav.mix_rate)
		if frames > 0:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = frames
	_bgm_cache[name] = stream
	return stream

func has_bgm(name: String) -> bool:
	return ResourceLoader.exists(BGM_DIR + name + ".wav")

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _linear_to_db(v: float) -> float:
	if v <= 0.001:
		return -80.0
	return 20.0 * log(v) / log(10.0)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	is_reduced_motion = bool(cfg.get_value("access", "reduced_motion", false))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("access", "reduced_motion", is_reduced_motion)
	cfg.save(SETTINGS_PATH)
