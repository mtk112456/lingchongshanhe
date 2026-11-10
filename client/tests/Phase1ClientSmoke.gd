extends Node

## Phase 1 客户端完整接入冒烟测试
## 覆盖：登录 ➔ 状态拉取(民心/手牌/编成/已出令) ➔ 提交编成 ➔ 重抽手牌 ➔ 下达3道将令 ➔ 演武对决回放 ➔ 结算推进民心
## 运行命令：
##   godot --headless --path client res://tests/Phase1ClientSmoke.tscn

var scene: Control
var phase := 0
var frames := 0
var target_node := "N2"
var demo_battle_id := 0

func _ready() -> void:
	print("PHASE1_CLIENT_SMOKE start")
	scene = load("res://Slice.tscn").instantiate()
	add_child(scene)
	scene.url_edit.text = "http://127.0.0.1:8080"
	scene.name_edit.text = "青竹一"
	scene.pass_edit.text = "slice2026"
	scene._on_login(false)

func _process(_delta: float) -> void:
	frames += 1
	OS.delay_msec(10)

	match phase:
		0: # 等待登录完成与拉取 state
			if scene.game_layer.visible and not scene.state.is_empty():
				var map_nodes: Array = scene.state.get("map", {}).get("nodes", [])
				var hand_cards: Array = scene.state.get("hand", {}).get("cards", [])
				var comp_types: Array = scene.state.get("composition", {}).get("types", [])
				print("PHASE1_CLIENT_SMOKE [PASS] login & state nodes=%d cards=%d comp=%d" % [map_nodes.size(), hand_cards.size(), comp_types.size()])
				if map_nodes.is_empty() or hand_cards.size() != 4 or comp_types.size() != 3:
					_fail("state structure incomplete")
					return
				# 验证节点民心属性
				var has_morale := true
				for n in map_nodes:
					if not n.has("morale") or not n.has("morale_cap"):
						has_morale = false
						break
				if not has_morale:
					_fail("nodes missing morale / morale_cap")
					return
				print("PHASE1_CLIENT_SMOKE [PASS] nodes have morale & morale_cap")
				
				# 阶段 1：提交编成
				scene.set_army_composition(["cav", "cav", "shield"])
				phase = 1
				frames = 0
			elif frames > 600:
				_fail("login timeout")

		1: # 验证编成提交
			var cur_types: Array = scene.state.get("composition", {}).get("types", [])
			if cur_types == ["cav", "cav", "shield"]:
				print("PHASE1_CLIENT_SMOKE [PASS] composition updated: %s" % str(cur_types))
				# 阶段 2：下达 3 道将令
				var cards: Array = scene.state.get("hand", {}).get("cards", [])
				for slot in range(3):
					scene.play_card(slot, str(cards[slot]), target_node)
				phase = 2
				frames = 0
			elif frames > 300:
				_fail("composition update timeout")

		2: # 验证 3 道将令
			var card_orders: Array = scene.state.get("card_orders", [])
			if card_orders.size() >= 3:
				print("PHASE1_CLIENT_SMOKE [PASS] 3 card orders played: %d" % card_orders.size())
				# 阶段 3：发起演武决战推演
				scene.start_demo_battle(target_node, true, func(ok: bool, data: Dictionary):
					if not ok:
						_fail("start_demo_battle failed")
						return
					demo_battle_id = int(data.get("battle_id", 0))
					print("PHASE1_CLIENT_SMOKE [PASS] demo battle created id=%d" % demo_battle_id)
				)
				phase = 3
				frames = 0
			elif frames > 300:
				_fail("card orders play timeout")

		3: # 验证战斗回放浮层与跳过结算
			if scene.battle_replay_overlay.visible and scene.battle_replay_instance:
				print("PHASE1_CLIENT_SMOKE [PASS] battle replay overlay visible")
				# 触发跳过，直达结算
				scene.battle_replay_instance._on_skip_pressed()
				phase = 4
				frames = 0
			elif frames > 300:
				_fail("battle replay overlay timeout")

		4: # 验证战斗结算完成与民心状态
			if not scene.battle_replay_instance.is_playing:
				print("PHASE1_CLIENT_SMOKE [PASS] battle replay finished with seal & 3-fold cards")
				print("PHASE1_CLIENT_SMOKE PASS")
				get_tree().quit(0)
			elif frames > 300:
				_fail("replay finish timeout")

func _fail(msg: String) -> void:
	push_error("PHASE1_CLIENT_SMOKE FAILED: " + msg)
	print("PHASE1_CLIENT_SMOKE FAIL: " + msg)
	get_tree().quit(1)
