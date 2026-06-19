class_name Game
extends Node2D

const RESULT_TITLE_WIN: String = "牛"
const RESULT_TITLE_LOSE: String = "菜"
const RESULT_MESSAGE_WIN: String = "膜拜大神"
const RESULT_MESSAGE_LOSE: String = "菜鸡互啄"
const RESULT_BUTTON_TEXT: String = "结束"

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

@export_group("关卡 UI")
# 关卡倒计时总时长，单位秒
@export_range(1.0, 3600.0, 1.0, "or_greater") var level_duration: float = 60.0

@onready var _player: Player = $Player
@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _enemy_spawn_point_root: Node2D = $EnemySpawnPointsRoot
@onready var _enemy_spawn_timer: Timer = $EnemySpawnTimer
@onready var _life_count_label: Label = $HUDLayer/LifeCountLabel
@onready var _time_bar: Sprite2D = $HUDLayer/TimeBar
@onready var _result_dialog: AcceptDialog = $ResultDialog
@onready var _bgm_player: AudioStreamPlayer = $AudioContainer/BGMPlayer
@onready var _win_sfx_player: AudioStreamPlayer = $AudioContainer/WinSFXPlayer
@onready var _lose_sfx_player: AudioStreamPlayer = $AudioContainer/LoseSFXPlayer

# 随机数生成器，用于挑选出生点和敌人配置
var _random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
# 缓存出生点，避免每次刷怪都重新遍历场景树
var _enemy_spawn_points: Array[Marker2D] = []
# 缓存有效的敌人配置资源，自动忽略空项
var _valid_enemy_configs: Array[EnemyConfig] = []
# 当前关卡剩余时间
var _level_time_left: float = 0.0
# 时间条原始横向缩放，便于按百分比缩短
var _time_bar_full_scale_x: float = 1.0
# 时间条左边缘位置，保证缩放时从左往右收缩
var _time_bar_left_edge_x: float = 0.0
# 时间条贴图宽度，用于在 centered 模式下修正位置
var _time_bar_texture_width: float = 0.0
# 是否已经进入结算状态，避免重复弹出结算对话框
var _is_result_displayed: bool = false


func _ready() -> void:
    _random_generator.randomize()
    _configure_result_dialog()
    _setup_hud()
    _collect_enemy_spawn_points()
    _collect_enemy_configs()
    _configure_enemy_spawn_timer()
    _spawn_initial_enemies()
    _start_enemy_spawn_timer()


func _process(delta: float) -> void:
    if _is_result_displayed:
        return

    _update_level_timer(delta)
    _update_spawn_interval()
    _update_hud()
    _check_level_complete()


func _configure_result_dialog() -> void:
    _result_dialog.dialog_close_on_escape = false
    _result_dialog.ok_button_text = RESULT_BUTTON_TEXT
    _result_dialog.hide()

    if not _result_dialog.confirmed.is_connected(_on_result_dialog_exit_requested):
        _result_dialog.confirmed.connect(_on_result_dialog_exit_requested)
    if not _result_dialog.close_requested.is_connected(_on_result_dialog_exit_requested):
        _result_dialog.close_requested.connect(_on_result_dialog_exit_requested)
    if not _result_dialog.canceled.is_connected(_on_result_dialog_exit_requested):
        _result_dialog.canceled.connect(_on_result_dialog_exit_requested)


func _setup_hud() -> void:
    _level_time_left = maxf(level_duration, 0.0)

    _time_bar_full_scale_x = _time_bar.scale.x
    if _time_bar.texture != null:
        _time_bar_texture_width = _time_bar.texture.get_width()
    if _time_bar.centered:
        _time_bar_left_edge_x = _time_bar.position.x - (_time_bar_full_scale_x * _time_bar_texture_width * 0.5)
    else:
        _time_bar_left_edge_x = _time_bar.position.x

    _update_hud()


func _update_level_timer(delta: float) -> void:
    if _level_time_left <= 0.0:
        _level_time_left = 0.0
        return

    _level_time_left = maxf(_level_time_left - delta, 0.0)


func _update_hud() -> void:
    _update_life_count_label()
    _update_time_bar()


func _update_life_count_label() -> void:
    _life_count_label.text = "x %d" % _get_player_life_count()


func _update_time_bar() -> void:
    var fill_ratio := 0.0
    if level_duration > 0.0:
        fill_ratio = clampf(_level_time_left / level_duration, 0.0, 1.0)

    _time_bar.scale.x = _time_bar_full_scale_x * fill_ratio

    if not _time_bar.centered:
        _time_bar.position.x = _time_bar_left_edge_x
        return

    var current_width := _time_bar_texture_width * _time_bar.scale.x
    _time_bar.position.x = _time_bar_left_edge_x + (current_width * 0.5)


func _check_level_complete() -> void:
    if _level_time_left <= 0.0:
        _show_result_dialog(RESULT_TITLE_WIN, RESULT_MESSAGE_WIN)
        return

    if _get_player_life_count() <= 0:
        _show_result_dialog(RESULT_TITLE_LOSE, RESULT_MESSAGE_LOSE)
        return


func _show_result_dialog(result_title: String, result_message: String) -> void:
    if _is_result_displayed:
        return

    _is_result_displayed = true
    _result_dialog.title = result_title
    _result_dialog.dialog_text = result_message
    _play_result_audio(result_title)
    _stop_world()
    _result_dialog.popup_centered()

    var ok_button: Button = _result_dialog.get_ok_button()
    if ok_button != null:
        ok_button.grab_focus()


func _play_result_audio(result_title: String) -> void:
    if _bgm_player.playing:
        _bgm_player.stop()

    if result_title == RESULT_TITLE_WIN:
        Utilities.play_sfx(_win_sfx_player)
    elif result_title == RESULT_TITLE_LOSE:
        Utilities.play_sfx(_lose_sfx_player)


func _stop_world() -> void:
    _enemy_spawn_timer.stop()
    _player.stop_runtime_audio()
    Engine.time_scale = 0.0
    get_tree().paused = true


func _on_result_dialog_exit_requested() -> void:
    get_tree().quit()


func _get_player_life_count() -> int:
    return _player.get_current_health()


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

    if level_duration <= 0.0:
        return end_interval

    var difficulty_ratio := 1.0 - clampf(_level_time_left / level_duration, 0.0, 1.0)
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