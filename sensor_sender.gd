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

var udp: PacketPeerUDP
var send_timer: float = 0.0
var is_connected := false

func _ready():
	init_network()
	status_label.text = "状态: 传感器已启动"
	status_label.modulate = Color.GREEN

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
		"timestamp": Time.get_unix_time_from_system()
	}

	var json_str = JSON.stringify(data)
	var packet = json_str.to_utf8_buffer()
	var err = udp.put_packet(packet)
	if err == OK:
		print("[发送] ", json_str)

func _exit_tree():
	if udp:
		udp.close()
