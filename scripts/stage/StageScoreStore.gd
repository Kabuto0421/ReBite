# 2026-07-07: ステージ別スコアの保存と取得を担当する。
class_name StageScoreStore
extends RefCounted

const SAVE_PATH := "user://stage_scores.json"

# 指定ステージのベストスコア情報を返す。
static func best_for_stage(stage_id: String) -> Dictionary:
	var data := load_all()
	return data.get(stage_id, {})

# 今回の結果がベストなら保存し、保存後のベスト情報を返す。
static func record_result(stage_id: String, result: Dictionary) -> Dictionary:
	var data := load_all()
	var previous: Dictionary = data.get(stage_id, {})
	if previous.is_empty() or int(result.get("score", 0)) > int(previous.get("score", 0)):
		data[stage_id] = result
		save_all(data)
	return data.get(stage_id, result)

# 全ステージの保存済みスコア情報を返す。
static func load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

# 全ステージのスコア情報を保存する。
static func save_all(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
