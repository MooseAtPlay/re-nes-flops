extends BombCharacter

@onready var bomb_checker: Area2D = $BombChecker

func _ready() -> void:
	# Connect to animation finished signal
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Connect bomb checker signals
	if bomb_checker:
		print("DEBUG: BombChecker collision_layer: ", bomb_checker.collision_layer)
		print("DEBUG: BombChecker collision_mask: ", bomb_checker.collision_mask)
		print("DEBUG: BombChecker monitoring: ", bomb_checker.monitoring)
		print("DEBUG: BombChecker monitorable: ", bomb_checker.monitorable)
		# Fix collision settings to detect bombs on layers 1 and 2
		bomb_checker.collision_layer = 0  # Keep checker on no layer (Area2D)
		bomb_checker.collision_mask = 3   # Detect layer 1 (armed bombs) + layer 2 (unarmed bombs)
		print("DEBUG: Updated BombChecker collision_layer to: ", bomb_checker.collision_layer)
		print("DEBUG: Updated BombChecker collision_mask to: ", bomb_checker.collision_mask)
		bomb_checker.area_entered.connect(_on_bomb_checker_area_entered)
		bomb_checker.area_exited.connect(_on_bomb_checker_area_exited)
		bomb_checker.body_entered.connect(_on_bomb_checker_body_entered)
		bomb_checker.body_exited.connect(_on_bomb_checker_body_exited)
	else:
		print("ERROR: Bomb checker not found")

const MAX_SPEED = 300.0
const ACCELERATION = 800.0
const FRICTION = 1000.0
const JUMP_VELOCITY = -400.0

# Animation state tracking
var is_bending: bool = false

# Bomb pickup tracking
var nearby_bombs: Array[Node2D] = []

# Semisolid platform state tracking
var was_on_semisolid: bool = false

func _physics_process(delta: float) -> void:
	# Handle semisolid platform collision FIRST
	handle_semisolid_collision()
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump (disabled when bending)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_bending:
		velocity.y = JUMP_VELOCITY
	
	# Handle bomb throwing
	handle_bomb_input()
	
	# Handle bending
	handle_bend_input()

	# Get the input direction and handle movement (disabled when bending)
	if not is_bending:
		var direction := Input.get_axis("move_left", "move_right")
		if direction:
			# Apply acceleration in the direction of input (works in air and on ground)
			velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
			# Flip sprite when moving left and update direction tracking
			animated_sprite.flip_h = direction < 0
			facing_left = direction < 0
		else:
			# Apply friction when no input (only on ground)
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	
	# Handle animations based on bomb state and ground state
	if is_throwing_bomb:
		# Don't change animation while throwing - let it finish
		pass
	elif is_holding_bomb:
		# Play hold_bomb animation when holding a bomb
		if animated_sprite.animation != "hold_bomb":
			animated_sprite.play("hold_bomb")
	elif is_bending:
		# Play bend animation when bending
		if animated_sprite.animation != "bend":
			animated_sprite.play("bend")
	elif not is_on_floor():
		# Play jump animation when in air
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
	else:
		# Ground-based animations
		var direction := Input.get_axis("move_left", "move_right")
		if direction:
			# Play run animation when moving on ground
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			# Play skid animation when slowing down but still moving
			if abs(velocity.x) > 10:  # Small threshold to avoid jittering
				if animated_sprite.animation != "skid":
					animated_sprite.play("skid")
			else:
				# Play idle animation when stopped or nearly stopped
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")

	move_and_slide()
	
	# Update semisolid platform state tracking
	was_on_semisolid = false
	if is_on_floor():
		var bodies = get_slide_collision_count()
		for i in range(bodies):
			var collision = get_slide_collision(i)
			var body = collision.get_collider()
			if body and body.is_in_group("semisolid"):
				was_on_semisolid = true
	
	# Update held bomb position if we have one
	if held_bomb and bomb_marker:
		# Use marker position, adjusting for direction
		var marker_pos = bomb_marker.global_position
		if facing_left:
			# When facing left, add 2x the marker's local x position
			held_bomb.position = marker_pos + Vector2(2 * abs(bomb_marker.position.x), 0)
		else:
			# When facing right, use marker position directly
			held_bomb.position = marker_pos

func handle_bomb_input() -> void:
	"""Handle bomb throwing input"""
	# Don't allow new bomb creation while throwing
	if is_throwing_bomb:
		return
	
	# Check if hold_bomb action is pressed (start holding)
	if Input.is_action_just_pressed("hold_bomb") and held_bomb == null:
		create_held_bomb()
	
	# Check if hold_bomb action is released (throw bomb)
	elif Input.is_action_just_released("hold_bomb") and held_bomb != null:
		throw_bomb()

func create_held_bomb() -> void:
	"""Create a new bomb and hold it"""
	# Check if we have bombs available
	var game_state = get_node("/root/AdvRockyBullwinkle")
	if not game_state or not game_state.use_bomb():
		return  # No bombs available
	
	# Load the bomb scene
	var bomb_scene = preload("res://adv_rocky_bullwinkle/bomb.tscn")
	var new_bomb = bomb_scene.instantiate()
	
	# Add bomb to the Bombs node
	var bombs_node = game_state.get_node("Bombs")
	if bombs_node:
		bombs_node.add_child(new_bomb)
	else:
		# Fallback to game_state if Bombs node not found
		game_state.add_child(new_bomb)
		print("WARNING: Bombs node not found, added bomb to game_state")
	
	# Set bomb position using marker, adjusting for direction
	if bomb_marker:
		var marker_pos = bomb_marker.global_position
		if facing_left:
			# When facing left, subtract 2x the marker's local x position
			new_bomb.position = marker_pos - Vector2(2 * abs(bomb_marker.position.x), 0)
		else:
			# When facing right, use marker position directly
			new_bomb.position = marker_pos
	else:
		# Fallback to character position if marker not found
		new_bomb.position = global_position + Vector2(0, -60)
	
	# Set bomb to armed state
	new_bomb.state = new_bomb.BombState.ARMED
	
	# Mark bomb as being held
	new_bomb.set_held(true)
	
	# Store reference to held bomb
	held_bomb = new_bomb
	
	# Set holding state for animation
	is_holding_bomb = true

func handle_semisolid_collision() -> void:
	"""Handle semisolid platform collision logic"""
	
	# Enable semisolid collision when:
	# 1. Moving down (falling) - to land on platforms from above
	# 2. Standing on a semisolid platform - to stay on it
	if velocity.y > 0.1 or was_on_semisolid:
		# Enable collision with semisolid platforms (layer 2)
		collision_mask = 3  # 1 (solid) + 2 (semisolid)
	else:
		# Disable collision with semisolid platforms when moving up or horizontally
		collision_mask = 1  # Only solid platforms

func handle_bend_input() -> void:
	"""Handle bend input"""
	# Check if bend action is pressed (start bending)
	if Input.is_action_just_pressed("bend") and not is_bending and is_on_floor() and abs(velocity.x) < 10:
		start_bending()
	
	# Check if bend action is released (stop bending)
	elif Input.is_action_just_released("bend") and is_bending:
		stop_bending()

func start_bending() -> void:
	"""Start bending animation and check for bomb pickup"""
	is_bending = true
	
	# Check for bomb pickup
	check_bomb_pickup()

func stop_bending() -> void:
	"""Stop bending animation"""
	is_bending = false

func check_bomb_pickup() -> void:
	"""Check if character is colliding with an unarmed bomb and pick it up"""
	print("DEBUG: Checking bomb pickup, nearby_bombs count: ", nearby_bombs.size())
	# Check nearby bombs that are in the Area2D
	for bomb in nearby_bombs:
		print("DEBUG: Checking bomb: ", bomb, " state: ", bomb.get("state") if bomb.has_method("get") else "no get method")
		if bomb.has_method("get") and bomb.get("state") == 0:  # UNARMED state
			print("DEBUG: Found UNARMED bomb, picking up")
			pickup_bomb(bomb)
			break

func pickup_bomb(bomb: Node2D) -> void:
	"""Pick up an unarmed bomb"""
	# Add bomb to player stats
	var game_state = get_node("/root/AdvRockyBullwinkle")
	if game_state:
		game_state.add_bombs(1)
	
	# Free the bomb node
	bomb.queue_free()

func _on_bomb_checker_area_entered(area: Area2D) -> void:
	"""Handle when a bomb enters the bomb checker area"""
	print("DEBUG: Area entered: ", area, " is in bombs group: ", area.is_in_group("bombs"))
	if area.is_in_group("bombs"):
		nearby_bombs.append(area)
		print("DEBUG: Added bomb to nearby_bombs, count: ", nearby_bombs.size())

func _on_bomb_checker_body_entered(body: Node2D) -> void:
	"""Handle when a body enters the bomb checker area"""
	print("DEBUG: Body entered: ", body, " is in bombs group: ", body.is_in_group("bombs"))
	if body.is_in_group("bombs"):
		nearby_bombs.append(body)
		print("DEBUG: Added bomb to nearby_bombs, count: ", nearby_bombs.size())

func _on_bomb_checker_area_exited(area: Area2D) -> void:
	"""Handle when a bomb exits the bomb checker area"""
	print("DEBUG: Area exited: ", area, " is in bombs group: ", area.is_in_group("bombs"))
	if area.is_in_group("bombs"):
		nearby_bombs.erase(area)
		print("DEBUG: Removed bomb from nearby_bombs, count: ", nearby_bombs.size())

func _on_bomb_checker_body_exited(body: Node2D) -> void:
	"""Handle when a body exits the bomb checker area"""
	print("DEBUG: Body exited: ", body, " is in bombs group: ", body.is_in_group("bombs"))
	if body.is_in_group("bombs"):
		nearby_bombs.erase(body)
		print("DEBUG: Removed bomb from nearby_bombs, count: ", nearby_bombs.size())
