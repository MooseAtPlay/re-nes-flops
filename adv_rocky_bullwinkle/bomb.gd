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
	# Check if animated_sprite exists
	if animated_sprite:
		# Connect to animation finished signal
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
		# Start with default animation
		animated_sprite.play("default")
	
	# Connect to body entered signal
	damage_area.body_entered.connect(_on_body_entered)
	
	# Disable damage area initially - only enable when exploding
	if damage_area:
		damage_area.monitoring = false

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
			print("DEBUG: Safe period over, transitioning to armed state")
	
	# Handle armed bomb timer
	if state == BombState.ARMED:
		armed_timer += delta
		if armed_timer >= armed_explode_time:
			print("DEBUG: Armed timer over, exploding bomb")
			explode()
	
	# Handle damage during exploding state
	if state == BombState.EXPLODING:
		var bodies = damage_area.get_overlapping_bodies()
		for body in bodies:
			# Damage player if not already damaged
			if body.name == "Bullwinkle" and not has_damaged_player:
				has_damaged_player = true
				# Get the game state and damage the player
				var game_state = get_node("/root/AdvRockyBullwinkle")
				if game_state:
					game_state.take_damage(1)
			
			# Damage enemy if not already damaged
			elif body.name == "Boris" and not has_damaged_enemy:
				has_damaged_enemy = true
				if body.has_method("take_damage"):
					body.take_damage(1)


func arm_bomb() -> void:
	"""Arm the bomb so it can explode"""
	print("DEBUG: Arming bomb")
	state = BombState.ARMED
	armed_timer = 0.0

func set_held(held: bool) -> void:
	"""Set whether the bomb is being held by the player"""
	print("DEBUG: Setting held: ", held)
	is_held = held
	if not held:
		# When released, clear any accumulated velocity from gravity
		velocity = Vector2.ZERO

func set_thrown_by(character: Node2D) -> void:
	"""Set the character who threw this bomb and start safe period"""
	print("DEBUG: Setting thrown by: ", character)
	thrower = character
	state = BombState.THROWN_SAFE
	print("DEBUG: Setting safe period timer: ", safe_period_timer)
	safe_period_timer = 0.0

func explode() -> void:
	"""Explode the bomb"""
	print("DEBUG: Exploding bomb")
	state = BombState.EXPLODING
	print("DEBUG: Setting armed timer: ", armed_timer)
	armed_timer = 0.0
	has_damaged_player = false
	has_damaged_enemy = false
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Enable damage area monitoring
	if damage_area:
		damage_area.monitoring = true
	
	# Clear held bomb reference if this bomb was being held
	var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
	if player and player.held_bomb == self:
		player.clear_held_bomb()
	
	# Change to exploding animation
	if animated_sprite:
		animated_sprite.play("exploding")
	
	# Force immediate damage check after a small delay to ensure area detection works
	await get_tree().process_frame
	check_immediate_damage()

func check_immediate_damage() -> void:
	"""Check for immediate damage when bomb explodes"""
	print("DEBUG: Checking immediate damage")
	if not damage_area:
		print("DEBUG: No damage area")
		return
		
	var bodies = damage_area.get_overlapping_bodies()
	print("DEBUG: Bodies: ", bodies)
	for body in bodies:
		print("DEBUG: Body: ", body)
		# Skip damage to the thrower
		if body == thrower:
			print("DEBUG: Skipping damage to thrower")
			continue
		
		# Damage player if not already damaged
		if body.name == "Bullwinkle" and not has_damaged_player:
			print("DEBUG: Damaging player")
			has_damaged_player = true
			# Get the game state and damage the player
			var game_state = get_node("/root/AdvRockyBullwinkle")
			if game_state:
				print("DEBUG: Bullwinkle taking damage")
				game_state.take_damage(1)
		
		# Damage enemy if not already damaged
		elif body.name == "Boris" and not has_damaged_enemy:
			print("DEBUG: Damaging enemy")
			has_damaged_enemy = true
			if body.has_method("take_damage"):
				print("DEBUG: Enemy taking damage")
				body.take_damage(1)

func _on_body_entered(body: Node2D) -> void:
	"""Handle when a body enters the bomb area"""
	# Skip collision with thrower during safe period
	if state == BombState.THROWN_SAFE and body == thrower:
		return
	
	if state == BombState.ARMED:
		# Armed bombs explode when touched by non-floor objects
		if not body.is_in_group("floor"):
			explode()
		

func _on_animation_finished() -> void:
	"""Handle when animation finishes"""
	if state == BombState.EXPLODING:
		# When exploding animation finishes, free the bomb
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
