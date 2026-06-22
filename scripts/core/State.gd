# 2026-06-13: 各状態クラスが共有する基本インターフェース。
class_name State
extends Node

signal transition_requested(next_state_name: StringName, payload: Variant) # 状態側から遷移要求を出す。

var owner_node: Node # この状態が操作する所有ノード。

# 所有ノードを状態に渡す。
func setup(target: Node) -> void:
	owner_node = target

# 状態へ入った時に呼ばれる。
func enter(_payload: Variant = null) -> void:
	pass

# 状態から出る時に呼ばれる。
func exit() -> void:
	pass

# 物理更新で呼ばれる。
func physics_update(_delta: float) -> void:
	pass

# 通常更新で呼ばれる。
func process_update(_delta: float) -> void:
	pass

# 入力イベントを処理する。
func handle_input(_event: InputEvent) -> void:
	pass
