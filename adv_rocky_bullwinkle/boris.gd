extends BombCharacter

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const MOVE_SPEED = 150.0
const MIN_DISTANCE = 92.0

# Health system
@export var health: int = 6
@export var max_health: int = 6

# Bomb throwing state
var throw_delay_timer: Timer

# Player facing
var player_facing_timer: Timer

func _ready() -> void:
	# Call parent _ready first
	super._ready()
	
	# Create a timer for the delay between creating and throwing bomb
	throw_delay_timer = Timer.new()
	throw_delay_timer.wait_time = 1.0  # 1 second delay
	throw_delay_timer.one_shot = true
	throw_delay_timer.timeout.connect(_on_throw_delay_timeout)
	add_child(throw_delay_timer)
	
	# Create a timer for checking player position and facing
	player_facing_timer = Timer.new()
	player_facing_timer.wait_time = 0.25  # 250ms
	player_facing_timer.timeout.connect(_on_player_facing_timeout)
	add_child(player_facing_timer)
	player_facing_timer.start()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle movement (only when not throwing bombs)
	if not is_throwing_bomb:
		handle_movement(delta)
	else:
		print("DEBUG: Not moving - is_throwing_bomb: ", is_throwing_bomb)

	# Handle animations
	handle_animations()

	move_and_slide()

func handle_animations() -> void:
	"""Handle Boris's animations"""
	if is_throwing_bomb:
		# Don't change animation while throwing - let it finish
		pass
	elif is_holding_bomb:
		# Play hold_bomb animation when holding a bomb
		if animated_sprite.animation != "hold_bomb":
			animated_sprite.play("hold_bomb")
	else:
		# Play idle animation when not doing anything else
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func _on_throw_bomb_timer_timeout() -> void:
	"""Called when the main throw timer times out - start bomb throwing sequence"""
	if not is_holding_bomb and not is_throwing_bomb:
		start_bomb_throw_sequence()

func start_bomb_throw_sequence() -> void:
	"""Start the bomb throwing sequence: create bomb, wait, then throw"""
	print("Boris starting bomb throw sequence")
	
	# Stop all movement before creating bomb
	velocity = Vector2.ZERO
	print("DEBUG: Boris velocity zeroed before creating bomb")
	
	# Create and hold a bomb
	create_held_bomb()
	
	# Start the delay timer
	throw_delay_timer.start()
	print("Boris created bomb, waiting to throw...")

func _on_throw_delay_timeout() -> void:
	"""Called when the delay timer times out - throw the bomb"""
	if is_holding_bomb:
		print("Boris throwing bomb after delay")
		throw_bomb()
	else:
		print("Boris delay timeout but no bomb to throw")

func take_damage(amount: int) -> void:
	"""Take damage and handle death"""
	health = max(0, health - amount)
	print("Boris took ", amount, " damage. Health: ", health, "/", max_health)
	
	if health <= 0:
		print("Boris defeated!")
		queue_free()

func _on_player_facing_timeout() -> void:
	"""Check player position and face them"""
	var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
	if player:
		# Check if player is to the left or right of Boris
		if player.global_position.x < global_position.x:
			# Player is to the left, face left
			facing_left = true
			animated_sprite.flip_h = true
		else:
			# Player is to the right, face right
			facing_left = false
			animated_sprite.flip_h = false

func handle_movement(delta: float) -> void:
	"""Handle Boris movement toward player with minimum distance"""
	# Stop moving if holding a bomb
	if is_holding_bomb:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * 2 * delta)
		print("DEBUG: Holding bomb, stopping movement. velocity.x: ", velocity.x)
		return
	
	var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
	if not player:
		print("DEBUG: No player found for Boris movement")
		return
	
	# Calculate distance to player
	var distance_to_player = global_position.distance_to(player.global_position)
	print("DEBUG: Distance to player: ", distance_to_player, " (MIN_DISTANCE: ", MIN_DISTANCE, ")")
	
	# Move based on distance to player
	if distance_to_player > MIN_DISTANCE:
		# Too far away - move toward player
		var direction_to_player = (player.global_position - global_position).normalized()
		print("DEBUG: Moving toward player, direction: ", direction_to_player)
		
		# Move toward player horizontally
		velocity.x = direction_to_player.x * MOVE_SPEED
		print("DEBUG: Set velocity.x to: ", velocity.x)
	elif distance_to_player < MIN_DISTANCE * 0.8:  # Back up when within 80% of min distance
		# Too close - back away from player
		var direction_away_from_player = (global_position - player.global_position).normalized()
		print("DEBUG: Backing away from player, direction: ", direction_away_from_player)
		
		# Move away from player horizontally
		velocity.x = direction_away_from_player.x * MOVE_SPEED
		print("DEBUG: Set velocity.x to: ", velocity.x)
	else:
		# At ideal distance - stop moving horizontally
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * 2 * delta)
		print("DEBUG: At ideal distance, stopping. velocity.x: ", velocity.x)
