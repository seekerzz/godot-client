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

@onready var quat_x: Label = %QuatX
@onready var quat_y: Label = %QuatY
@onready var quat_z: Label = %QuatZ
@onready var quat_w: Label = %QuatW

@onready var status_label: Label = %StatusLabel

# 录制UI
@onready var record_button: Button = %RecordButton
@onready var record_status_label: Label = %RecordStatusLabel

# 回放UI
@onready var recording_list: ItemList = %RecordingList
@onready var playback_button: Button = %PlaybackButton
@onready var delete_button: Button = %DeleteButton
@onready var refresh_button: Button = %RefreshButton
@onready var send_to_pc_button: Button = %SendToPCButton
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
var _sensor_plugin = null
var _plugin_ready := false
var _plugin_check_elapsed := 0.0
const PLUGIN_CHECK_TIMEOUT := 2.0

func _ready():
	init_network()
	status_label.text = "状态: 等待 SensorPlugin 初始化..."
	status_label.modulate = Color.YELLOW

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
	if send_to_pc_button:
		send_to_pc_button.pressed.connect(_on_send_to_pc_pressed)
	if recording_list:
		recording_list.item_selected.connect(_on_recording_selected)

	# 加载录制列表
	refresh_recording_list()

func _fatal_plugin_error(msg: String):
	push_error(msg)
	status_label.text = "错误: " + msg
	status_label.modulate = Color.RED
	set_process(false)

func _verify_android_plugin_or_fail() -> bool:
	var report_lines: PackedStringArray = []
	if not OS.has_feature("android"):
		report_lines.append("non_android_runtime_fail")
		_write_plugin_report(report_lines)
		return false

	var has_plugin = Engine.has_singleton("SensorPlugin")
	report_lines.append("has_singleton SensorPlugin=%s" % has_plugin)
	if not has_plugin:
		_write_plugin_report(report_lines)
		return false

	_sensor_plugin = Engine.get_singleton("SensorPlugin")
	if _sensor_plugin == null:
		report_lines.append("singleton_null")
		_write_plugin_report(report_lines)
		return false

	var sensor_available = _sensor_plugin.is_sensor_available()
	report_lines.append("sensor_available=%s" % sensor_available)
	if not sensor_available:
		_write_plugin_report(report_lines)
		return false

	_plugin_ready = true
	report_lines.append("plugin_ready=true")
	_write_plugin_report(report_lines)
	return true

func _write_plugin_report(lines: PackedStringArray):
	var f := FileAccess.open("user://plugin_check.txt", FileAccess.WRITE)
	if f:
		for line in lines:
			f.store_line(line)

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

	if not _plugin_ready:
		_plugin_check_elapsed += delta
		if _verify_android_plugin_or_fail():
			status_label.text = "状态: SensorPlugin 已就绪"
			status_label.modulate = Color.GREEN
		elif _plugin_check_elapsed >= PLUGIN_CHECK_TIMEOUT:
			_fatal_plugin_error("SensorPlugin singleton not found")
		return

	if not _plugin_ready or _sensor_plugin == null:
		_fatal_plugin_error("SensorPlugin not ready at runtime")
		return

	var linear_accel = _sensor_plugin.get_linear_acceleration()
	var raw_quat = _sensor_plugin.get_raw_quaternion()
	if linear_accel.size() < 3 or raw_quat.size() < 4:
		_fatal_plugin_error("SensorPlugin returned invalid data shape")
		return

	# 强制走 SensorPlugin: 使用线性加速度和四元数
	var accel = Vector3(linear_accel[0], linear_accel[1], linear_accel[2])
	var gyro = Vector3.ZERO
	var gravity = Vector3.ZERO
	var magneto = Vector3.ZERO
	var quat = Quaternion(raw_quat[0], raw_quat[1], raw_quat[2], raw_quat[3])

	# 更新显示
	update_display(accel, gyro, gravity, magneto, quat)

	# 定时发送数据
	send_timer += delta
	if send_timer >= SEND_INTERVAL and is_connected:
		send_sensor_data(accel, gyro, gravity, magneto, quat)
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

func update_display(accel: Vector3, gyro: Vector3, gravity: Vector3, magneto: Vector3, quat: Quaternion):
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

	quat_x.text = "X: %.4f" % quat.x
	quat_y.text = "Y: %.4f" % quat.y
	quat_z.text = "Z: %.4f" % quat.z
	quat_w.text = "W: %.4f" % quat.w

func send_sensor_data(accel: Vector3, gyro: Vector3, gravity: Vector3, magneto: Vector3, quat: Quaternion):
	# 发送二进制传感器数据（28字节）
	# 包结构: accel(x,y,z) + quaternion(x,y,z,w)，每个float 4字节
	send_binary_sensor_data(accel, quat)

	# 如果正在录制，保存到本地缓存（录制数据仍使用JSON格式便于存储）
	if is_recording:
		var data = {
			"source": "SensorPlugin",
			"accel": {"x": accel.x, "y": accel.y, "z": accel.z},
			"gyro": {"x": gyro.x, "y": gyro.y, "z": gyro.z},
			"gravity": {"x": gravity.x, "y": gravity.y, "z": gravity.z},
			"magneto": {"x": magneto.x, "y": magneto.y, "z": magneto.z},
			"quaternion": {"x": quat.x, "y": quat.y, "z": quat.z, "w": quat.w},
			"timestamp": Time.get_unix_time_from_system(),
			"recorded": is_recording
		}
		recorded_frames.append(data)
		# 更新UI显示帧数
		if record_status_label:
			record_status_label.text = "录制中... 帧数: " + str(recorded_frames.size())

func send_binary_sensor_data(accel: Vector3, quat: Quaternion):
	"""发送二进制传感器数据包（28字节）
	包结构:
	- accel.x (float, 4 bytes)
	- accel.y (float, 4 bytes)
	- accel.z (float, 4 bytes)
	- quaternion.x (float, 4 bytes)
	- quaternion.y (float, 4 bytes)
	- quaternion.z (float, 4 bytes)
	- quaternion.w (float, 4 bytes)
	"""
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false  # 使用小端序与server保持一致

	# 写入加速度数据
	buffer.put_float(accel.x)
	buffer.put_float(accel.y)
	buffer.put_float(accel.z)

	# 写入四元数数据
	buffer.put_float(quat.x)
	buffer.put_float(quat.y)
	buffer.put_float(quat.z)
	buffer.put_float(quat.w)

	# 发送数据包
	var packet = buffer.data_array
	var err = udp.put_packet(packet)
	if err == OK:
		# 调试输出（每60帧输出一次避免日志过多）
		if recorded_frames.size() % 60 == 0:
			print("[发送] 二进制数据 %d bytes | Accel: (%.3f, %.3f, %.3f) | Quat: (%.3f, %.3f, %.3f, %.3f)" % [
				packet.size(), accel.x, accel.y, accel.z, quat.x, quat.y, quat.z, quat.w
			])

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

# ===== 文件传输到电脑功能 =====

const FILE_CHUNK_SIZE := 1000  # 每片大小（字节），留余量避免UDP分片

func send_file_to_pc(filename: String):
	print("[文件传输] 开始传输文件: " + filename)

	var file = FileAccess.open("user://" + filename, FileAccess.READ)
	if not file:
		status_label.text = "无法打开文件: " + filename
		print("[文件传输] 错误: 无法打开文件")
		return

	var file_content = file.get_as_text()
	file.close()

	var total_size = file_content.length()
	var total_chunks = ceil(float(total_size) / FILE_CHUNK_SIZE)

	print("[文件传输] 文件大小: " + str(total_size) + " 字节, 分片数: " + str(total_chunks))

	# 发送文件开始标记
	if is_connected:
		var start_marker = {
			"type": "file_transfer_start",
			"filename": filename,
			"total_size": total_size,
			"total_chunks": total_chunks,
			"timestamp": Time.get_unix_time_from_system()
		}
		udp.put_packet(JSON.stringify(start_marker).to_utf8_buffer())
		print("[文件传输] 发送开始标记")

	status_label.text = "正在发送文件... 0%"
	status_label.modulate = Color.CYAN

	# 分片发送文件内容
	for i in range(total_chunks):
		var start_pos = i * FILE_CHUNK_SIZE
		var end_pos = min((i + 1) * FILE_CHUNK_SIZE, total_size)
		var chunk_data = file_content.substr(start_pos, end_pos - start_pos)

		var chunk_packet = {
			"type": "file_chunk",
			"filename": filename,
			"chunk_index": i,
			"total_chunks": total_chunks,
			"data": chunk_data
		}

		var json_str = JSON.stringify(chunk_packet)
		var err = udp.put_packet(json_str.to_utf8_buffer())
		if err != OK:
			print("[文件传输] 错误: 发送分片失败 " + str(i) + " 错误码: " + str(err))
			status_label.text = "发送失败"
			return

		# 打印前5个和每10个分片的发送日志
		if i < 5 or i % 10 == 0:
			print("[文件传输] 发送分片 #" + str(i) + " 大小: " + str(json_str.length()) + " 字节")

		# 更新进度
		var progress = int(float(i + 1) / total_chunks * 100)
		status_label.text = "正在发送文件... " + str(progress) + "%"

		# 增加延迟避免UDP丢包 (100ms = 10Hz)
		await get_tree().create_timer(0.1).timeout

	# 发送文件结束标记
	if is_connected:
		var end_marker = {
			"type": "file_transfer_end",
			"filename": filename,
			"timestamp": Time.get_unix_time_from_system()
		}
		udp.put_packet(JSON.stringify(end_marker).to_utf8_buffer())
		print("[文件传输] 发送结束标记")

	status_label.text = "文件发送完成: " + parse_recording_filename(filename)
	status_label.modulate = Color.GREEN
	print("[文件传输] 完成")

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

func _on_send_to_pc_pressed():
	if recording_list:
		var selected = recording_list.get_selected_items()
		if selected.size() == 0:
			status_label.text = "请先选择要发送的文件"
			return

		var index = selected[0]
		var filename = recording_list.get_item_metadata(index)

		if not is_connected:
			status_label.text = "未连接到电脑"
			return

		# 调用文件传输函数
		send_file_to_pc(filename)

func _on_refresh_button_pressed():
	refresh_recording_list()
	status_label.text = "列表已刷新"

func _exit_tree():
	if is_playing:
		stop_playback()
	if udp:
		udp.close()
