extends Node


var INITIAL_POSITION = Vector2(400, 300)

var checkpoint = INITIAL_POSITION
var last_checkpoint = INITIAL_POSITION
var camera_limits
var debug = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
#	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _input(event):
	if event is InputEventKey:
		if event.alt_pressed and event.keycode == KEY_ENTER and event.pressed and not event.echo:
			OS.window_fullscreen = !OS.window_fullscreen

		if event.keycode == KEY_R and event.pressed and not event.echo:
			restart()

	if event.is_action("select") and event.is_pressed():
		restart()


func restart():
	last_checkpoint = checkpoint
	return get_tree().reload_current_scene()
