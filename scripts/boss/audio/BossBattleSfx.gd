# 2026-06-23: ボス戦固有SEの登録、遅延再生、音量、BGMダッキング通知を提供する。
class_name BossBattleSfx
extends Node

signal important_sound_played(cue_id: StringName) # BGMを下げるべき重要SEの再生を通知する。
signal cue_requested(cue_id: StringName, delay: float) # テストや字幕連携用に意味Cueの要求を通知する。

@export var enabled := true # ボス戦SEを再生するか。
@export var volume_db := -5.0 # ボス戦SE全体の基準音量。

var cue_streams: Dictionary = {} # Cue IDから音源への対応。
var cue_volume_offsets: Dictionary = {} # Cueごとの音量補正。
var important_cues: Dictionary = {} # BGMダッキング対象Cue。

# Cue IDと音源を登録する。
func register_cue(cue_id: StringName, path: String, volume_offset_db: float = 0.0, important: bool = false) -> void:
	cue_streams[cue_id] = _load_audio(path)
	cue_volume_offsets[cue_id] = volume_offset_db
	important_cues[cue_id] = important

# Cueを即時または指定秒後に再生する。
func play_cue(cue_id: StringName, delay: float = 0.0) -> void:
	if not enabled or not cue_streams.has(cue_id) or cue_streams[cue_id] == null:
		return
	cue_requested.emit(cue_id, delay)
	if delay <= 0.0:
		_play_cue_now(cue_id)
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(delay)
	tween.tween_callback(func(): _play_cue_now(cue_id))

# 再生中Playerを終了時に明示的に破棄する。
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.free()

# 登録済みCueを一度だけ再生する。
func _play_cue_now(cue_id: StringName) -> void:
	if not enabled or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = cue_streams[cue_id]
	player.volume_db = volume_db + float(cue_volume_offsets.get(cue_id, 0.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	if bool(important_cues.get(cue_id, false)):
		important_sound_played.emit(cue_id)

# ファイル形式に応じたAudioStreamを読み込む。
func _load_audio(path: String) -> AudioStream:
	var stream: AudioStream
	match path.get_extension().to_lower():
		"wav":
			stream = AudioStreamWAV.load_from_file(path)
		"mp3":
			stream = AudioStreamMP3.load_from_file(path)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
		_:
			push_error("Unsupported boss sfx format: %s" % path)
	if stream == null:
		push_error("Failed to load boss sfx: %s" % path)
	return stream
