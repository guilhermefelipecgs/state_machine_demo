extends CharacterBody2D

var dir : Vector2

func _physics_process(delta):
	if visible:
		var collide = move_and_collide(dir * 20)

		if collide:
			hide()
			if collide.get_collider().is_in_group('target'):
				collide.get_collider().hit('hit_f' if collide.get_normal().x < 0 else 'hit_b')
				queue_free()

