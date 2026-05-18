extends CharacterBody2D
class_name Player

const NORMAL_ANIMATION_PREFIX: StringName = &"normal"
const ARMED_ANIMATION_PREFIX: StringName = &"armed"

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")

const DEFAULT_MOVE_SPEED_MULTIPLIER: float = 1.0
const DEFAULT_FIRE_RATE_MULTIPLIER: float = 1.0
const SPIRAL_PHASE_STEP: float = PI / 12


# 移动速度，单位像素/秒
@export var move_speed: float = 120.0
# 攻击间隔
@export var fire_interval: float = 0.18
# 子弹生成时与玩家的偏移，避免贴合玩家
@export var bullet_spawn_offset: float = 18.0

@onready var _body_sprite: AnimatedSprite2D = $BodySprite
@onready var _armed_effect_sprite: AnimatedSprite2D = $ArmedEffectSprite
@onready var _shooting_timer: Timer = $ShootingTimer

# 当前朝向后缀，对应动画中的"up"、"down"、"left"、"right"
var _facing_suffix: StringName = &"right"
# 当前移速倍率
var _move_speed_multiplier: float = DEFAULT_MOVE_SPEED_MULTIPLIER
# 普通射速倍率
var _rapid_fire_rate_multiplier: float = DEFAULT_FIRE_RATE_MULTIPLIER
# 强化形态射速倍率
var _form_fire_rate_multiplier: float = DEFAULT_FIRE_RATE_MULTIPLIER
# 当前玩家形态
var _form_mode: int = PickupConfig.PlayerFormMode.NORMAL
# 当前弹幕模式
var _shot_pattern: int = PickupConfig.ShotPattern.NORMAL
# 螺旋弹幕的相位，让连续射击形成旋转感
var _spiral_phase: float = 0.0

# 三类Buff的持续时间
var _speed_buff_time_left: float = 0.0
var _rapid_buff_time_left: float = 0.0
var _form_buff_time_left: float = 0.0

func _ready():
	_shooting_timer.one_shot = true
	_shooting_timer.wait_time = _get_effective_fire_interval()
	_update_animation()
	_update_armed_effect()


func _physics_process(delta: float) -> void:
	_update_pickup_effects(delta)

	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var shoot_input := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")

	velocity = move_input * _get_effective_move_speed()
	move_and_slide()

	if _shot_pattern == PickupConfig.ShotPattern.SPIRAL:
		_try_auto_spiral_shoot()
	elif shoot_input != Vector2.ZERO:
		_try_shoot(shoot_input)

	_update_facing(move_input, shoot_input)
	_update_animation()
	_update_armed_effect()


func apply_pickup(config: PickupConfig) -> bool:
	if config == null:
		return false

	var applied := false
	var should_refresh_shooting_timer := false
	var buff_duration := maxf(config.duration, 0.0)
	var has_form_override := (
		config.player_form_mode != PickupConfig.PlayerFormMode.NORMAL
		or config.shot_pattern != PickupConfig.ShotPattern.NORMAL
	)
	var has_fire_rate_override := not is_equal_approx(
		config.fire_rate_multiplier,
		DEFAULT_FIRE_RATE_MULTIPLIER
	)

	# 移速道具
	if not is_equal_approx(config.move_speed_multiplier, DEFAULT_MOVE_SPEED_MULTIPLIER):
		_move_speed_multiplier = config.move_speed_multiplier
		_speed_buff_time_left = buff_duration
		applied = true

	# 普通射速道具与形态专属射速拆开维护，避免螺旋形态的射速被其他 Buff 覆盖
	if has_fire_rate_override and not has_form_override:
		_rapid_fire_rate_multiplier = config.fire_rate_multiplier
		_rapid_buff_time_left = buff_duration
		should_refresh_shooting_timer = true
		applied = true

	# 形态道具
	if has_form_override:
		_form_mode = config.player_form_mode
		_shot_pattern = config.shot_pattern
		_form_fire_rate_multiplier = (
			config.fire_rate_multiplier if has_fire_rate_override else DEFAULT_FIRE_RATE_MULTIPLIER
		)
		_form_buff_time_left = buff_duration
		_spiral_phase = 0.0
		should_refresh_shooting_timer = true
		applied = true

	if should_refresh_shooting_timer:
		_refresh_shooting_timer_wait_time()

	return applied


# 螺旋形态自动按固定节奏 360 度旋转发射
func _try_auto_spiral_shoot() -> void:
	if not _shooting_timer.is_stopped():
		return

	var spiral_direction := Vector2.RIGHT.rotated(_spiral_phase)
	var has_spawned_bullet := _fire_bullets(spiral_direction)
	if has_spawned_bullet:
		_shooting_timer.start(_get_effective_fire_interval())


# 尝试发射子弹，先检查冷却，再根据当前弹幕模式发射
func _try_shoot(shoot_input: Vector2) -> void:
	if not _shooting_timer.is_stopped():
		return

	var shoot_direction := shoot_input.normalized()
	var has_spawned_bullet := _fire_bullets(shoot_direction)
	if has_spawned_bullet:
		_shooting_timer.start(_get_effective_fire_interval())


func _refresh_shooting_timer_wait_time() -> void:
	var new_interval := _get_effective_fire_interval()
	_shooting_timer.wait_time = new_interval

	# 如果玩家在冷却中拾取了更快的射速 Buff，需要让当前冷却也立刻缩短
	if _shooting_timer.is_stopped():
		return
	if _shooting_timer.time_left <= new_interval:
		return

	_shooting_timer.start(new_interval)


# 计算当前有效移动速度，移速倍率越高，速度越快
func _get_effective_move_speed() -> float:
	return move_speed * _move_speed_multiplier


# 计算当前有效发射间隔，射速倍率越高，间隔越短
func _get_effective_fire_interval() -> float:
	return max(fire_interval / _get_effective_fire_rate_multiplier(), 0.01)


# 强化形态下优先使用自带射速倍率，否则返回普通射速倍率
func _get_effective_fire_rate_multiplier() -> float:
	if _has_active_form_override():
		return maxf(_form_fire_rate_multiplier, 0.01)

	return maxf(_rapid_fire_rate_multiplier, 0.01)


# 只要玩家处于特殊形态或者特殊弹幕模式，视为强化有效
func _has_active_form_override() -> bool:
	return (
		_form_mode != PickupConfig.PlayerFormMode.NORMAL
		or _shot_pattern != PickupConfig.ShotPattern.NORMAL
	)


# 根据当前形态选择动画前缀
func _get_animation_prefix() -> StringName:
	if _form_mode == PickupConfig.PlayerFormMode.ARMED:
		return ARMED_ANIMATION_PREFIX

	return NORMAL_ANIMATION_PREFIX


# 根据当前弹幕模式发射子弹，并返回是否至少成功生成一颗子弹
func _fire_bullets(base_direction: Vector2) -> bool:
	if _shot_pattern == PickupConfig.ShotPattern.SPIRAL:
		var has_spawned_forward_bullet := _spawn_bullet(base_direction)
		var has_spawned_backward_bullet := _spawn_bullet(base_direction.rotated(PI))
		_spiral_phase = wrapf(_spiral_phase + SPIRAL_PHASE_STEP, 0.0, TAU)
		return has_spawned_forward_bullet or has_spawned_backward_bullet

	return _spawn_bullet(base_direction)


func _spawn_bullet(shoot_direction: Vector2) -> bool:
	# 子弹挂载到主场景，避免跟随玩家移动
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		return false

	var bullet := BULLET_SCENE.instantiate() as Bullet
	if bullet == null:
		return false

	bullet.top_level = true
	bullet.setup(shoot_direction)

	spawn_parent.add_child(bullet)
	bullet.global_position = global_position + shoot_direction * bullet_spawn_offset
	return true


# 每帧更新 Buff 剩余时间，在到期后恢复默认状态
func _update_pickup_effects(delta: float) -> void:
	# 移速 Buff
	if _speed_buff_time_left > 0.0:
		_speed_buff_time_left = maxf(_speed_buff_time_left - delta, 0.0)
		if _speed_buff_time_left <= 0.0:
			_move_speed_multiplier = DEFAULT_MOVE_SPEED_MULTIPLIER

	# 射速 Buff
	if _rapid_buff_time_left > 0.0:
		_rapid_buff_time_left = maxf(_rapid_buff_time_left - delta, 0.0)
		if _rapid_buff_time_left <= 0.0:
			_rapid_fire_rate_multiplier = DEFAULT_FIRE_RATE_MULTIPLIER
			_refresh_shooting_timer_wait_time()

	# 形态 Buff
	if _form_buff_time_left > 0.0:
		_form_buff_time_left = maxf(_form_buff_time_left - delta, 0.0)
		if _form_buff_time_left <= 0.0:
			_form_mode = PickupConfig.PlayerFormMode.NORMAL
			_shot_pattern = PickupConfig.ShotPattern.NORMAL
			_form_fire_rate_multiplier = DEFAULT_FIRE_RATE_MULTIPLIER
			_spiral_phase = 0.0
			_refresh_shooting_timer_wait_time()


# 射击方向优先于移动方向，用于决定显示玩家朝向
# 自动螺旋弹幕期间不再读取射击输入，只根据移动方向更新朝向
func _update_facing(move_input: Vector2, shoot_input: Vector2) -> void:
	if _shot_pattern == PickupConfig.ShotPattern.SPIRAL:
		if move_input != Vector2.ZERO:
			_facing_suffix = _vector_to_facing_suffix(move_input)
		return

	if shoot_input != Vector2.ZERO:
		_facing_suffix = _vector_to_facing_suffix(shoot_input)
	elif move_input != Vector2.ZERO:
		_facing_suffix = _vector_to_facing_suffix(move_input)


func _update_animation() -> void:
	var animation_name := StringName("%s_%s" % [_get_animation_prefix(), _facing_suffix])

	if not _body_sprite.sprite_frames.has_animation(animation_name):
		var fallback_animation_name := StringName("%s_%s" % [NORMAL_ANIMATION_PREFIX, _facing_suffix])
		if not _body_sprite.sprite_frames.has_animation(fallback_animation_name):
			push_warning("Missing Player Animation: %s" % animation_name)
			return
		animation_name = fallback_animation_name

	if _body_sprite.animation != animation_name:
		_body_sprite.play(animation_name)


func _update_armed_effect() -> void:
	var is_armed := _form_mode == PickupConfig.PlayerFormMode.ARMED

	if not is_armed:
		# 不可见并停止播放
		if _armed_effect_sprite.visible:
			_armed_effect_sprite.visible = false
		if _armed_effect_sprite.is_playing():
			_armed_effect_sprite.stop()
		return

	if not _armed_effect_sprite.visible:
		_armed_effect_sprite.visible = true
	if _armed_effect_sprite.is_playing():
		return
	if _armed_effect_sprite.sprite_frames == null:
		return

	if _armed_effect_sprite.sprite_frames.has_animation(&"default"):
		_armed_effect_sprite.play(&"default")


# 根据方向向量获取朝向后缀，用于动画名称拼接
func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y):
		return &"right" if direction.x > 0.0 else &"left"

	return &"down" if direction.y > 0.0 else &"up"
