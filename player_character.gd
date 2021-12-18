#Author: Kevin Griggs
#Made for Godot version 3.4 in GDScript
#This script defines the movement of a 2D platformer character
#The character can walk, jump, and fall.
#The walking movement will slide up hills and subtract from other horizonatal velocity applied.
#The falling and jumping movement will slide down/up steep slopes, and excess horizontal velocity will be converted
#into forces that slide even on the floor.
#External forces will slide on floors and walls.

extends KinematicBody2D

var walk_acceleration = 1500 #The acceleration rate of the walking movement
var walk_deceleration = 1500 #The deceleration rate of the walking movement when on the floor
var max_walk_speed= 300 #The maximum walk speed
var walk_velocity = Vector2.ZERO #The velocity to be added by the walk movement
var air_deceleration = 1500 #the deceleration of the walk velocity while not on the ground

#All non walk, fall, or jump velocities. Also includes horizontal velocity created by falling and jumping
var ext_velocity = Vector2.ZERO
var ext_air_deceleration = Vector2.ZERO #The deceleration of external velocities in the air
var ext_deceleration = 2500 #The deceleration of external velocities on the ground

var grav_velocity = Vector2.ZERO #The current fall/jump velocity
var gravity_acceleration = Vector2(0, 15) #The acceleration due to gravity
var is_jumping = false #whether or not the character is jumping (only active on the first jump tick, used to break snap)
var sustain_jump = false #whether or not the jump is being sustained 
var jump_duration = 0 #the current duration of the jump
var max_jump_duration = 0.25 #the maximum duration of the jump
var jump_strength = 500 #the strength of the jump

var _walk_input_value = 0; #the value provided by the walk axis input

var max_floor_angle = 0.785398 #The maximium angle of the floor (currently 45 degrees)


func _ready():
	set_process(true)
	set_physics_process(true)

#Every tick, handles input gathering. Calculates jump sustain
func _process(delta):
	
	_walk_input_value = Input.get_axis("left", "right") #gets the walk input and binds it to an axis
	
	#if the player has hit a ceiling or floor or cancelled their jump, ends sustain
	if Input.is_action_just_released("jump") or is_on_floor() or is_on_ceiling():
		sustain_jump = false
	
	#if the player can jump and want to jump, begins jump and sustain
	if Input.is_action_pressed("jump") and is_on_floor():
		is_jumping = true
		sustain_jump = true
	else: #else ends jump
		is_jumping = false
	
	#if the player is sustaining, increases duration if below max, or cancels sustain if max is reached
	if sustain_jump:
		if jump_duration + delta < max_jump_duration:
			jump_duration += delta
		else:
			sustain_jump = false
			jump_duration = 0
	else: #if the player is not sustaining, resets timer
		jump_duration = 0

#every constant tick, handles core movement
func _physics_process(delta):
	
	ext_velocity = slide(ext_velocity, true, false)#moves along ext_velocity and sets ext_velocity to the slide result
		
	apply_grav_jump() #calculates gravity and jump velocities
	
	grav_slide(delta) #moves along gravity/jump vector

	calc_walk_velocity(delta) #calculates the walking velocity

	walk_slide(delta) #moves along walking vector
	
	decelerate(delta) #decelerates remaining velocity

#calculates gravity and jump velocities
func apply_grav_jump():
	#if jump was just performed, jumps
	if is_jumping:
		grav_velocity += Vector2(0, -jump_strength)
	
	#if not sustaining, applies gravity
	if !sustain_jump:
		grav_velocity += gravity_acceleration

#moves along gravity/jump vector
func grav_slide(delta):
	
	#prevent weirdness with grav sliding down while standing, despite stop on slope being true
	if(is_on_floor() and !is_jumping):
		grav_velocity.y = 0
	
	#moves along grav_velocity
	var _grav_result = slide(grav_velocity, !is_jumping, true)
	
	#whether or not the direction of grav_result's vertical component is opposite the ext_velocities vertical componeent
	var _opposes_ext = sign(_grav_result.y) != sign(ext_velocity.y) and ext_velocity != Vector2.ZERO
	
	#if grav_result.y opposes ext_velocity.y, and the character is not colliding with a wall,
	#neutralizes ext_velocity.y at expense of grav_result.y
	if _opposes_ext and !is_on_wall():
		if sign(ext_velocity.y + _grav_result.y) == sign(ext_velocity.y):
			ext_velocity.y += _grav_result.y
		else:
			grav_velocity.y = ext_velocity.y + _grav_result.y
			ext_velocity.y = 0
	#else if there is an x component to grav_result, adds grav_result to ext_velocity to be treats as external force
	#occurs on collision with a slope
	elif _grav_result.x != 0:
		ext_velocity += _grav_result 
		grav_velocity = Vector2.ZERO
	#if there was no slope collision and the ext_velocity and grav_result are not opposes, stores grav_result in grav_velocity
	else:
		grav_velocity = _grav_result

 #calculates the walking velocity
func calc_walk_velocity(delta):
	
	var _tick_acceleration = walk_acceleration * _walk_input_value * delta #the scales acceleration in the input direction
	var _signed_max_walk_speed = max_walk_speed * _walk_input_value #the max move speed in the input direction
	var _would_run_into_wall = false #holds a boolean used to prevent the character from attempting to climb steep slopes
	var _walk_acc = Vector2(_tick_acceleration, 0)#the scaled acceleration in vector form
	
	#prevents acceleration while moving into wall or ceiling
	if get_slide_count() > 0:
		_would_run_into_wall = (is_on_wall() or is_on_ceiling()) and sign(-get_slide_collision(get_slide_count()-1).normal.x) == sign((walk_velocity + _walk_acc).x)
	
	#if player wants to walk
	if _walk_input_value != 0:
		if !_would_run_into_wall: #if the character would not walk into wall or ceiling
			if (walk_velocity + _walk_acc).length() < max_walk_speed: #accelerates if not at max move speed
				walk_velocity += _walk_acc
			else: #continues at max move speed
				walk_velocity = walk_velocity.normalized() * max_walk_speed

#moves along walking vector
func walk_slide(delta):
	
	var _coll_result: KinematicCollision2D #a the results cast used to determine if the player would walk into a wall
	
	var _test_vector = walk_velocity #the cast vector
	
	if is_on_floor():
		_test_vector = walk_velocity.slide(get_floor_normal()) #slides the test vector along the floor
		
	_coll_result = move_and_collide((_test_vector + Vector2(0,-1)) * delta, true, true, true) #performs the cast

	var _would_hit_wall = false
	
	#if the cast resulted in a collision and the collider was a wall or ceiling sets _would_hit_wall to true
	if _coll_result:
		_would_hit_wall = _coll_result.get_angle() >= max_floor_angle or _coll_result.get_angle() <= -max_floor_angle
	
	#if the character would hit a wall or ceiling and they're are an the floor, 
	#prevents jitter by moving the chatacter to the collision point and stoping further movement
	if _would_hit_wall and is_on_floor():
		move_and_collide((_test_vector + Vector2(0,-1)) * delta)
		walk_velocity = Vector2.ZERO
	
	#moves along walk vector
	var _walk_result = slide(walk_velocity, true, true)
	
	#is true if the player's walk_result.x opposes the ext_velocities.x
	var _opposes_ext = sign(_walk_result.x) != sign(ext_velocity.x) and ext_velocity != Vector2.ZERO
	
	#if the player's walk_result.x opposes the ext_velocities.x and the player is not has not been stoped by a wall or ceiling
	#neutralizes ext_velocity's horizontal component (walk velocity decelerates ext_velocty but does not add to it)
	if _opposes_ext and !(is_on_wall() or _would_hit_wall):
		
		if sign(ext_velocity.x + _walk_result.x) == sign(ext_velocity.x):
			ext_velocity.x += _walk_result.x
		else:
			walk_velocity.x = ext_velocity.x + _walk_result.x
			ext_velocity.x = 0
			
		if sign(ext_velocity.y + _walk_result.y) == sign(ext_velocity.y):
			ext_velocity.y += _walk_result.y
		else:
			ext_velocity.y = 0
	#if is on wall or ceiling and not oppposing ext_velocity, removes y component (prevents wall climbing)
	elif is_on_wall() or _would_hit_wall:
		walk_velocity.x = _walk_result.x 
	else: #else if not on wall or opposing ext_velocity, converts vector to be completely horizontal
		walk_velocity.x = _walk_result.length() * sign(_walk_result.x)
	
	#if is on floor and a wall, stop
	if is_on_floor() and is_on_wall():
		walk_velocity = Vector2.ZERO

#an extension to the normal slide function that eliminates the magnitude loss
func slide(var vel: Vector2, var snap = true, var stop_on_slop = true):
	
	#the snap vector
	var _snapVel = Vector2(0, 10)
	
	#disables snap
	if !snap:
		_snapVel = Vector2.ZERO
	
	#the first slide pass
	var _slide_result = move_and_slide_with_snap(vel, _snapVel, Vector2(0,-1), stop_on_slop, 4, max_floor_angle)
	
	var _slide_result_2 = _slide_result
	
	#if there was a slide, does a second slide along the remaining distance
	if(_slide_result and _slide_result != Vector2.ZERO):
		var _velocity_difference = vel.length() - _slide_result.length()
		if _velocity_difference > 0:
			_slide_result_2 = move_and_slide_with_snap(_slide_result.normalized() * _velocity_difference, _snapVel, Vector2(0,-1), stop_on_slop, 4, max_floor_angle)
			return _slide_result_2 + _slide_result_2.normalized() * _slide_result.length() #returns the second slide + the magnitude of the first
		else:
			return _slide_result #returns the first slide if there was no magnitude loss
	else:
		return Vector2.ZERO #returns 0 if there was no collision

#decelerates the velocities
func decelerate(delta):
	
	#if is on a floor or cieling, decelerates the ext_velocity
	if(is_on_floor() or is_on_ceiling()):
		var _ext_decelerated = ext_velocity - ext_deceleration * delta * ext_velocity.normalized()
		if _ext_decelerated.length() > 0 and ext_velocity.normalized().is_equal_approx(_ext_decelerated.normalized()):
			ext_velocity -= ext_deceleration  * delta * ext_velocity.normalized()
		else:
			ext_velocity = Vector2.ZERO
	#else if is on a wall and there is and ext_air_deceleration, decelerates the ext_velocity
	elif !is_on_wall() and ext_air_deceleration != Vector2.ZERO:
		var _ext_decelerated = ext_velocity - ext_air_deceleration * delta * ext_velocity.normalized()
		if _ext_decelerated.length() > 0 and ext_velocity.normalized().is_equal_approx(_ext_decelerated.normalized()):
			ext_velocity -= ext_deceleration  * delta * ext_velocity.normalized()
		else:
			ext_velocity = Vector2.ZERO
	
	#if there is no walk input of the character is on a wall, decelerates the walk velocity
	if _walk_input_value == 0 or is_on_wall():
		#if the player is on the floor decelerates according to floor deceleration
		if(is_on_floor()):
			var _walk_tick_deceleration = walk_deceleration * delta * walk_velocity.normalized()
			if (walk_velocity - _walk_tick_deceleration).normalized().is_equal_approx(walk_velocity.normalized()):
				walk_velocity -= _walk_tick_deceleration
			else:
				walk_velocity = Vector2.ZERO
		else: #else decelerates accorting to air deceleration
			var _air_tick_deceleration = air_deceleration * delta * walk_velocity.normalized()
			if (walk_velocity - _air_tick_deceleration).normalized().is_equal_approx(walk_velocity.normalized()):
				walk_velocity -= _air_tick_deceleration
			else:
				walk_velocity = Vector2.ZERO
			
	
	


