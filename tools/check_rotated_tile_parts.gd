# 2026-06-21: 回転タイルの見た目、衝突、破壊センサー、方向判定を確認する。
extends SceneTree

const TEST_POSITION := Vector2(120.0, 84.0)
const TEST_SIZE := Vector2(160.0, 32.0)
const TEST_ROTATION := deg_to_rad(27.0)

# テスト本体を次フレームから実行する。
func _init() -> void:
	call_deferred("_run")

# 通常タイルと破壊タイルへ同じ回転が反映されることを検証する。
func _run() -> void:
	var normal_group := _create_normal_group()
	root.add_child(normal_group)
	var break_group := _create_break_group()
	root.add_child(break_group)
	await process_frame
	await physics_frame

	_check_normal_group(normal_group)
	_check_break_group(break_group)

	print("ROTATED_TILE_PARTS_CHECK_OK")
	root.remove_child(normal_group)
	normal_group.queue_free()
	root.remove_child(break_group)
	break_group.queue_free()
	await process_frame
	quit(0)

# 回転TileRectPartを1つ持つ通常タイルグループを作る。
func _create_normal_group() -> EditableTileGroup:
	var group := EditableTileGroup.new()
	group.name = "RotatedNormalGroup"
	group.add_child(_create_part())
	return group

# 回転TileRectPartを1つ持つ破壊タイルグループを作る。
func _create_break_group() -> ActionBreakGroup:
	var group := ActionBreakGroup.new()
	group.name = "RotatedBreakGroup"
	group.rotation = deg_to_rad(11.0)
	group.add_child(_create_part())
	return group

# 共通の回転TileRectPartを作る。
func _create_part() -> TileRectPart:
	var part := TileRectPart.new()
	part.name = "Slope"
	part.rect_name = "Slope"
	part.position = TEST_POSITION
	part.size = TEST_SIZE
	part.rotation = TEST_ROTATION
	return part

# 通常グループの生成済み見た目と衝突を検証する。
func _check_normal_group(group: EditableTileGroup) -> void:
	assert(group.get_tile_rects().size() == 1)
	assert(group.get_tile_parts().size() == 1)
	var part: Dictionary = group.get_tile_parts()[0]
	assert(is_equal_approx(float(part.rotation), TEST_ROTATION))

	var collision_shape := group.get_node("Collision").get_child(0) as CollisionShape2D
	assert(collision_shape != null)
	assert(collision_shape.shape.size == TEST_SIZE)
	assert(collision_shape.position.is_equal_approx(_expected_center(TEST_POSITION, TEST_SIZE, TEST_ROTATION)))
	assert(is_equal_approx(collision_shape.rotation, TEST_ROTATION))

	var visual_part := group.get_node("GeneratedTiles").get_child(0) as Node2D
	assert(visual_part != null)
	assert(visual_part.position == TEST_POSITION)
	assert(is_equal_approx(visual_part.rotation, TEST_ROTATION))

# 破壊グループの衝突、拡張センサー、回転方向判定を検証する。
func _check_break_group(group: ActionBreakGroup) -> void:
	var collision_shape := group.get_node("Collision").get_child(0) as CollisionShape2D
	assert(collision_shape != null)
	assert(collision_shape.position.is_equal_approx(_expected_center(TEST_POSITION, TEST_SIZE, TEST_ROTATION)))
	assert(is_equal_approx(collision_shape.rotation, TEST_ROTATION))

	var sensor_shape := group.get_node("BreakSensor").get_child(0) as CollisionShape2D
	var expected_probe_size := TEST_SIZE + Vector2.ONE * group.action_probe_margin * 2.0
	assert(sensor_shape != null)
	assert(sensor_shape.shape.size == expected_probe_size)
	assert(sensor_shape.position.is_equal_approx(_expected_center(TEST_POSITION, TEST_SIZE, TEST_ROTATION)))
	assert(is_equal_approx(sensor_shape.rotation, TEST_ROTATION))

	var local_test_point := TEST_POSITION + Vector2(-80.0, TEST_SIZE.y * 0.5).rotated(TEST_ROTATION)
	var global_test_point := group.to_global(local_test_point)
	var global_direction := Vector2.RIGHT.rotated(TEST_ROTATION + group.rotation)
	assert(group._best_direction_dot_to_group(global_test_point, global_direction) > 0.99)

# 左上基準の回転矩形から中央座標を求める。
func _expected_center(position: Vector2, size: Vector2, angle: float) -> Vector2:
	return position + (size * 0.5).rotated(angle)
