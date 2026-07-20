# 2026-07-21: 三層のBoar搬送と岩押しを組み合わせる記憶搬送路ステージ。
extends "res://scripts/stage/StageBase.gd"

var patrol_boars: Array[Node] = [] # Aで作ったSMASH記憶をC地点へ運ぶBoar一覧。
var branch_lanterns: Array[Node] = [] # C地点を示す誘導灯一覧。
var execution_groups: Array[Node] = [] # C地点で再演SMASHにより崩れる床一覧。

# 共通初期化後、各Boarの巡回路をC地点まで開く。
func _ready() -> void:
	super._ready()
	patrol_boars = _collect_existing_nodes(["BoarTop", "BoarMiddle", "BoarBottom"])
	branch_lanterns = _collect_existing_nodes(["GuidanceLantern_TopC", "GuidanceLantern_MiddleC", "GuidanceLantern_BottomC"])
	execution_groups = _collect_existing_nodes([
		"EditableGeometry/ActionBreakGroups/ActionBreakGroup_TopDrop",
		"EditableGeometry/ActionBreakGroups/ActionBreakGroup_MiddleDrop",
		"EditableGeometry/ActionBreakGroups/ActionBreakGroup_BottomDrop",
	])
	_set_execution_route_visible(true)
	for boar in patrol_boars:
		if boar.has_method("open_patrol_branch"):
			boar.open_patrol_branch()
	for group in execution_groups:
		if group.has_signal("broken"):
			group.broken.connect(func(_enemy: Node, _record: Resource):
				_resolve_execution_group(group)
				shake_camera(7.0, 0.12)
			)

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.052, 0.06, 0.082)
	background.size = Vector2(5200, 2200)
	background.position = Vector2(-1500, -760)
	background.z_index = -20
	add_child(background)

# 指定したNodePathのうち存在するものだけ集める。
func _collect_existing_nodes(paths: Array[String]) -> Array[Node]:
	var nodes: Array[Node] = []
	for path in paths:
		var node := get_node_or_null(path)
		if node != null:
			nodes.append(node)
	return nodes

# 処刑地点として使うCルートの視認性を切り替える。
func _set_execution_route_visible(open: bool) -> void:
	var lantern_color := Color(1.0, 1.0, 1.0, 1.0) if open else Color(0.45, 0.55, 0.70, 0.45)
	var floor_color := Color(1.0, 0.92, 0.70, 1.0) if open else Color(0.62, 0.62, 0.70, 0.72)
	for lantern in branch_lanterns:
		lantern.modulate = lantern_color
	for group in execution_groups:
		group.modulate = floor_color

# 落とし床に乗っている敵が物理挙動で残った場合も、全滅型ステージが詰まらないよう処理する。
func _resolve_execution_group(group: Node) -> void:
	var names: Array[StringName] = []
	match group.name:
		&"ActionBreakGroup_TopDrop":
			names = [&"BoarTop"]
		&"ActionBreakGroup_MiddleDrop":
			names = [&"BoarMiddle"]
		&"ActionBreakGroup_BottomDrop":
			names = [&"BoarBottom", &"SkullBottomVictimA", &"SkullBottomVictimB"]
	for enemy_name in names:
		var enemy := get_node_or_null(NodePath(String(enemy_name)))
		if enemy != null and enemy.has_method("die"):
			enemy.die()
