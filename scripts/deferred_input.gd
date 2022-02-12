
var action
var delay # ms
var time : int

# warning-ignore:shadowed_variable
# warning-ignore:shadowed_variable
func _init(action, delay = 200):
	self.action = action
	self.delay = delay


func is_just_pressed():

	if Input.is_action_just_pressed(action):
		time = Time.get_ticks_msec() + delay
		return true

	if time >= Time.get_ticks_msec():
		return true

	return false


func reset():
	time = 0
