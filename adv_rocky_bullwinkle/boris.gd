extends BombCharacter

const SPEED = 200.0
const JUMP_VELOCITY = -400.0

# Health system
@export var health: int = 6
@export var max_health: int = 6

# Bomb throwing state
var is_preparing_bomb: bool = false
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
	if not is_preparing_bomb and not is_holding_bomb and not is_throwing_bomb:
		start_bomb_throw_sequence()

func start_bomb_throw_sequence() -> void:
	"""Start the bomb throwing sequence: create bomb, wait, then throw"""
	print("Boris starting bomb throw sequence")
	is_preparing_bomb = true
	
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
		is_preparing_bomb = false
	else:
		print("Boris delay timeout but no bomb to throw")
		is_preparing_bomb = false

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
