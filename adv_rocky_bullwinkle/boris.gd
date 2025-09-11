extends BombCharacter

const SPEED = 200.0
const JUMP_VELOCITY = -400.0

# Bomb throwing state
var is_preparing_bomb: bool = false
var throw_delay_timer: Timer

func _ready() -> void:
	# Call parent _ready first
	super._ready()
	
	# Create a timer for the delay between creating and throwing bomb
	throw_delay_timer = Timer.new()
	throw_delay_timer.wait_time = 1.0  # 1 second delay
	throw_delay_timer.one_shot = true
	throw_delay_timer.timeout.connect(_on_throw_delay_timeout)
	add_child(throw_delay_timer)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()

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
