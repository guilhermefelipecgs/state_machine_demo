extends Node

var actived : bool
var step : bool

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta):
	if actived:
		get_tree().paused = true

	if step:
		get_tree().paused = false
		step = false


func _input(event):
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_D:
			actived = true
		if event.keycode == KEY_C:
			step = true
		if event.keycode == KEY_S:
			actived = false
			step = true
