extends AnimatableBody2D


func _ready():
	$collision_shape_2d.disabled = false


func hit(dir):
	$animation_tree['parameters/StateMachine/conditions/' + dir] = true


func _process(delta):
	$animation_tree['parameters/StateMachine/conditions/hit_f'] = false
	$animation_tree['parameters/StateMachine/conditions/hit_b'] = false
