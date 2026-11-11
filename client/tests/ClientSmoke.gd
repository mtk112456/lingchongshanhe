extends Node

## 无头客户端冒烟：验证 Slice.tscn 能构建 UI、登录、拉取切片状态、提交一条军令。
## 运行：godot --headless --path client res://tests/ClientSmoke.tscn
## 用 _process 帧状态机等待网络，避免 headless 定时器不触发的问题。

var scene: Control
var phase := 0
var frames := 0

func _ready() -> void:
	print("CLIENT_SMOKE start")
	scene = load("res://Slice.tscn").instantiate()
	add_child(scene)
	scene.url_edit.text = "http://127.0.0.1:8080"
	scene.name_edit.text = "青竹一"
	scene.pass_edit.text = "slice2026"
	scene._on_login(false)

func _process(_delta: float) -> void:
	frames += 1
	OS.delay_msec(8)

	if phase == 0:
		if scene.game_layer.visible and not scene.state.is_empty():
			var turn_no := int(scene.state.get("turn", {}).get("turn_no", 0))
			var nodes := int(scene.state.get("map", {}).get("nodes", []).size())
			var role := str(scene.me.get("role", ""))
			print("CLIENT_SMOKE login ok=true turn=%d nodes=%d role=%s" % [turn_no, nodes, role])
			if turn_no != 1 or nodes != 5:
				_fail("login/state")
				return
			scene._submit_defend()
			phase = 1
			frames = 0
		elif frames > 1200:
			_fail("login timeout")
	elif phase == 1:
		var card_orders: Array = scene.state.get("card_orders", [])
		if card_orders.size() >= 1:
			print("CLIENT_SMOKE order ok=true card_orders=%d status=%s" % [card_orders.size(), str(scene.action_status.text)])
			scene._logout_local("切换教师")
			scene.name_edit.text = "teacher"
			scene.pass_edit.text = "teacher2026"
			scene._on_login(true)
			phase = 2
			frames = 0
		elif frames > 1200:
			_fail("order timeout")
	elif phase == 2:
		if scene.game_layer.visible and str(scene.state.get("me", {}).get("role", "")) == "teacher":
			print("CLIENT_SMOKE teacher ok=true teacher_box=%s" % str(scene.teacher_box.visible))
			if not scene.teacher_box.visible:
				_fail("teacher_box hidden")
				return
			print("CLIENT_SMOKE PASS")
			get_tree().quit(0)
		elif frames > 1200:
			_fail("teacher timeout")

func _fail(message: String) -> void:
	push_error("CLIENT_SMOKE failed: " + message)
	get_tree().quit(1)
