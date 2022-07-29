extends Node2D

@onready var player = $'../../player/'
@onready var animation_tree = $'../../player/animation_tree'
@onready var panel = $node_2d/center_container/panel
var State = preload("res://scenes/state.tscn")
var rect2
var last_state = 'Start'
var last_from = 'Start'
var last_sm = 'root'
var last_sm_from = 'root'


func _ready():
	if get_parent() is Window: set_process(false)
	panel.custom_minimum_size = Vector2(256, 256)
	if not game_manager.debug:
		hide()
		set_process(false)


func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo():
			if visible:
				hide()
				game_manager.debug = false
				set_process(false)
			else:
				show()
				game_manager.debug = true
				set_process(true)


func _process(delta):
	for i in panel.get_children():
		panel.remove_child(i)
		i.queue_free()
	
	var sm : AnimationNodeStateMachine = _get_node(player._get_current_playback(), animation_tree.tree_root)
	$label.text = 'Path: ' + player._get_current_playback().replace('parameters', 'Root')
	
	rect2 = null
	
	for i in sm.get_property_list():
		if i.get('class_name') == 'AnimationNode':
			var node_name = i.name.split('/')[1]
			
			if player._get_current_playback() == 'parameters/' and node_name == 'End': continue
			
			var state = State.instantiate()
			var type = 'current' if node_name == player._get_current_state() else 'normal'
			if node_name == 'Start':
				type = 'start'
			elif node_name == 'End':
				type = 'end'
			state.get_node(type).show()
			state.get_node(type).name = 'panel_container'
			for j in state.get_children():
				if not j.visible:
					state.remove_child(j)
					j.queue_free()
			state.get_node('panel_container/margin_container/label').text = node_name
			state.position = sm.get_node_position(node_name)
			state.name = node_name
			panel.add_child(state)
			
			if rect2 == null:
				rect2 = Rect2(state.position, state.get_node('panel_container').get_minimum_size())
			else:
				rect2 = rect2.merge(Rect2(state.position, state.get_node('panel_container').get_minimum_size()))
	
	panel.custom_minimum_size = rect2.size
	for i in panel.get_children():
		i.position -= rect2.position
	
	if last_sm != player._get_current_playback():
		last_sm_from = last_sm
		var arr = player._get_current_playback().split('/')
		last_sm = arr[arr.size() - 2]
	
	if last_state != player._get_current_state():
		last_from = last_state
		last_state = player._get_current_state()

	update()

func _draw():
	if rect2 == null:
		return

	var sm = _get_node(player._get_current_playback(), animation_tree.tree_root)
	
	var transitions = {}
	
	for idx in sm.get_transition_count():
		var from_name = str(sm.get_transition_from(idx)).split('/')[0].replace('..', 'Start')
		var to_name = str(sm.get_transition_to(idx)).split('/')[0].replace('..', 'End')
		
		transitions[from_name + to_name] = 0
	
	for idx in sm.get_transition_count():
		var from_name = str(sm.get_transition_from(idx)).split('/')[0].replace('..', 'Start')
		var to_name = str(sm.get_transition_to(idx)).split('/')[0].replace('..', 'End')
		
#		if not (from_name == 'idle' and to_name == 'sword_attack'): continue
		var margin = Vector2(75, 16)
		var label = panel.get_node(from_name + '/panel_container/margin_container/label')
		
		if not label: return
		
		var from_label_size = panel.get_node(from_name + '/panel_container/margin_container/label').custom_minimum_size
		var to_label_size = panel.get_node(to_name + '/panel_container/margin_container/label').custom_minimum_size
		
		var from_position = sm.get_node_position(from_name)
		var to_position = sm.get_node_position(to_name)
		var from = from_position - rect2.position + (from_label_size + margin) / 2
		var to = to_position - rect2.position + (to_label_size + margin) / 2
		
		last_from = last_sm_from if not sm.has_node(last_from) else last_from
		last_from = 'Start' if not sm.has_node(last_from) else last_from
		
		var color = Color.ORANGE if last_from == from_name and player._get_current_state() == to_name else Color.WHITE
		
		if transitions.has(to_name + from_name):
			if transitions[from_name + to_name] == 1: continue
			transitions[from_name + to_name] += 1
			
			if from_position.y == to_position.y:
				if from_position.x < to_position.x:
					draw_line(from + Vector2(14, -14), to + Vector2(14,-14), color, 2)
				else:
					draw_line(from + Vector2(-14, 14), to + Vector2(-14, 14), color, 2)
			elif from_position.y < to_position.y:
				draw_line(from + Vector2(14, 0), to + Vector2(14, 0), color, 2)
			else:
				draw_line(from + Vector2(-14, 0), to + Vector2(-14, 0), color, 2)
		else:
			draw_line(from, to, color, 2)


func _get_node(sm_path : String, node : AnimationNodeStateMachine) -> AnimationNodeStateMachine:
	if sm_path.begins_with('parameters'):
		var path_array = sm_path.replace('parameters/', '').rstrip('/').split('/')
	
		for i in path_array:
			if i:
				node = _get_node(i, node.get_node(i))

	return node
