extends Node

## 战斗回放冒烟测试：验证 3路x2排 战斗回放引擎、样例 JSON 数据回放、跳过机制与折页结算
## 运行：godot --headless --path client res://tests/BattleReplaySmoke.tscn

var replay_scene: Control
var phase := 0
var frames := 0

func _ready() -> void:
	print("BATTLE_REPLAY_SMOKE start")
	var scene_res = load("res://BattleReplay.tscn")
	if not scene_res:
		_fail("failed to load BattleReplay.tscn")
		return
	
	replay_scene = scene_res.instantiate()
	add_child(replay_scene)
	
	# 测试用户规范指定的严格 JSON 样例
	var test_json := {
		"tick_max": 60,
		"wall_base": 1000,
		"att_slots": {"1": {"front": "cav", "back": "arc"}, "2": {"front": "shield"}},
		"def_slots": {"1": {"front": "shield", "back": "arc"}},
		"units": [
			{"id": "A1F", "side": "att", "lane": 1, "row": "front", "type": "cav", "troops": 363, "max_troops": 363},
			{"id": "D1F", "side": "def", "lane": 1, "row": "front", "type": "shield", "troops": 400, "max_troops": 400}
		],
		"events": [
			{"t": 4, "lane": 1, "unit": "A1F", "action": "attack", "target": "D1F", "damage": 30, "target_troops": 333, "killed": false},
			{"t": 6, "unit": "SIEGE", "action": "wall", "damage": 42, "wall": 958},
			{"t": 15, "lane": 1, "unit": "A1F", "action": "attack", "target": "D1F", "damage": 50, "target_troops": 283, "killed": false},
			{"t": 30, "unit": "SIEGE", "action": "wall", "damage": 658, "wall": 300}
		],
		"result": {"wall": 300, "score": 1, "ticks": 61}
	}
	
	replay_scene.play_data(test_json)
	phase = 1

func _process(_delta: float) -> void:
	frames += 1
	OS.delay_msec(8)
	
	if phase == 1:
		# 验证初始状态载入
		if replay_scene.units_data.size() >= 2 and replay_scene.current_wall == 1000:
			print("BATTLE_REPLAY_SMOKE init ok=true units=%d wall=%d" % [
				replay_scene.units_data.size(),
				replay_scene.current_wall
			])
			# 触发跳过逻辑，快速推演到最终状态
			replay_scene._on_skip_pressed()
			phase = 2
			frames = 0
		elif frames > 300:
			_fail("init timeout")
	elif phase == 2:
		# 验证跳过推演完成与结算结果
		if replay_scene.current_tick == 60:
			print("BATTLE_REPLAY_SMOKE finished ok=true wall=%d" % replay_scene.current_wall)
			if replay_scene.current_wall != 300:
				_fail("expected final wall to be 300, got %d" % replay_scene.current_wall)
				return
			if not replay_scene.result_overlay.visible:
				_fail("result overlay not visible")
				return
			
			# 验证折页翻页
			replay_scene._show_page_frame(1)
			if not replay_scene.page_frame_2.visible:
				_fail("page frame 2 not visible")
				return
			
			print("BATTLE_REPLAY_SMOKE PASS")
			get_tree().quit(0)
		elif frames > 300:
			_fail("finish timeout")

func _fail(message: String) -> void:
	push_error("BATTLE_REPLAY_SMOKE failed: " + message)
	get_tree().quit(1)
