class_name Game
extends Node2D


@export_group("刷怪资源")
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var enemy_configs: Array[EnemyConfig] = [
    preload("res://config/enemy_config/enemy_basic.tres"),
    preload("res://config/enemy_config/enemy_shelled.tres"),
    preload("res://config/enemy_config/enemy_fast.tres"),
    preload("res://config/enemy_config/enemy_bomber.tres"),
]

@export_group("刷怪节奏")
# 开局的刷怪数量
@export_range(0, 100, 1, "or_greater") var initial_spawn_count: int = 1
# 每次计时器触发时的刷怪数量
@export_range(0, 20, 1, "or_greater") var spawn_count_per_tick: int = 1
# 开局时的刷怪间隔
@export_range(0.1, 60.0, 0.1, "or_greater") var spawn_interval: float = 1.5
# 关卡后期允许缩短到的最小刷怪间隔
@export_range(0.1, 60.0, 0.1, "or_greater") var min_spawn_interval: float = 0.6
# 允许最大敌人存在数量
@export_range(1, 200, 1, "or_greater") var max_active_enemies: int = 12

#region Debug
# 刷怪间隔从开局到逐渐缩小到最小值所需的时间（秒）
@export_range(1.0, 3600.0, 1.0, "or_greater") var spawn_acceleration_duration: float = 60.0
#endregion

@onready var _player: Player = $Player
@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _enemy_spawn_point_root: Node2D = $EnemySpawnPointsRoot
@onready var _enemy_spawn_timer: Timer = $EnemySpawnTimer

# 随机数生成器，用于挑选出生点和敌人配置
var _random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
# 缓存出生点，避免每次刷怪都重新遍历场景树
var _enemy_spawn_points: Array[Marker2D] = []
# 缓存有效的敌人配置资源，自动忽略空项
var _valid_enemy_configs: Array[EnemyConfig] = []
# 当前游戏运行时间，用于计算动态刷怪间隔
var _game_time_elapsed: float = 0.0


func _ready() -> void:
    _random_generator.randomize()
    _collect_enemy_spawn_points()
    _collect_enemy_configs()
    _configure_enemy_spawn_timer()
    _spawn_initial_enemies()
    _start_enemy_spawn_timer()


func _process(delta: float) -> void:
    _game_time_elapsed += delta
    _update_spawn_interval()


func _collect_enemy_spawn_points() -> void:
    _enemy_spawn_points.clear()
    for child in _enemy_spawn_point_root.get_children():
        if child is Marker2D:
            _enemy_spawn_points.append(child)

    if _enemy_spawn_points.is_empty():
        push_warning("EnemySpawnPoints: 没有找到敌人出生点！")


func _collect_enemy_configs() -> void:
    _valid_enemy_configs.clear()
    for config in enemy_configs:
        if config != null:
            _valid_enemy_configs.append(config)

    if _valid_enemy_configs.is_empty():
        push_warning("EnemyConfigs: 没有找到有效的敌人配置！")


func _configure_enemy_spawn_timer() -> void:
    _enemy_spawn_timer.one_shot = false
    _enemy_spawn_timer.wait_time = _get_current_spawn_interval()

    if not _enemy_spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
        _enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)


# 更新刷怪间隔
func _update_spawn_interval() -> void:
    var current_interval := _get_current_spawn_interval()
    if is_equal_approx(current_interval, _enemy_spawn_timer.wait_time):
        return

    _enemy_spawn_timer.wait_time = current_interval

    # 如果当前这一轮倒计时比新的间隔更长，就立刻切换到更快的节奏
    if _enemy_spawn_timer.is_stopped():
        return
    if _enemy_spawn_timer.time_left <= current_interval:
        return

    _enemy_spawn_timer.start(current_interval)


# 根据游戏运行时间，计算当前的刷怪间隔
func _get_current_spawn_interval() -> float:
    var start_interval := maxf(spawn_interval, 0.1)
    var end_interval := minf(maxf(min_spawn_interval, 0.1), start_interval)

    if spawn_acceleration_duration <= 0.0:
        return end_interval

    var difficulty_ratio := clampf(_game_time_elapsed / spawn_acceleration_duration, 0.0, 1.0)
    return lerpf(start_interval, end_interval, difficulty_ratio)


# 开局刷一波敌人
func _spawn_initial_enemies() -> void:
    for _spawn_index in range(initial_spawn_count):
        if not _try_spawn_enemy():
            break


# 当前刷怪系统准备完成后再启动计时器
func _start_enemy_spawn_timer() -> void:
    if not _is_spawn_system_ready():
        return

    _enemy_spawn_timer.start()


# 每次计时器触发时，按照设定数量刷怪
func _on_enemy_spawn_timer_timeout() -> void:
    for _spawn_index in range(spawn_count_per_tick):
        if not _try_spawn_enemy():
            break


# 尝试刷怪
func _try_spawn_enemy() -> bool:
    if not _is_spawn_system_ready():
        return false
    if _get_active_enemy_count() >= max_active_enemies:
        return false

    var spawn_point := _pick_spawn_point()
    if spawn_point == null:
        return false

    var enemy_config := _pick_enemy_config()
    if enemy_config == null:
        return false

    var enemy_instance := enemy_scene.instantiate() as Enemy
    if enemy_instance == null:
        push_error("敌人场景实例化失败，请检查 enemy_scene 资源")
        return false

    _enemy_container.add_child(enemy_instance)
    enemy_instance.global_position = spawn_point.global_position
    enemy_instance.setup(enemy_config, _player)

    return true


# 玩家、敌人场景、刷怪点、敌人配置都准备就绪
func _is_spawn_system_ready() -> bool:
    return (
        _player != null
        and enemy_scene != null
        and not _enemy_spawn_points.is_empty()
        and not enemy_configs.is_empty()
    )


# 随机选择一个刷怪点
func _pick_spawn_point() -> Marker2D:
    if _enemy_spawn_points.is_empty():
        return null

    var random_index := _random_generator.randi_range(0, _enemy_spawn_points.size() - 1)
    return _enemy_spawn_points[random_index]


# 随机选择一个敌人配置
func _pick_enemy_config() -> EnemyConfig:
    if enemy_configs.is_empty():
        return null

    var random_index := _random_generator.randi_range(0, enemy_configs.size() - 1)
    return enemy_configs[random_index]


# 统计当前活跃敌人数量
func _get_active_enemy_count() -> int:
    var active_enemy_count := 0
    for child in _enemy_container.get_children():
        if child is Enemy:
            active_enemy_count += 1
    return active_enemy_count