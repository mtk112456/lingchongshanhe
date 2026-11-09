extends Node

## 切片测试 API 客户端：单队列，避免 Android 上并发 HTTPRequest 互相覆盖。
## 所有回调签名：callback(ok: bool, data: Dictionary, error: Dictionary)

var base_url := "http://10.0.2.2:8080"
var token := ""

var _http: HTTPRequest
var _queue: Array = []
var _busy := false
var _current: Dictionary = {}

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_completed)

func set_base_url(url: String) -> void:
	base_url = url.strip_edges().trim_suffix("/")
	if base_url == "":
		base_url = "http://10.0.2.2:8080"

func request(method: String, path: String, body: Variant, callback: Callable) -> void:
	_queue.append({
		"method": method,
		"path": path,
		"body": body,
		"callback": callback,
	})
	_pump()

func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	_current = _queue.pop_front()
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var body_text := ""
	if _current.body != null:
		body_text = JSON.stringify(_current.body)
	var method := HTTPClient.METHOD_GET
	match str(_current.method):
		"POST":
			method = HTTPClient.METHOD_POST
		"PUT":
			method = HTTPClient.METHOD_PUT
		"DELETE":
			method = HTTPClient.METHOD_DELETE
	var err := _http.request(base_url + str(_current.path), headers, method, body_text)
	if err != OK:
		_busy = false
		_finish(false, {}, {
			"code": "NETWORK_ERROR",
			"message": "无法连接服务器（%s）" % base_url,
		})

func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish(false, {}, {
			"code": "NETWORK_ERROR",
			"message": "网络请求失败，请检查服务器地址与网络。",
		})
		return

	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish(false, {}, {
			"code": "BAD_RESPONSE",
			"message": "服务器返回格式错误（HTTP %d）" % code,
		})
		return

	var dict: Dictionary = parsed
	var ok := bool(dict.get("ok", false)) and code >= 200 and code < 300
	var data: Dictionary = dict.get("data", {}) if typeof(dict.get("data", {})) == TYPE_DICTIONARY else {}
	var error: Dictionary = {}
	if not ok:
		var raw: Variant = dict.get("error", {})
		error = raw if typeof(raw) == TYPE_DICTIONARY else {
			"code": "HTTP_%d" % code,
			"message": "请求失败（HTTP %d）" % code,
		}
		if not error.has("message"):
			error["message"] = "请求失败（HTTP %d）" % code
	_finish(ok, data, error)

func _finish(ok: bool, data: Dictionary, error: Dictionary) -> void:
	var callback: Callable = _current.get("callback", Callable())
	_current = {}
	if callback.is_valid():
		callback.call(ok, data, error)
	_pump()

# ---------------------------------------------------------------------------
# 认证
# ---------------------------------------------------------------------------

func login(name: String, password: String, callback: Callable) -> void:
	request("POST", "/api/auth/login", {"name": name, "password": password}, callback)

func admin_login(username: String, password: String, callback: Callable) -> void:
	request("POST", "/api/auth/admin-login", {"username": username, "password": password}, callback)

func logout(callback: Callable = Callable()) -> void:
	if token == "":
		if callback.is_valid():
			callback.call(true, {}, {})
		return
	request("POST", "/api/auth/logout", {}, callback)

# ---------------------------------------------------------------------------
# 切片
# ---------------------------------------------------------------------------

func state(callback: Callable, turn_id: int = 0) -> void:
	var path := "/api/slice/state"
	if turn_id > 0:
		path += "?turn_id=" + str(turn_id)
	request("GET", path, null, callback)

func submit_order(turn_id: int, action: String, origin: String, target: String, request_key: String, callback: Callable) -> void:
	request("POST", "/api/slice/orders", {
		"turn_id": turn_id,
		"action": action,
		"origin_node": origin,
		"target_node": target,
		"request_key": request_key,
	}, callback)

func withdraw_order(turn_id: int, request_key: String, callback: Callable) -> void:
	request("POST", "/api/slice/orders/withdraw", {
		"turn_id": turn_id,
		"request_key": request_key,
	}, callback)

func report(turn_id: int, callback: Callable) -> void:
	request("GET", "/api/slice/report?turn_id=" + str(turn_id), null, callback)

func history(callback: Callable) -> void:
	request("GET", "/api/slice/history", null, callback)

func replay(callback: Callable) -> void:
	request("GET", "/api/slice/replay", null, callback)

func wallet(callback: Callable) -> void:
	request("GET", "/api/slice/wallet", null, callback)

func recharge(points: int, request_key: String, callback: Callable) -> void:
	request("POST", "/api/slice/recharge", {
		"points": points,
		"request_key": request_key,
	}, callback)

# ---------------------------------------------------------------------------
# 教师
# ---------------------------------------------------------------------------

func admin_status(callback: Callable) -> void:
	request("GET", "/api/slice/admin/status", null, callback)

func lock_turn(turn_id: int, force: bool, callback: Callable) -> void:
	request("POST", "/api/slice/admin/lock", {"turn_id": turn_id, "force": force}, callback)

func settle_turn(turn_id: int, callback: Callable) -> void:
	request("POST", "/api/slice/admin/settle", {"turn_id": turn_id}, callback)

func next_turn(from_turn_id: int, callback: Callable) -> void:
	request("POST", "/api/slice/admin/next-turn", {"from_turn_id": from_turn_id}, callback)
