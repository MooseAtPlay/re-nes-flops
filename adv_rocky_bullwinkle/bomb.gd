extends CharacterBody2D

enum BombState {
	UNARMED,
	ARMED,
	THROWN_SAFE,  # Safe period after being thrown - won't damage thrower
	EXPLODING
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_area: Area2D = $DamageArea

@export var state: BombState = BombState.UNARMED
@export var armed_explode_time: float = 2.0  # in seconds

var armed_timer: float = 0.0
var has_damaged_player: bool = false
var has_damaged_enemy: bool = false
var is_held: bool = false
var thrower: Node2D = null  # Reference to the character who threw this bomb
var safe_period_timer: float = 0.0
const SAFE_PERIOD_DURATION = 0.5  # Safe period in seconds
const GRAVITY = 360.0
const FRICTION = 800.0  # Friction when sliding on ground

# Semisolid platform state tracking
var was_on_semisolid: bool = false

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
	damage_area.body_entered.connect(_on_body_entered)
	
	# Disable damage area initially - only enable when exploding
	if damage_area:
		damage_area.monitoring = false
		print("Damage area monitoring disabled initially")
	
	print("Bomb ready - Position: ", position, " State: ", state)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Handle semisolid platform collision FIRST
	handle_semisolid_collision()
	
	# Handle movement based on velocity and gravity
	if state != BombState.EXPLODING and not is_held:
		# Check if bomb has been thrown (has velocity)
		if velocity != Vector2.ZERO:
			# Thrown bomb: apply gravity to velocity and move by velocity
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			else:
				# When on floor, set vertical velocity to 0 and apply friction to horizontal velocity
				velocity.y = 0.0
				# Apply friction to horizontal movement
				velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

			# Use move_and_slide for proper physics collision
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
		else:
			# Non-thrown bomb: apply gravity directly to position (original behavior)
			if not is_on_floor():
				position.y += GRAVITY * delta
	
	# Handle safe period timer for thrown bombs
	if state == BombState.THROWN_SAFE:
		safe_period_timer += delta
		if safe_period_timer >= SAFE_PERIOD_DURATION:
			# Safe period over, transition to armed state
			state = BombState.ARMED
			armed_timer = 0.0
			print("Bomb safe period ended, now armed - Position: ", position, " Velocity: ", velocity, " On floor: ", is_on_floor())
	
	# Handle armed bomb timer
	if state == BombState.ARMED:
		armed_timer += delta
		if armed_timer >= armed_explode_time:
			print("Bomb timer expired, exploding!")
			explode()
	
	# Handle damage during exploding state
	if state == BombState.EXPLODING:
		var bodies = damage_area.get_overlapping_bodies()
		print("Bomb exploding - detected ", bodies.size(), " overlapping bodies")
		for body in bodies:
			print("Overlapping body: ", body.name, " Type: ", body.get_class())
			# Skip damage to the thrower
			if body == thrower:
				print("Skipping damage to thrower: ", body.name)
				continue
			
			# Damage player if not already damaged
			if body.name == "Bullwinkle" and not has_damaged_player:
				print("Bullwinkle hit by exploding bomb!")
				has_damaged_player = true
				# Get the game state and damage the player
				var game_state = get_node("/root/AdvRockyBullwinkle")
				if game_state:
					print("Game state found, current health: ", game_state.health)
					game_state.take_damage(1)
					print("Player damaged by bomb, new health: ", game_state.health)
				else:
					print("ERROR: Could not find game state to damage player")
			
			# Damage enemy if not already damaged
			elif body.name == "Boris" and not has_damaged_enemy:
				print("Boris hit by exploding bomb!")
				has_damaged_enemy = true
				if body.has_method("take_damage"):
					body.take_damage(1)
					print("Boris damaged by bomb")
				else:
					print("ERROR: Boris does not have take_damage method")


func arm_bomb() -> void:
	"""Arm the bomb so it can explode"""
	print("Bomb armed!")
	state = BombState.ARMED
	armed_timer = 0.0

func set_held(held: bool) -> void:
	"""Set whether the bomb is being held by the player"""
	is_held = held
	if not held:
		# When released, clear any accumulated velocity from gravity
		velocity = Vector2.ZERO
		print("Bomb released from hold")
	else:
		print("Bomb is being held")

func set_thrown_by(character: Node2D) -> void:
	"""Set the character who threw this bomb and start safe period"""
	thrower = character
	state = BombState.THROWN_SAFE
	safe_period_timer = 0.0
	print("Bomb thrown by: ", character.name, " - Safe period started")

func explode() -> void:
	"""Explode the bomb"""
	print("Bomb exploding! State changing to EXPLODING")
	state = BombState.EXPLODING
	armed_timer = 0.0
	has_damaged_player = false
	has_damaged_enemy = false
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Enable damage area monitoring
	if damage_area:
		damage_area.monitoring = true
		print("Damage area monitoring enabled")
	
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
	
	# Force immediate damage check after a small delay to ensure area detection works
	await get_tree().process_frame
	check_immediate_damage()

func check_immediate_damage() -> void:
	"""Check for immediate damage when bomb explodes"""
	if not damage_area:
		return
		
	var bodies = damage_area.get_overlapping_bodies()
	print("Immediate damage check - detected ", bodies.size(), " overlapping bodies")
	for body in bodies:
		print("Immediate check - Overlapping body: ", body.name, " Type: ", body.get_class())
		# Skip damage to the thrower
		if body == thrower:
			print("Skipping immediate damage to thrower: ", body.name)
			continue
		
		# Damage player if not already damaged
		if body.name == "Bullwinkle" and not has_damaged_player:
			print("IMMEDIATE: Bullwinkle hit by exploding bomb!")
			has_damaged_player = true
			# Get the game state and damage the player
			var game_state = get_node("/root/AdvRockyBullwinkle")
			if game_state:
				print("IMMEDIATE: Game state found, current health: ", game_state.health)
				game_state.take_damage(1)
				print("IMMEDIATE: Player damaged by bomb, new health: ", game_state.health)
			else:
				print("ERROR: Could not find game state to damage player")
		
		# Damage enemy if not already damaged
		elif body.name == "Boris" and not has_damaged_enemy:
			print("IMMEDIATE: Boris hit by exploding bomb!")
			has_damaged_enemy = true
			if body.has_method("take_damage"):
				body.take_damage(1)
				print("IMMEDIATE: Boris damaged by bomb")
			else:
				print("ERROR: Boris does not have take_damage method")

func _on_body_entered(body: Node2D) -> void:
	"""Handle when a body enters the bomb area"""
	print("Body entered bomb area: ", body.name, " State: ", state)
	
	# Skip collision with thrower during safe period
	if state == BombState.THROWN_SAFE and body == thrower:
		return
	
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
