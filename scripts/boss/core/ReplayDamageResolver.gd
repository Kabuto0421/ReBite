# 2026-06-22: 再演由来の環境ダメージだけを一度だけBossへ通す。
class_name ReplayDamageResolver
extends Node

signal damage_approved(event: Dictionary) # 検証済みダメージをEncounterへ通知する。

var _resolved_event_ids: Dictionary = {} # 重複適用済みイベントIDの集合。

# 再演由来かつ未処理ならダメージを承認する。
func request_damage(event: Dictionary) -> bool:
	var event_id := str(event.get("event_id", ""))
	if event_id.is_empty() or _resolved_event_ids.has(event_id):
		return false
	if event.get("source", &"NATURAL") != &"REBITE_REPLAY":
		return false
	_resolved_event_ids[event_id] = true
	damage_approved.emit(event)
	return true

# Encounterリセット時に重複履歴を消す。
func reset() -> void:
	_resolved_event_ids.clear()
