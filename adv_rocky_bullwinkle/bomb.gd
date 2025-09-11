extends Area2D

enum BombState {
	UNARMED,
	ARMED,
	EXPLODING
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var state: BombState = BombState.UNARMED
var armed_timer: float = 0.0
var has_damaged_player: bool = false
var velocity: Vector2 = Vector2.ZERO

const ARMED_EXPLODE_TIME = 2.0 # in seconds
const GRAVITY = 9.8 * 8 # 8x gravity

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Bomb _ready() called - State: ", state)
	
	# Check if animated_sprite exists
	if animated_sprite:
		print("AnimatedSprite2D found, connecting signals")
		# Connect to animation finished signal
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
		# Start with default animation
		animated_sprite.play("default")
		print("Playing default animation")
	else:
		print("ERROR: AnimatedSprite2D not found!")
	
	# Connect to body entered signal
	body_entered.connect(_on_body_entered)
	print("Bomb ready - Position: ", position, " State: ", state)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Handle movement based on velocity and gravity
	if state != BombState.EXPLODING:
		# Check if bomb has been thrown (has velocity)
		if velocity != Vector2.ZERO:
			# Thrown bomb: apply gravity to velocity and move by velocity
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			position += velocity * delta
			print("Thrown bomb moving - Position: ", position, " Velocity: ", velocity)
		else:
			# Non-thrown bomb: apply gravity directly to position (original behavior)
			if not is_on_floor():
				position.y += GRAVITY * delta
				print("Bomb falling - Position: ", position)
	
	# Handle armed bomb timer
	if state == BombState.ARMED:
		armed_timer += delta
		if armed_timer >= ARMED_EXPLODE_TIME:
			print("Bomb timer expired, exploding!")
			explode()
	
	# Handle player damage during exploding state
	if state == BombState.EXPLODING and not has_damaged_player:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.name == "Bullwinkle":
				print("Bullwinkle hit by exploding bomb!")
				has_damaged_player = true
				# Get the game state and damage the player
				var game_state = get_node("/root/AdvRockyBullwinkle")
				if game_state:
					game_state.take_damage(1)
					print("Player damaged by bomb")
				else:
					print("ERROR: Could not find game state to damage player")
				break  # Only damage once per frame

func is_on_floor() -> bool:
	"""Check if bomb is touching something in the 'floor' group"""
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("floor"):
			return true
	return false

func arm_bomb() -> void:
	"""Arm the bomb so it can explode"""
	print("Bomb armed!")
	state = BombState.ARMED
	armed_timer = 0.0

func explode() -> void:
	"""Explode the bomb"""
	print("Bomb exploding! State changing to EXPLODING")
	state = BombState.EXPLODING
	armed_timer = 0.0
	has_damaged_player = false
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Clear held bomb reference if this bomb was being held
	var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
	if player and player.held_bomb == self:
		player.clear_held_bomb()
	
	# Change to exploding animation
	if animated_sprite:
		animated_sprite.play("exploding")
		print("Playing exploding animation")
	else:
		print("ERROR: Cannot play exploding animation - AnimatedSprite2D not found!")

func _on_body_entered(body: Node2D) -> void:
	"""Handle when a body enters the bomb area"""
	print("Body entered bomb area: ", body.name, " State: ", state)
	if state == BombState.ARMED:
		# Armed bombs explode when touched by non-floor objects
		if not body.is_in_group("floor"):
			print("Armed bomb touched, exploding!")
			explode()
		

func _on_animation_finished() -> void:
	"""Handle when animation finishes"""
	if animated_sprite:
		print("Animation finished: ", animated_sprite.animation)
	else:
		print("Animation finished: No sprite")
	
	if state == BombState.EXPLODING:
		# When exploding animation finishes, free the bomb
		print("Exploding animation finished, freeing bomb")
		queue_free()
