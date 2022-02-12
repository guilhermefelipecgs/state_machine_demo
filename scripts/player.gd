extends CharacterBody2D

var left_frames = preload('res://textures/player/left.tres')
var right_frames = preload('res://textures/player/right.tres')

var DeferredInput = preload('res://scripts/deferred_input.gd')

var Bullet = preload('res://scenes/bullet.tscn')

const GRAVITY : = 30.0
const ACCELERATION : = 25.0
const SPEED_ROLL : = 2200.0
const MAX_SPEED_RUN : = 300.0
const MAX_SPEED_WALK : = 130.0
const MAX_SPEED_WALK_CROUCHED : = 110.0
const MAX_SPEED_JUMP_SHORT : = 250.0
const JUMP_SPEED : = 300.0
const FRICTION = 6.0

@onready var old_position : Vector2 = position
@onready var old_state = _get_current_state()

var playbacks : Array = []
@onready var last_state = _get_current_state()
var rollback : = false
var rollbacking : = false
var current_time_one_shot : bool
var old_time : float

# Controls
var lv : Vector2
var dir : = Vector2.RIGHT
var is_on_floor : bool
var is_on_air : bool
var stop_inputs : bool
var die : bool
var walking : bool
var running : bool
var jumping : bool
var rolling : bool

# Actions
var up : bool
var left : bool
var right : bool
var jump : bool
var crouch : bool
var draw_weapon : bool
var turn : bool
var run : bool
var walking_crouched : bool
var land : bool
var shoot : bool

# Deffered actions
@onready var shoot_action = DeferredInput.new('shoot', 150)
@onready var jump_action = DeferredInput.new('jump', 300)

var sync_old_position : Vector2


func _enter_tree():
	if game_manager.camera_limits:
		$camera_2d.limit_left = game_manager.camera_limits.position.x
		$camera_2d.limit_top = game_manager.camera_limits.position.y
		$camera_2d.limit_right = game_manager.camera_limits.size.x
		$camera_2d.limit_bottom = game_manager.camera_limits.size.y
	
	position = game_manager.last_checkpoint


func _ready():
	_init_playbacks()


func _init_playbacks():
	for item in $animation_tree.get_property_list():
		if item.name.match('*playback'):
			var path = item.name.replace('playback', '')
			playbacks.append(path)


func _physics_process(delta):
	_get_input()
	_move(delta)
	_update_state_machine()

	$animation_tree.advance(delta)

	# sync functions
	_climb()
	_jump_short()
	_jump_climb()
	# end sync functions

	$label.text = _get_current_state()
	$label_last.text = last_state


#"""
#██╗███╗   ██╗██████╗ ██╗   ██╗████████╗███████╗
#██║████╗  ██║██╔══██╗██║   ██║╚══██╔══╝██╔════╝
#██║██╔██╗ ██║██████╔╝██║   ██║   ██║   ███████╗
#██║██║╚██╗██║██╔═══╝ ██║   ██║   ██║   ╚════██║
#██║██║ ╚████║██║     ╚██████╔╝   ██║   ███████║
#╚═╝╚═╝  ╚═══╝╚═╝      ╚═════╝    ╚═╝   ╚══════╝
#"""
func _get_input():
	left = false
	right = false
	crouch = false
	draw_weapon = false
	run = false
#	jump = false
	up = false

	if stop_inputs:
		return

	if Input.is_action_pressed('up'):
		up = true

	if Input.is_action_pressed('right'):
		right = true

	if Input.is_action_pressed('left'):
		left = true

	if Input.is_action_pressed('crouch'):
		crouch = true

	if Input.is_action_pressed('draw_weapon'):
		draw_weapon = true

	if Input.is_action_pressed('run'):
		run = true

#	if Input.is_action_pressed('jump'):
#		jump = true

	shoot = shoot_action.is_just_pressed()
	jump = jump_action.is_just_pressed()


#func stop_inputs():
#	stop_inputs = true


func resume_inputs():
	stop_inputs = false


#"""
#███╗   ███╗ ██████╗ ██╗   ██╗███████╗
#████╗ ████║██╔═══██╗██║   ██║██╔════╝
#██╔████╔██║██║   ██║██║   ██║█████╗
#██║╚██╔╝██║██║   ██║╚██╗ ██╔╝██╔══╝
#██║ ╚═╝ ██║╚██████╔╝ ╚████╔╝ ███████╗
#╚═╝     ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝
#"""
func _move(delta):
	old_position = position

	if _can_turn():
		if dir == Vector2.RIGHT:
			dir = Vector2.LEFT
			$mirror.scale.x = -1
		else:
			dir = Vector2.RIGHT
			$mirror.scale.x = 1

	# move x
	running = false
	walking = false
	walking_crouched = false
	jumping = false
	rolling = false
	land = false

	if _can_run():
		running = true
		lv += dir * ACCELERATION
	elif _can_walk():
		walking = true
		lv += dir * ACCELERATION
	elif _can_walk_crouched():
		walking_crouched = true
		lv += dir * ACCELERATION
	elif _can_jump():
		jumping = true
		lv.y = 0
		lv += dir * ACCELERATION
	elif _can_roll():
		rolling = true
		lv += dir * ACCELERATION

	# max speed x
	if running and abs(lv.x) > MAX_SPEED_RUN:
		lv.x = MAX_SPEED_RUN * sign(lv.x)
	elif walking and abs(lv.x) > MAX_SPEED_WALK:
		lv.x = MAX_SPEED_WALK * sign(lv.x)
	elif walking_crouched and abs(lv.x) > MAX_SPEED_WALK_CROUCHED:
		lv.x = MAX_SPEED_WALK_CROUCHED * sign(lv.x)
	elif jumping and abs(lv.x) > MAX_SPEED_JUMP_SHORT:
		lv.x = MAX_SPEED_JUMP_SHORT * sign(lv.x)

		if _is_state('jump_long'):
			lv.x = MAX_SPEED_JUMP_SHORT * 1.5 * sign(lv.x)
	elif rolling and abs(lv.x) > MAX_SPEED_RUN:
		lv.x = MAX_SPEED_WALK * sign(lv.x)

	# apply gravity
	if not jumping:
		lv.y += GRAVITY

		if _is_state('hang') or _is_state('climb') or _is_state('jump_short_before'):
			lv.y = 0

	var motion = lv * delta
	var collision = move_and_collide(motion, false)

	if collision and collision.get_remainder() != Vector2():
		var angle = rad2deg(acos(collision.get_normal().dot(Vector2.UP)))

		if angle < 35:
			is_on_floor = true

			if is_on_air:
				lv.y = GRAVITY
				land = true
		else:
			is_on_floor = false
			if running or walking or rolling:
				lv -= dir * ACCELERATION # nullify move x

		if is_on_floor:
			is_on_air = false

			# nullify gravity
			lv.y -= GRAVITY

			# max speed normalized (for slopes)
			if running and lv.length() > MAX_SPEED_RUN:
				lv = lv.normalized() * MAX_SPEED_RUN
			elif walking and lv.length() > MAX_SPEED_WALK:
				lv = lv.normalized() * MAX_SPEED_WALK
			elif walking_crouched and lv.length() > MAX_SPEED_WALK_CROUCHED:
				lv = lv.normalized() * MAX_SPEED_WALK_CROUCHED
			elif rolling and lv.length() > MAX_SPEED_RUN:
				lv = lv.normalized() * MAX_SPEED_RUN

			# friction
			if not (running or walking or walking_crouched or jumping or rolling):
				lv -= lv / FRICTION # apply friction only when not moving

		if is_on_floor and collision.get_collider_velocity() != Vector2(): # moving platform
			motion = (lv + collision.get_collider_velocity()) * delta

			if collision.get_collider_velocity().y > 0: # if going down
				motion.y = 0
				lv.y = collision.get_collider_velocity().y
		else:
			lv = lv.slide(collision.get_normal())
			motion = lv * delta

		collision = move_and_collide(motion)
	else:
		is_on_floor = false
		is_on_air = true

	# Revert movement
	if (old_position - position).length() < 0.1:
		position = old_position
		lv = Vector2()

	# Die for fall
	if lv.y > 1000:
		die = true


func _can_turn():
	if _is_state('turn_idle') or \
		_is_state('turn_run_R') or _is_state('turn_run_L') or \
		_is_state('turn_crouch') or \
		_is_state('turn_c') or \
		_is_state('turn_aim_c') or \
		_is_state('turn_aim_f') or \
		_state_contains('turn_walk') or \
		_is_state('turn_run_2_idle_L_after') or _is_state('turn_run_2_idle_R_after'):

		return not _is_old_state(_get_current_state())
	return false


func _can_run():
	if left and right:
		return false

	if _is_state('idle_2_run') or _is_state('turn_run_R') or _is_state('turn_run_L') or _state_contains('run_step'):
		return true

	if ((dir.x < 0 and left) or (dir.x > 0 and right)) and run:
		return (_is_old_state('idle') and _is_state('idle')) or (_is_old_state(_get_current_state()) and _is_state_after())

	return false


func _can_walk():
	if left and right:
		return false

	if _is_state('idle_2_walk') or _state_contains('walk_step'):
		return true

	if ((dir.x < 0 and left) or (dir.x > 0 and right)):
		return (_is_old_state('idle') and _is_state('idle')) or \
			(_is_old_state(_get_current_state()) and _is_state_after())

	return false


func _can_walk_crouched():
	if left and right:
		return false

	if _is_state('crouch_2_walk_crouched') or _is_state("walk_crouched"):
		return true

	if ((dir.x < 0 and left) or (dir.x > 0 and right)):
		return (_is_old_state('crouch') and _is_state('crouch')) or \
			(_is_old_state(_get_current_state()) and _is_state_after())

	return false


func _can_jump():
	return (_is_state('jump_short') and _get_current_time() < 0.36) \
		or (_is_state('jump_long') and _get_current_time() < 0.52)


func _can_roll():
	return _is_state('roll')


#"""
#███████╗████████╗ █████╗ ████████╗███████╗
#██╔════╝╚══██╔══╝██╔══██╗╚══██╔══╝██╔════╝
#███████╗   ██║   ███████║   ██║   █████╗
#╚════██║   ██║   ██╔══██║   ██║   ██╔══╝
#███████║   ██║   ██║  ██║   ██║   ███████╗
#╚══════╝   ╚═╝   ╚═╝  ╚═╝   ╚═╝   ╚══════╝
#
#███╗   ███╗ █████╗  ██████╗██╗  ██╗██╗███╗   ██╗███████╗
#████╗ ████║██╔══██╗██╔════╝██║  ██║██║████╗  ██║██╔════╝
#██╔████╔██║███████║██║     ███████║██║██╔██╗ ██║█████╗
#██║╚██╔╝██║██╔══██║██║     ██╔══██║██║██║╚██╗██║██╔══╝
#██║ ╚═╝ ██║██║  ██║╚██████╗██║  ██║██║██║ ╚████║███████╗
#╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝
#"""
func _update_state_machine():
	var stop = not (left or right) or (left and right) or draw_weapon or shoot or $mirror/ray_cast_wall.is_colliding()

	# main
	_set_param('idle', is_on_floor and stop or not run)

	# main/run
	_set_param('run', (is_on_floor or $mirror/ray_cast_fix_long_jump_2_run.is_colliding()) and run and not stop)

	# main/walk
	_set_param('walk', is_on_floor and walking and not stop or not stop)
	_set_param('walk_2_idle', is_on_floor and stop or turn or crouch)
	_set_param('walk_2_run', is_on_floor and walking and run, true)

	# main/crouch
	_set_param('crouch', is_on_floor and crouch)
	_set_param('crouch_2_idle', is_on_floor and not crouch and not $mirror/ray_cast_up.is_colliding())
	_set_param('walk_crouched', is_on_floor and walking_crouched and not stop)
	_set_param('walk_crouched_2_crouch', is_on_floor and stop or (not crouch and not $mirror/ray_cast_up.is_colliding()))

	# main/aim
	_set_param('draw_weapon', is_on_floor and draw_weapon, true)
	_set_param('save_weapon', is_on_floor and not draw_weapon)

	# main/jump
	_set_param('jump', is_on_floor and jump, true)
	_set_param('jump_climb', is_on_floor and jump and $mirror/ray_cast_ledge.is_colliding())
	_set_param('jump_short', is_on_floor and jump and (left or right) and not $mirror/ray_cast_jump.is_colliding(), true)

	_set_param('shoot', is_on_floor and shoot)

	# main/turn
	turn = false
	if (left and dir.x > 0) or (right and dir.x < 0):
		if left and right:
			turn = false
		elif _is_state('idle') or \
			(_state_contains('run_step') and _is_state_before()) or \
			_state_contains('walk_step') or \
			_state_contains('run_2_idle') or _is_state('idle_2_run') or _state_contains('walk_2_idle') or _is_state('idle_2_walk') or \
			_is_state('crouch') or \
			_is_state('aim_c') or \
			_is_state('aim_f') or \
			_is_state_after():
			turn = true
	if old_state.begins_with('turn') and not _get_current_state().begins_with('turn'):
		_turn()
	
	_set_param('turn', turn, true)
	_set_param('turn_run', is_on_floor and run and turn, true)


	# break '_after'
	_set_param('after', running or draw_weapon or crouch or turn or walking or jump or shoot, true)

	_set_param('fall', is_on_air and lv.y > 100, true)
	_set_param('land', land, true)
	_set_param('land_roll', land and run, true)

	# die
	_set_param('die', die, true)


	if old_state != _get_current_state():
		last_state = old_state
	old_state = _get_current_state()

#	if _is_state('crouch_2_idle'):
#		_set_current_time($animation_player.get_animation(_get_current_state()).length - old_time)
#	else:
#		current_time_one_shot = false
#	old_time = _get_current_time()


func _set_param(condition, value, use_all_playbacks = false):
	# set condition for all state machines to false
	for playback in playbacks:
		var param = playback + 'conditions/' + condition
		if $animation_tree.get(param) != null:
			$animation_tree[param] = false

	if use_all_playbacks:
		# set all state machines
		for playback in playbacks:
			var param = playback + 'conditions/' + condition
			if $animation_tree.get(param) != null:
				$animation_tree[param] = value
	else:
		# set only current sub state machine
		var param = _get_current_playback() + 'conditions/' + condition
		if $animation_tree.get(param) != null:
			$animation_tree[param] = value


func _get_current_playback() -> String:
	var sm : AnimationNodeStateMachine = $animation_tree.tree_root
	var current_node = str($animation_tree['parameters/playback'].get_current_node())
	var current_path = '/'

	while sm.has_node(current_node):
		if sm.get_node(current_node) is AnimationNodeStateMachine:
			sm = sm.get_node(current_node)
			current_path += current_node + '/'

			if $animation_tree.get('parameters' + current_path + 'playback'):
				current_node = str($animation_tree.get('parameters' + current_path + 'playback').get_current_node())
		else:
			break

	return 'parameters' + current_path


func _get_current_state() -> String:
	var sm : AnimationNodeStateMachine = $animation_tree.tree_root
	var current_node = str($animation_tree['parameters/playback'].get_current_node())
	var current_path = '/'

	while sm.has_node(current_node):
		if sm.get_node(current_node) is AnimationNodeStateMachine:
			sm = sm.get_node(current_node)
			current_path += current_node + '/'

			if $animation_tree.get('parameters' + current_path + 'playback'):
				current_node = str($animation_tree.get('parameters' + current_path + 'playback').get_current_node())
		else:
			break

	if $animation_tree.get('parameters' + current_path + 'playback'):
		current_node = str($animation_tree.get('parameters' + current_path + 'playback').get_current_node())

	current_node = current_node.split('/')
	current_node = current_node[current_node.size() - 1]

	if current_node == 'End':
		current_node = old_state

	return current_node


func _get_current_time() -> float:
	var sm : AnimationNodeStateMachine = $animation_tree.tree_root
	var current_node = str($animation_tree['parameters/playback'].get_current_node())
	var path = current_node

	while sm.has_node(current_node):
		if sm.get_node(current_node) is AnimationNodeStateMachine:
			sm = sm.get_node(current_node)

			if $animation_tree.get('parameters/' + path + '/playback'):
				current_node = str($animation_tree.get('parameters/' + path + '/playback').get_current_node())
				path += '/' + current_node
		else:
			break


	if $animation_tree.get('parameters/' + path + '/playback'):
		current_node += '/' + $animation_tree.get('parameters/' + path + '/playback').get_current_node()

	if $animation_tree.get('parameters/' + path + '/time'):
		return $animation_tree['parameters/' + path + '/time']

	return 0.0


func _set_current_time(time):
	if not current_time_one_shot:
		current_time_one_shot = true
		var sm : AnimationNodeStateMachine = $animation_tree.tree_root
		var current_node = str($animation_tree['parameters/playback'].get_current_node())

		while sm.has_node(current_node):
			if sm.get_node(current_node) is AnimationNodeStateMachine:
				sm = sm.get_node(current_node)

				if $animation_tree.get('parameters/' + current_node + '/playback'):
					current_node += '/' + $animation_tree.get('parameters/' + current_node + '/playback').get_current_node()
			else:
				break

		if $animation_tree.get('parameters/' + current_node + '/playback'):
			current_node += '/' + $animation_tree.get('parameters/' + current_node + '/playback').get_current_node()

		$animation_tree['parameters/' + current_node + '/time'] = time


func _is_state_after():
	return _get_current_state().ends_with('after')


func _is_state_before():
	return _get_current_state().ends_with('before')


func _is_state(state):
	return _get_current_state() == state


func _state_contains(word):
	return _get_current_state().match('*' + word + '*')


func _is_old_state(state):
	return old_state == state


#"""
# █████╗  ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
#██╔══██╗██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
#███████║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
#██╔══██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
#██║  ██║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
#╚═╝  ╚═╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
#"""
func _jump_short():
	if (not _is_state('jump_short_before') and not _is_state('jump_short_land')) or $mirror/ray_cast_jump.is_colliding():
		return

	var delta = 0.05 if _is_state('jump_short_before') else 0.05

	if _get_current_time() < delta:
		sync_old_position = $mirror/position_2d.global_position
	else:
		position += sync_old_position - $mirror/position_2d.global_position


func _climb():
	if _is_state('hang'):
		sync_old_position = $mirror/position_2d.global_position
	if _is_state('climb'):
		position += sync_old_position - $mirror/position_2d.global_position


func _jump_climb():
	if not _is_state('jump_climb'):
		return

	if _get_current_time() < 0.02:
		sync_old_position = $mirror/position_2d.global_position
		sync_old_position.x += $mirror/ray_cast_ledge.get_collider().global_position.x - sync_old_position.x
	else:
		position.x += sync_old_position.x - $mirror/position_2d.global_position.x


func _turn():
	if dir == Vector2.LEFT:
		$animated_sprite.frames = left_frames
	else:
		$animated_sprite.frames = right_frames


func _jump():
	lv.y -= JUMP_SPEED
	jump = false


func _shoot():
	var bullet = Bullet.instantiate()
	bullet.dir = dir
	bullet.top_level = true
	bullet.position = $mirror/bullet_spawn.global_position
	add_child(bullet)

func _restart():
	game_manager.restart()
