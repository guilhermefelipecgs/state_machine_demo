extends Area2D

signal refresh


func _draw():
	if Engine.is_editor_hint():
		var x = $collision_shape_2d.shape.extents.x
		var y = $collision_shape_2d.shape.extents.y
		var color = Color(randf(), randf(), randf(), .3)

		draw_rect(Rect2(Vector2(0, 0), Vector2(x, y) * 2), color)


func _on_zone_body_entered(body):
	_update_camera(body)


func _on_zone_body_exited(body):
	for i in get_tree().get_nodes_in_group('zones'):
		i.emit_signal("refresh", body)


func _on_zone_refresh(body):
	_update_camera(body)


func _update_camera(body):
	var rect2 = Rect2(global_position, $collision_shape_2d.shape.extents * 2)
	
	if rect2.grow(1).has_point(body.get_node('collision_shape_2d').global_position):
		var camera : Camera2D = body.get_node("camera_2d")
		var ext_x = $collision_shape_2d.shape.extents.x
		var ext_y = $collision_shape_2d.shape.extents.y
		
		camera.limit_left = int(position.x)
		camera.limit_top = int(position.y)
		camera.limit_right = position.x + ext_x * 2
		camera.limit_bottom = position.y + ext_y * 2
		
		if has_node('position_2d'):
			game_manager.checkpoint = $position_2d.global_position
			game_manager.camera_limits = Rect2(camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)
