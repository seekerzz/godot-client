extends Control

# 传感器数据显示与发送脚本 - Godot 4
# 将传感器数据通过UDP发送到PC端

const SERVER_IP := "192.168.50.64"  # PC IP地址
const SERVER_PORT := 49555
const SEND_INTERVAL := 0.05  # 发送间隔(秒)

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

# 录制UI
@onready var record_button: Button = %RecordButton
@onready var record_status_label: Label = %RecordStatusLabel

# 回放UI
@onready var recording_list: ItemList = %RecordingList
@onready var playback_button: Button = %PlaybackButton
@onready var delete_button: Button = %DeleteButton
@onready var refresh_button: Button = %RefreshButton
@onready var playback_progress: ProgressBar = %PlaybackProgress

var udp: PacketPeerUDP
var send_timer: float = 0.0
var is_connected := false

# 录制功能
var is_recording := false
var recorded_frames: Array[Dictionary] = []

# 回放功能
var is_playing := false
var playback_frames: Array[Dictionary] = []
var playback_index: int = 0
var playback_timer: float = 0.0
var current_playback_file: String = ""

func _ready():
	init_network()
	status_label.text = "状态: 传感器已启动"
	status_label.modulate = Color.GREEN

	# 连接录制按钮
	if record_button:
		record_button.pressed.connect(_on_record_button_pressed)
		update_record_button_ui()

	# 连接回放按钮
	if playback_button:
		playback_button.pressed.connect(_on_playback_button_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_button_pressed)
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_button_pressed)
	if recording_list:
		recording_list.item_selected.connect(_on_recording_selected)

	# 加载录制列表
	refresh_recording_list()

func init_network():
	udp = PacketPeerUDP.new()
	var err = udp.bind(0)  # 绑定任意可用端口
	if err == OK:
		udp.set_dest_address(SERVER_IP, SERVER_PORT)
		is_connected = true
		status_label.text = "状态: 网络已连接"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "状态: 网络连接失败"
		status_label.modulate = Color.RED

func _process(delta):
	# 处理回放
	if is_playing:
		playback_timer += delta
		if playback_timer >= SEND_INTERVAL:
			playback_timer = 0.0
			send_next_playback_frame()
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
	if send_timer >= SEND_INTERVAL and is_connected:
		send_sensor_data(accel, gyro, gravity, magneto)
		send_timer = 0.0

	# 更新状态
	if not is_playing:
		if accel == Vector3.ZERO and gyro == Vector3.ZERO:
			status_label.text = "状态: 等待传感器数据..."
			status_label.modulate = Color.YELLOW
		else:
			if is_connected:
				status_label.text = "状态: 正常发送数据"
				status_label.modulate = Color.GREEN

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
		"timestamp": Time.get_unix_time_from_system(),
		"recorded": is_recording
	}

	# 如果正在录制，保存到本地缓存
	if is_recording:
		recorded_frames.append(data.duplicate())
		# 更新UI显示帧数
		if record_status_label:
			record_status_label.text = "录制中... 帧数: " + str(recorded_frames.size())

	send_data_packet(data)

func send_data_packet(data: Dictionary):
	var json_str = JSON.stringify(data)
	var packet = json_str.to_utf8_buffer()
	var err = udp.put_packet(packet)
	if err == OK:
		print("[发送] ", json_str)

func send_next_playback_frame():
	if playback_index >= playback_frames.size():
		stop_playback()
		return

	var frame = playback_frames[playback_index]
	# 添加回放标记
	frame["playback"] = true
	frame["frame_index"] = playback_index
	frame["total_frames"] = playback_frames.size()

	send_data_packet(frame)

	# 更新进度
	playback_index += 1
	if playback_progress:
		playback_progress.value = float(playback_index) / playback_frames.size() * 100

	status_label.text = "回放中: %d/%d" % [playback_index, playback_frames.size()]
	status_label.modulate = Color.CYAN

func _on_record_button_pressed():
	if is_recording:
		stop_recording()
	else:
		start_recording()

func start_recording():
	is_recording = true
	recorded_frames.clear()
	update_record_button_ui()

	# 发送录制开始标记到服务端
	if is_connected:
		var marker = {"type": "record_start", "timestamp": Time.get_unix_time_from_system()}
		udp.put_packet(JSON.stringify(marker).to_utf8_buffer())

	print("[录制] 开始录制")

func stop_recording():
	is_recording = false
	update_record_button_ui()

	# 发送录制结束标记到服务端
	if is_connected:
		var marker = {"type": "record_stop", "timestamp": Time.get_unix_time_from_system()}
		udp.put_packet(JSON.stringify(marker).to_utf8_buffer())

	# 保存录制数据到本地
	save_recorded_data_locally()
	print("[录制] 结束录制，共 " + str(recorded_frames.size()) + " 帧")

	# 刷新列表
	refresh_recording_list()

func update_record_button_ui():
	if record_button:
		if is_recording:
			record_button.text = "结束录制"
			record_button.modulate = Color.RED
		else:
			record_button.text = "开始录制"
			record_button.modulate = Color.WHITE

	if record_status_label:
		if is_recording:
			record_status_label.text = "录制中... 帧数: " + str(recorded_frames.size())
			record_status_label.modulate = Color.RED
		else:
			record_status_label.text = "未录制"
			record_status_label.modulate = Color.WHITE

func save_recorded_data_locally():
	if recorded_frames.is_empty():
		print("[录制] 没有数据需要保存")
		return

	var datetime = Time.get_datetime_dict_from_system()
	var filename = "user://record_%04d%02d%02d_%02d%02d%02d.json" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

	print("[录制] 正在保存到: " + filename)
	print("[录制] 帧数: " + str(recorded_frames.size()))

	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var output = {
			"record_date": "%04d-%02d-%02d %02d:%02d:%02d" % [
				datetime.year, datetime.month, datetime.day,
				datetime.hour, datetime.minute, datetime.second
			],
			"frame_count": recorded_frames.size(),
			"duration": recorded_frames.size() * SEND_INTERVAL,
			"frames": recorded_frames
		}
		file.store_string(JSON.stringify(output, "\t"))
		file.close()
		print("[录制] 数据已保存成功")
		status_label.text = "录制已保存: " + filename.get_file()
	else:
		var err = FileAccess.get_open_error()
		print("[录制] 保存失败，错误码: " + str(err))
		status_label.text = "保存失败: " + str(err)

# ===== 回放功能 =====

func refresh_recording_list():
	if not recording_list:
		print("[列表] recording_list 节点未找到")
		return

	recording_list.clear()
	print("[列表] 正在刷新录制列表...")

	var dir = DirAccess.open("user://")
	if not dir:
		print("[列表] 无法打开 user:// 目录")
		status_label.text = "无法访问存储目录"
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var files: Array[String] = []

	while file_name != "":
		if file_name.begins_with("record_") and file_name.ends_with(".json"):
			files.append(file_name)
			print("[列表] 发现文件: " + file_name)
		file_name = dir.get_next()

	files.sort()
	files.reverse()  # 最新的在前

	print("[列表] 共发现 " + str(files.size()) + " 个录制文件")

	for f in files:
		# 解析文件名显示友好名称
		var display_name = parse_recording_filename(f)
		recording_list.add_item(display_name)
		recording_list.set_item_metadata(recording_list.get_item_count() - 1, f)

func parse_recording_filename(filename: String) -> String:
	# record_YYYYMMDD_HHMMSS.json -> 2024年MM月DD日 HH:MM:SS
	if filename.length() < 22:
		return filename

	var year = filename.substr(7, 4)
	var month = filename.substr(11, 2)
	var day = filename.substr(13, 2)
	var hour = filename.substr(16, 2)
	var minute = filename.substr(18, 2)
	var second = filename.substr(20, 2)

	return "%s年%s月%s日 %s:%s:%s" % [year, month, day, hour, minute, second]

func _on_recording_selected(index: int):
	if recording_list:
		current_playback_file = recording_list.get_item_metadata(index)
		status_label.text = "已选择: " + parse_recording_filename(current_playback_file)

func _on_playback_button_pressed():
	if is_playing:
		stop_playback()
	elif current_playback_file != "":
		start_playback()

func start_playback():
	if current_playback_file == "":
		status_label.text = "请先选择一个录制文件"
		return

	print("[回放] 尝试打开文件: " + current_playback_file)
	var file = FileAccess.open("user://" + current_playback_file, FileAccess.READ)
	if not file:
		status_label.text = "无法打开文件: " + current_playback_file
		print("[回放] 错误: 无法打开文件")
		return

	var content = file.get_as_text()
	file.close()
	print("[回放] 文件内容长度: " + str(content.length()))

	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		status_label.text = "文件解析失败"
		print("[回放] 错误: JSON 解析失败")
		return

	var data = json.get_data()
	if not data.has("frames"):
		status_label.text = "无效的数据格式"
		print("[回放] 错误: 没有 frames 字段")
		return

	playback_frames = data["frames"]
	playback_index = 0
	playback_timer = 0.0
	is_playing = true

	print("[回放] 加载成功，共 " + str(playback_frames.size()) + " 帧")

	# 发送回放开始标记
	if is_connected:
		var marker = {
			"type": "playback_start",
			"filename": current_playback_file,
			"frame_count": playback_frames.size(),
			"timestamp": Time.get_unix_time_from_system()
		}
		var marker_str = JSON.stringify(marker)
		udp.put_packet(marker_str.to_utf8_buffer())
		print("[回放] 发送开始标记: " + marker_str)
	else:
		print("[回放] 警告: 未连接到服务器")

	playback_button.text = "停止回放"
	playback_button.modulate = Color.ORANGE
	status_label.text = "开始回放: " + parse_recording_filename(current_playback_file) + " [" + str(playback_frames.size()) + " 帧]"

func stop_playback():
	is_playing = false
	playback_frames.clear()
	playback_index = 0

	# 发送回放停止标记
	if is_connected:
		var marker = {
			"type": "playback_stop",
			"timestamp": Time.get_unix_time_from_system()
		}
		udp.put_packet(JSON.stringify(marker).to_utf8_buffer())

	playback_button.text = "开始回放"
	playback_button.modulate = Color.WHITE
	if playback_progress:
		playback_progress.value = 0
	status_label.text = "回放已停止"

func _on_delete_button_pressed():
	if recording_list:
		var selected = recording_list.get_selected_items()
		if selected.size() == 0:
			status_label.text = "请先选择要删除的文件"
			return

		var index = selected[0]
		var filename = recording_list.get_item_metadata(index)

		var err = DirAccess.remove_absolute("user://" + filename)
		if err == OK:
			status_label.text = "已删除: " + parse_recording_filename(filename)
			refresh_recording_list()
			current_playback_file = ""
		else:
			status_label.text = "删除失败"

func _on_refresh_button_pressed():
	refresh_recording_list()
	status_label.text = "列表已刷新"

func _exit_tree():
	if is_playing:
		stop_playback()
	if udp:
		udp.close()
