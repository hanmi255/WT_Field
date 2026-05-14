extends Area2D
class_name Bullet

const WORLD_COLLISION_MASK: int = 1

@export var speed: float = 320.0
@export var max_lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var remaining_lifetime: float = 0.0

func _ready() -> void:
	remaining_lifetime = max_lifetime
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	var current_position: Vector2 = global_position
	var new_position: Vector2 = current_position + direction * speed * delta

	if _will_hit_world_bounds(current_position, new_position):
		queue_free()
		return

	global_position = new_position

	# 没有检测到碰撞时，也要在超时后销毁
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()


func setup(initial_direction: Vector2) -> void:
	if initial_direction != Vector2.ZERO:
		direction = initial_direction.normalized()

	rotation = direction.angle()


# 使用射线查询检测当前帧的飞行路径，避免子弹穿过零厚度边界或薄墙体
func _will_hit_world_bounds(from_position: Vector2, to_position: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false

	var query := PhysicsRayQueryParameters2D.create(
		from_position,
		to_position,
		WORLD_COLLISION_MASK,
	)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var hit_result := space_state.intersect_ray(query)
	return not hit_result.is_empty()


func _on_area_entered(area: Area2D) -> void:
	if area is Bullet:
		return

	queue_free()