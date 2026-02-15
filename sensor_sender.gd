extends Control

# 传感器数据显示与发送脚本 - 带配对功能
# 通过UDP发送传感器数据到PC端

const DISCOVERY_PORT_START := 49000
const DISCOVERY_PORT_END := 49010
const PAIRING_TIMEOUT := 3.0  # 配对超时(秒)
const SEND_INTERVAL := 0.05   # 发送间隔(秒)
const CONFIG_FILE := "user://pairing_config.json"

@onready var accel_x: Label = %AccelX
@onready var accel_y: Label = %AccelY
@onready var accel_z: Label = %AccelZ

@onready var gyro_x: Label = %GyroX
@onready var gyro_y: Label = %GyroY
@onready var gyro_z: Label = %GyroZ

@onready var gravity_x: Label = %GravityX
@onready var gravity_y: Label = %GravityY
@onready var gravity_z: Label = %GravityZ

@onready var magneto_x: Label = %MagnetoX
@onready var magneto_y: Label = %MagnetoY
@onready var magneto_z: Label = %MagnetoZ

@onready var status_label: Label = %StatusLabel

# 配对UI
@onready var pairing_panel: Panel = %PairingPanel
@onready var pairing_code_input: LineEdit = %PairingCodeInput
@onready var pair_button: Button = %PairButton
@onready var scan_button: Button = %ScanButton
@onready var pairing_status: Label = %PairingStatus
@onready var saved_info_label: Label = %SavedInfo
@onready var forget_button: Button = %ForgetButton

var discovery_socket: PacketPeerUDP
var data_socket: PacketPeerUDP
var current_pc_ip: String = ""
var current_data_port: int = -1

var send_timer: float = 0.0
var is_paired := false
var is_connecting := false

func _ready():
	# 初始化发现socket
	discovery_socket = PacketPeerUDP.new()
	var err = discovery_socket.bind(0)  # 绑定任意端口
	if err != OK:
		status_label.text = "状态: 网络初始化失败"
		status_label.modulate = Color.RED
		return

	# 初始化数据socket
	data_socket = PacketPeerUDP.new()
	err = data_socket.bind(0)
	if err != OK:
		status_label.text = "状态: 数据socket初始化失败"
		status_label.modulate = Color.RED
		return

	# 连接按钮信号
	pair_button.pressed.connect(_on_pair_button_pressed)
	scan_button.pressed.connect(_on_scan_button_pressed)
	forget_button.pressed.connect(_on_forget_button_pressed)

	# 显示已保存的配对信息
	update_saved_info_display()

	# 尝试自动连接
	try_auto_connect()

# 保存配对信息到本地
func save_pairing_config(pc_ip: String, data_port: int):
	var config = {
		"pc_ip": pc_ip,
		"data_port": data_port,
		"timestamp": Time.get_unix_time_from_system()
	}
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config))
		file.close()
		print("[配置] 配对信息已保存")

# 加载配对信息
func load_pairing_config() -> Dictionary:
	if FileAccess.file_exists(CONFIG_FILE):
		var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json = JSON.new()
			var err = json.parse(content)
			if err == OK:
				return json.get_data()
	return {}

# 尝试自动连接
func try_auto_connect():
	var config = load_pairing_config()
	if config.is_empty():
		update_status("等待配对...")
		return

	current_pc_ip = config.get("pc_ip", "")
	current_data_port = config.get("data_port", -1)

	if current_pc_ip.is_empty() or current_data_port == -1:
		update_status("等待配对...")
		return

	# 尝试连接保存的地址
	pairing_status.text = "尝试自动连接..."
	data_socket.set_dest_address(current_pc_ip, current_data_port)

	# 发送测试数据包
	var test_data = {"type": "ping", "timestamp": Time.get_unix_time_from_system()}
	var err = data_socket.put_packet(JSON.stringify(test_data).to_utf8_buffer())

	if err == OK:
		# 等待一小段时间看是否能收到数据（实际验证在_process中）
		await get_tree().create_timer(0.5).timeout
		# 如果连接成功，数据应该能发送出去
		is_paired = true
		pairing_panel.visible = false
		update_status("已自动连接: " + current_pc_ip)
		print("[连接] 自动连接成功: ", current_pc_ip, ":", current_data_port)
	else:
		pairing_status.text = "自动连接失败，请重新配对"
		update_status("等待配对...")

func _on_pair_button_pressed():
	var code = pairing_code_input.text.strip_edges()
	if code.length() != 4:
		pairing_status.text = "请输入4位配对码"
		return

	if is_connecting:
		return

	is_connecting = true
	pairing_status.text = "正在配对..."
	pair_button.disabled = true

	# 启动配对流程
	attempt_pairing(code)

func _on_scan_button_pressed():
	if is_connecting:
		return

	is_connecting = true
	pairing_status.text = "正在扫描PC..."
	scan_button.disabled = true

	scan_for_pc()

func _on_forget_button_pressed():
	# 清除配对信息
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove(CONFIG_FILE)

	is_paired = false
	current_pc_ip = ""
	current_data_port = -1

	# 更新UI
	update_saved_info_display()
	pairing_status.text = "配对信息已清除"
	update_status("等待配对...")
	print("[配置] 配对信息已清除")

func update_saved_info_display():
	var config = load_pairing_config()
	if not config.is_empty():
		var pc_ip = config.get("pc_ip", "")
		if saved_info_label:
			saved_info_label.text = "已保存的PC: " + pc_ip
		if forget_button:
			forget_button.visible = true
	else:
		if saved_info_label:
			saved_info_label.text = ""
		if forget_button:
			forget_button.visible = false

func scan_for_pc():
	var found := false

	for port in range(DISCOVERY_PORT_START, DISCOVERY_PORT_END + 1):
		pairing_status.text = "尝试端口 " + str(port) + "..."

		# 发送发现请求到广播地址
		discovery_socket.set_dest_address("255.255.255.255", port)
		discovery_socket.put_packet("DISCOVER".to_utf8_buffer())

		# 等待回复
		var start_time := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start_time < 1000:  # 1秒超时
			if discovery_socket.get_available_bytes() > 0:
				var packet = discovery_socket.get_packet()
				var data = packet.get_string_from_utf8()
				var pc_ip = discovery_socket.get_packet_ip()

				if data.begins_with("SERVER_INFO:"):
					current_pc_ip = pc_ip
					found = true
					pairing_status.text = "发现PC: " + pc_ip
					break

			await get_tree().process_frame

		if found:
			break

	if not found:
		pairing_status.text = "未找到PC，请确认PC端已启动"

	is_connecting = false
	scan_button.disabled = false

func attempt_pairing(pairing_code: String):
	var paired := false

	# 尝试所有发现端口
	for port in range(DISCOVERY_PORT_START, DISCOVERY_PORT_END + 1):
		pairing_status.text = "尝试端口 " + str(port) + "..."

		# 发送配对请求
		discovery_socket.set_dest_address("255.255.255.255", port)
		var request = "PAIR:" + pairing_code
		discovery_socket.put_packet(request.to_utf8_buffer())

		# 等待回复
		var start_time := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start_time < int(PAIRING_TIMEOUT * 1000):
			if discovery_socket.get_available_bytes() > 0:
				var packet = discovery_socket.get_packet()
				var data = packet.get_string_from_utf8()
				var pc_ip = discovery_socket.get_packet_ip()

				if data.begins_with("PAIRED:"):
					# 配对成功
					current_data_port = int(data.substr(7))
					current_pc_ip = pc_ip
					is_paired = true
					paired = true

					# 设置数据socket目标
					data_socket.set_dest_address(pc_ip, current_data_port)

					# 保存配对信息
					save_pairing_config(pc_ip, current_data_port)

					pairing_status.text = "配对成功! 端口: " + str(current_data_port)
					pairing_panel.visible = false
					update_status("已连接: " + pc_ip)
					break

				elif data == "ERROR:WRONG_CODE":
					pairing_status.text = "配对码错误"
					break

				elif data.begins_with("ERROR:"):
					pairing_status.text = "配对失败: " + data
					break

			await get_tree().process_frame

		if paired:
			break

	if not paired and pairing_status.text != "配对码错误":
		pairing_status.text = "配对超时，请重试"

	is_connecting = false
	pair_button.disabled = false

func _process(delta):
	if not is_paired:
		return

	# 获取传感器数据
	var accel = Input.get_accelerometer()
	var gyro = Input.get_gyroscope()
	var gravity = Input.get_gravity()
	var magneto = Input.get_magnetometer()

	# 更新显示
	update_display(accel, gyro, gravity, magneto)

	# 定时发送数据
	send_timer += delta
	if send_timer >= SEND_INTERVAL:
		send_sensor_data(accel, gyro, gravity, magneto)
		send_timer = 0.0

func update_display(accel: Vector3, gyro: Vector3, gravity: Vector3, magneto: Vector3):
	accel_x.text = "X: %.3f" % accel.x
	accel_y.text = "Y: %.3f" % accel.y
	accel_z.text = "Z: %.3f" % accel.z

	gyro_x.text = "X: %.3f" % gyro.x
	gyro_y.text = "Y: %.3f" % gyro.y
	gyro_z.text = "Z: %.3f" % gyro.z

	gravity_x.text = "X: %.3f" % gravity.x
	gravity_y.text = "Y: %.3f" % gravity.y
	gravity_z.text = "Z: %.3f" % gravity.z

	magneto_x.text = "X: %.3f" % magneto.x
	magneto_y.text = "Y: %.3f" % magneto.y
	magneto_z.text = "Z: %.3f" % magneto.z

func send_sensor_data(accel: Vector3, gyro: Vector3, gravity: Vector3, magneto: Vector3):
	var data = {
		"accel": {"x": accel.x, "y": accel.y, "z": accel.z},
		"gyro": {"x": gyro.x, "y": gyro.y, "z": gyro.z},
		"gravity": {"x": gravity.x, "y": gravity.y, "z": gravity.z},
		"magneto": {"x": magneto.x, "y": magneto.y, "z": magneto.z},
		"timestamp": Time.get_unix_time_from_system()
	}

	var json_str = JSON.stringify(data)
	var packet = json_str.to_utf8_buffer()
	var err = data_socket.put_packet(packet)

	if err == OK:
		update_status("发送中...")
	else:
		update_status("发送失败")

func update_status(text: String):
	if status_label:
		status_label.text = "状态: " + text

func disconnect():
	is_paired = false
	current_pc_ip = ""
	current_data_port = -1
	pairing_panel.visible = true
	pairing_status.text = "已断开"
	update_status("等待配对...")

func _exit_tree():
	if discovery_socket:
		discovery_socket.close()
	if data_socket:
		data_socket.close()
