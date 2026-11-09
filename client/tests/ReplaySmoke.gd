extends Node

## 回放 UI 冒烟：教师登录 → 锁令 → 结算 → 打开回放。
## 运行前需要已启动 API，并有一个可结算的回合。

var scene: Control
var phase := 0
var frames := 0

func _ready() -> void:
	print("REPLAY_SMOKE start")
	scene = load("res://Slice.tscn").instantiate()
	add_child(scene)
	scene.url_edit.text = "http://127.0.0.1:8080"
	scene.name_edit.text = "teacher"
	scene.pass_edit.text = "teacher2026"
	scene._on_login(true)

func _process(_delta: float) -> void:
	frames += 1
	OS.delay_msec(8)
	if phase == 0:
		if scene.game_layer.visible and not scene.state.is_empty():
			scene._teacher_lock()
			phase = 1
			frames = 0
		elif frames > 1500:
			_fail("teacher login timeout")
	elif phase == 1:
		if str(scene.state.get("turn", {}).get("status", "")) == "locked":
			scene._teacher_settle()
			phase = 2
			frames = 0
		elif frames > 1500:
			_fail("lock timeout")
	elif phase == 2:
		if str(scene.state.get("turn", {}).get("status", "")) == "settled":
			scene._open_replay()
			phase = 3
			frames = 0
		elif frames > 1500:
			_fail("settle timeout")
	elif phase == 3:
		if scene.replay_dialog.visible:
			print("REPLAY_SMOKE turns=%d text=%d" % [
				scene.replay_turn_select.item_count,
				len(scene.replay_text.text),
			])
			if scene.replay_turn_select.item_count < 1 or len(scene.replay_text.text) < 10:
				_fail("replay content empty")
				return
			print("REPLAY_SMOKE PASS")
			get_tree().quit(0)
		elif frames > 1500:
			_fail("replay timeout")

func _fail(message: String) -> void:
	push_error("REPLAY_SMOKE failed: " + message)
	get_tree().quit(1)
