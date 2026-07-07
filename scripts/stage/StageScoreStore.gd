# 2026-07-07: ステージ別スコアの保存と取得を担当する。
class_name StageScoreStore
extends RefCounted

const SAVE_PATH := "user://stage_scores.json"

# 現在の体験版対象ステージID一覧を返す。
static func current_stage_ids() -> PackedStringArray:
	return PackedStringArray([
		"Stage0",
		"Stage1",
		"Stage2",
		"Stage3",
		"Stage4",
		"Stage5",
		"Stage6",
		"Stage7",
		"Stage8",
		"Stage9",
		"Stage10",
	])

# 指定ステージのベストスコア情報を返す。
static func best_for_stage(stage_id: String) -> Dictionary:
	var data := load_all()
	return data.get(stage_id, {})

# 今回の結果がベストなら保存し、保存後のベスト情報を返す。
static func record_result(stage_id: String, result: Dictionary) -> Dictionary:
	var data := load_all()
	var previous: Dictionary = data.get(stage_id, {})
	if previous.is_empty() or int(result.get("score", 0)) > int(previous.get("score", 0)):
		data[stage_id] = _normalized_result(stage_id, result)
		save_all(data)
	return data.get(stage_id, result)

# ランキング用に全ステージのベストスコア合計を返す。
static func total_best_score(stage_ids: Variant = null) -> int:
	var total := 0
	var data := load_all()
	for stage_id in _resolved_stage_ids(stage_ids):
		var result: Dictionary = data.get(String(stage_id), {})
		total += int(result.get("score", 0))
	return total

# ランキング用にクリア済みステージ数を返す。
static func completed_stage_count(stage_ids: Variant = null) -> int:
	var count := 0
	var data := load_all()
	for stage_id in _resolved_stage_ids(stage_ids):
		var result: Dictionary = data.get(String(stage_id), {})
		if int(result.get("score", 0)) > 0:
			count += 1
	return count

# ランキング用に全ステージの星合計を返す。
static func total_stars(stage_ids: Variant = null) -> int:
	var total := 0
	var data := load_all()
	for stage_id in _resolved_stage_ids(stage_ids):
		var result: Dictionary = data.get(String(stage_id), {})
		total += int(result.get("stars", 0))
	return total

# Unityroomなどのランキング送信用に必要な集計情報をまとめる。
static func ranking_payload(stage_ids: Variant = null) -> Dictionary:
	var resolved_stage_ids := _resolved_stage_ids(stage_ids)
	var data := load_all()
	var stage_scores := {}
	for stage_id in resolved_stage_ids:
		stage_scores[String(stage_id)] = data.get(String(stage_id), {})
	return {
		"total_score": total_best_score(resolved_stage_ids),
		"completed_stage_count": completed_stage_count(resolved_stage_ids),
		"stage_count": resolved_stage_ids.size(),
		"total_stars": total_stars(resolved_stage_ids),
		"stages": stage_scores,
	}

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

# 保存するスコア結果に後続連携向けの共通フィールドを補う。
static func _normalized_result(stage_id: String, result: Dictionary) -> Dictionary:
	var normalized := result.duplicate(true)
	normalized["stage_id"] = stage_id
	normalized["score"] = int(normalized.get("score", 0))
	normalized["stars"] = int(normalized.get("stars", 0))
	normalized["elapsed"] = float(normalized.get("elapsed", 0.0))
	normalized["deaths"] = int(normalized.get("deaths", 0))
	normalized["updated_at_unix"] = int(Time.get_unix_time_from_system())
	return normalized

# 明示ステージ一覧がない場合は現在の体験版対象ステージを使う。
static func _resolved_stage_ids(stage_ids: Variant) -> PackedStringArray:
	if stage_ids == null:
		return current_stage_ids()
	if stage_ids is PackedStringArray:
		return stage_ids
	if stage_ids is Array:
		return PackedStringArray(stage_ids)
	return current_stage_ids()
