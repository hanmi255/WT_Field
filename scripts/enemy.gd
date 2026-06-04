extends CharacterBody2D
class_name Enemy

const DEFAULT_BULLET_DAMAGE: int = 1
const BLINK_ENABLED_SHADER_PARAMETER: StringName = &"blink_enabled"
const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")
const EXPLOSION_QUERY_MAX_RESULTS: int = 16

enum DeathSequenceStage {
	NONE,
	DEATH,
	EXPLOSION
}

# 敌人配置资源
@export var config: EnemyConfig
# 敌人接触玩家时造成的伤害值
@export var touch_damage: int = 1
# 敌人持续贴住玩家时的伤害间隔
@export var touch_damage_interval: float = 0.5
# 受击闪烁持续时间
@export var hurt_blink_duration: float = 0.16

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _touch_damage_area: Area2D = $TouchDamageArea
@onready var _touch_damage_collision_shape: CollisionShape2D = $TouchDamageArea/CollisionShape2D
@onready var _explosion_area: Area2D = $ExplosionArea
@onready var _explosion_collision_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D

# 当前追踪的玩家对象，由敌人管理器在生成时注入
var _target_player: Player = null
# 当前生命值
var _current_health: int = 1
# 敌人死亡后停止移动和受伤处理
var _is_dead: bool = false
# 接触伤害冷却时间
var _touch_damage_cooldown_left: float = 0.0
# 当前仍在接触范围的玩家对象
# TODO: 联机时需要同步这个数组
# var _players_in_touch_range: Array[Player] = []
var _touched_player: Player = null
# 受击闪烁剩余时间
var _hurt_blink_time_left: float = 0.0
# 当前死亡流程所处阶段
var _death_sequence_stage: DeathSequenceStage = DeathSequenceStage.NONE
# 当前死亡阶段正在播放的动画
var _death_animation_name_in_use: StringName = &""
# 敌人实例的随机数生成器，用于掉落判定
var _random_generator: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random_generator.randomize()
	_touch_damage_area.body_entered.connect(_on_touch_damage_area_body_entered)
	_touch_damage_area.body_exited.connect(_on_touch_damage_area_body_exited)
	_touch_damage_area.area_entered.connect(_on_touch_damage_area_area_entered)
	_animated_sprite.animation_finished.connect(_on_animation_finished)
	_apply_config()


func setup(enemy_config: EnemyConfig, player: Player) -> void:
	config = enemy_config
	_target_player = player
	_apply_config()


func set_target_player(player: Player) -> void:
	_target_player = player


func apply_damage(amount: int) -> bool:
	if _is_dead:
		return false
	if amount <= 0:
		return false

	_current_health -= amount
	if _current_health <= 0:
		_current_health = 0
		_die()
		return true

	_start_hurt_blink()
	return true


func _physics_process(delta: float) -> void:
	_update_hurt_blink(delta)
	_update_touch_damage(delta)

	if _is_dead:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(_target_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var movement_direction := global_position.direction_to(_target_player.global_position)
	_update_facing(movement_direction)
	velocity = movement_direction * _get_move_speed()
	move_and_slide()


func _apply_config() -> void:
	if config == null:
		return

	_current_health = config.max_health
	_apply_collision_radius(config.collision_radius)
	_apply_explosion_radius(config.explosion_radius)

	if config.enemy_frames != null:
		_animated_sprite.sprite_frames = config.enemy_frames
		if config.enemy_frames.has_animation(config.move_animation_name):
			_animated_sprite.play(config.move_animation_name)
		else:
			push_warning("Missing Enemy Move Animation: %s" % config.move_animation_name)


func _apply_collision_radius(radius: float) -> void:
	var body_shape := _collision_shape.shape as CircleShape2D
	if body_shape != null:
		body_shape.radius = radius

	var damage_shape := _touch_damage_collision_shape.shape as CircleShape2D
	if damage_shape != null:
		damage_shape.radius = radius


func _apply_explosion_radius(radius: float) -> void:
	if not config.explode_on_death:
		return

	var explosion_shape := _explosion_collision_shape.shape as CircleShape2D
	if explosion_shape != null:
		explosion_shape.radius = radius


func _get_move_speed() -> float:
	return 0.0 if config == null else config.move_speed


func _update_facing(move_direction: Vector2) -> void:
	if is_zero_approx(move_direction.x):
		return

	_animated_sprite.flip_h = move_direction.x < 0.0


# 敌人接触玩家时触发持续伤害
func _on_touch_damage_area_body_entered(body: Node2D) -> void:
	if _is_dead:
		return

	var player := body as Player
	if player == null:
		return

	_touched_player = player
	_try_deal_touch_damage()


func _on_touch_damage_area_body_exited(body: Node2D) -> void:
	if body == _touched_player:
		_touched_player = null


# 子弹击中敌人时触发伤害
func _on_touch_damage_area_area_entered(area: Area2D) -> void:
	if _is_dead:
		return

	var bullet := area as Bullet
	if bullet == null:
		return

	var damaged := apply_damage(DEFAULT_BULLET_DAMAGE)
	if damaged:
		bullet.queue_free()


# 管理对玩家造成持续伤害的冷却时间
func _update_touch_damage(delta: float) -> void:
	if _touch_damage_cooldown_left > 0.0:
		_touch_damage_cooldown_left = maxf(_touch_damage_cooldown_left - delta, 0.0)

	if _touched_player == null:
		return
	if not is_instance_valid(_touched_player):
		_touched_player = null
		return
	if _touch_damage_cooldown_left > 0.0:
		return

	_try_deal_touch_damage()


# 尝试对接触的玩家造成伤害
func _try_deal_touch_damage() -> void:
	if _touched_player == null:
		return

	_touched_player.apply_damage(touch_damage)
	_touch_damage_cooldown_left = touch_damage_interval


# 敌人受击闪烁
func _start_hurt_blink() -> void:
	_hurt_blink_time_left = hurt_blink_duration
	_set_hurt_blink_enabled(true)


# 闪烁时间结束后恢复正常
func _update_hurt_blink(delta: float) -> void:
	if _hurt_blink_time_left <= 0.0:
		return

	_hurt_blink_time_left = maxf(_hurt_blink_time_left - delta, 0.0)
	if _hurt_blink_time_left > 0.0:
		return

	_set_hurt_blink_enabled(false)


func _set_hurt_blink_enabled(enabled: bool) -> void:
	var sprite_material := _animated_sprite.material as ShaderMaterial
	sprite_material.set_shader_parameter(BLINK_ENABLED_SHADER_PARAMETER, enabled)


# 进入死亡阶段后停止碰撞，并启动动画
func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	_touched_player = null
	_hurt_blink_time_left = 0.0
	_set_hurt_blink_enabled(false)
	_collision_shape.set_deferred("disabled", true)
	_touch_damage_collision_shape.set_deferred("disabled", true)
	_touch_damage_area.set_deferred("monitoring", false)
	_touch_damage_area.set_deferred("monitorable", false)
	_try_drop_pickup()
	_start_death_sequence()


# 先播放通用死亡动画，自爆敌人再额外播放爆炸动画
func _start_death_sequence() -> void:
	if config == null:
		queue_free()
		return

	if _play_death_sequence_animation(config.death_animation_name, DeathSequenceStage.DEATH):
		return

	_finish_after_death_animation()


func _finish_after_death_animation() -> void:
	if _should_play_explosion_sequence():
		_start_explosion_sequence()
		return

	queue_free()


func _should_play_explosion_sequence() -> bool:
	return config != null and config.explode_on_death


# 自爆阶段开始结算爆炸伤害
func _start_explosion_sequence() -> void:
	if not _should_play_explosion_sequence():
		queue_free()
		return

	_try_apply_explosion_damage()

	if _play_death_sequence_animation(config.explosion_animation_name, DeathSequenceStage.EXPLOSION):
		return

	queue_free()


func _play_death_sequence_animation(animation_name: StringName, stage: DeathSequenceStage) -> bool:
	_death_animation_name_in_use = animation_name
	_death_sequence_stage = stage

	if config == null:
		return false
	if config.enemy_frames == null:
		return false
	if not config.enemy_frames.has_animation(animation_name):
		return false

	_animated_sprite.play(animation_name)
	return true


func _try_apply_explosion_damage() -> void:
	if config == null:
		return
	if not config.explode_on_death:
		return
	if config.explosion_damage <= 0 or config.explosion_radius <= 0.0:
		return
	if _explosion_collision_shape.shape == null:
		return

	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _explosion_collision_shape.shape
	query.transform = _explosion_collision_shape.global_transform
	query.collision_mask = _explosion_area.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var query_results := space_state.intersect_shape(query, EXPLOSION_QUERY_MAX_RESULTS)
	if query_results.is_empty():
		return

	var damaged_collider_ids: Dictionary = {}

	for result in query_results:
		var collider := result.get("collider") as Node
		if collider == null:
			continue
		if collider == self:
			continue

		var collider_id := collider.get_instance_id()
		if damaged_collider_ids.has(collider_id):
			continue
		damaged_collider_ids[collider_id] = true

		var hited_player := collider as Player
		if hited_player != null:
			hited_player.apply_damage(config.explosion_damage)
			continue

		var hited_enemy := collider as Enemy
		if hited_enemy != null:
			hited_enemy.apply_damage(config.explosion_damage)


# 敌人死亡时概率掉落道具
func _try_drop_pickup() -> void:
	if config == null:
		return
	if config.pickup_drop_configs.is_empty():
		return
	if _random_generator.randf() > config.pickup_drop_chance:
		return

	var pickup_config := _pick_pickup_drop_config()
	if pickup_config == null:
		return

	call_deferred("_spawn_dropped_pickup", pickup_config, global_position)


# 从掉落配置中随机选择一个
func _pick_pickup_drop_config() -> PickupConfig:
	if config == null:
		return null

	var available_configs: Array[PickupConfig] = []
	var total_weight := 0.0

	for pickup_config in config.pickup_drop_configs:
		if pickup_config == null:
			continue
		if pickup_config.drop_weight <= 0.0:
			continue
		available_configs.append(pickup_config)
		total_weight += pickup_config.drop_weight

	if available_configs.is_empty():
		return null
	if total_weight <= 0.0:
		return null

	var target_weight := _random_generator.randf_range(0.0, total_weight)
	var accumulated_weight := 0.0

	for pickup_config in available_configs:
		accumulated_weight += pickup_config.drop_weight
		if accumulated_weight >= target_weight:
			return pickup_config

	return available_configs.back()


# 延迟到当前物理查询结束后再实例化掉落物，避免在碰撞回调中直接修改物理对象状态
func _spawn_dropped_pickup(pickup_config: PickupConfig, spawn_position: Vector2) -> void:
	var drop_parent := get_parent()
	if drop_parent == null:
		return

	var pickup_instance := PICKUP_SCENE.instantiate() as Pickup
	if pickup_instance == null:
		return

	pickup_instance.config = pickup_config
	drop_parent.add_child(pickup_instance)
	pickup_instance.global_position = spawn_position


func _on_animation_finished() -> void:
	if not _is_dead:
		return
	if _death_animation_name_in_use == &"":
		return
	if _animated_sprite.animation != _death_animation_name_in_use:
		return

	match _death_sequence_stage:
		DeathSequenceStage.DEATH:
			_finish_after_death_animation()
		DeathSequenceStage.EXPLOSION:
			queue_free()
		_:
			queue_free()
