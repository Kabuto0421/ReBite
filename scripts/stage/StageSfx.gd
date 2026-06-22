# 2026-06-14: ステージ共通の短い効果音再生を扱う。
class_name StageSfx
extends Node

signal important_sound_played(sound_name: StringName)

@export var volume_db := -5.0 # 効果音全体の音量。
@export var enabled := true # 効果音を再生するかどうか。

var streams := {} # SE名からAudioStreamへの対応。
var volume_offsets := {} # SEごとの音量補正。
var duck_sound_names := {} # BGMを一瞬下げる対象SE。

# 使用するSEを読み込む。
func setup() -> void:
	streams = {
		&"bite_hit": _load_audio("res://assets/sfx/bite_hit.mp3"),
		&"memory_tag_crack": _load_audio("res://assets/sfx/memory_tag_crack.mp3"),
		&"skull_dash": _load_audio("res://assets/sfx/skull_dash.wav"),
		&"hop_launch": _load_audio("res://assets/sfx/hop_launch.wav"),
		&"spike_hit": _load_audio("res://assets/sfx/spike_hit.wav"),
		&"action_break_block": _load_audio("res://assets/sfx/action_break_block.wav"),
		&"enemy_die": _load_audio("res://assets/sfx/enemy_die.wav"),
	}
	volume_offsets = {
		&"skull_dash": -2.0,
		&"hop_launch": -2.0,
		&"bite_hit": -2.0,
		&"memory_tag_crack": -2.0,
		&"spike_hit": 0.0,
		&"action_break_block": 0.0,
		&"enemy_die": 0.0,
	}
	duck_sound_names = {
		&"bite_hit": true,
		&"memory_tag_crack": true,
		&"spike_hit": true,
		&"action_break_block": true,
		&"enemy_die": true,
	}

# 終了時に再生中Playerを明示的に解放する。
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.free()

# 指定名のSEを一度だけ鳴らす。
func play(sound_name: StringName) -> void:
	if not enabled:
		return
	if DisplayServer.get_name() == "headless":
		return
	if not streams.has(sound_name) or streams[sound_name] == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams[sound_name]
	player.volume_db = volume_db + float(volume_offsets.get(sound_name, 0.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	if duck_sound_names.has(sound_name):
		important_sound_played.emit(sound_name)

# 音声をimportキャッシュに依存せず読み込む。
func _load_audio(path: String) -> AudioStream:
	var extension := path.get_extension().to_lower()
	var stream: AudioStream
	match extension:
		"wav":
			stream = AudioStreamWAV.load_from_file(path)
		"mp3":
			stream = AudioStreamMP3.load_from_file(path)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
		_:
			push_error("Unsupported sfx format: %s" % path)
	if stream == null:
		push_error("Failed to load sfx: %s" % path)
	return stream
