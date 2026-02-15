extends Control

# 传感器数据显示脚本 - Godot 4

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

func _ready():
	status_label.text = "状态: 传感器已启动"
	status_label.modulate = Color.GREEN

func _process(_delta):
	# 获取加速度计数据 (m/s²)
	var accel = Input.get_accelerometer()
	accel_x.text = "X: %.3f" % accel.x
	accel_y.text = "Y: %.3f" % accel.y
	accel_z.text = "Z: %.3f" % accel.z

	# 获取陀螺仪数据 (rad/s)
	var gyro = Input.get_gyroscope()
	gyro_x.text = "X: %.3f" % gyro.x
	gyro_y.text = "Y: %.3f" % gyro.y
	gyro_z.text = "Z: %.3f" % gyro.z

	# 获取重力传感器数据 (m/s²)
	var gravity = Input.get_gravity()
	gravity_x.text = "X: %.3f" % gravity.x
	gravity_y.text = "Y: %.3f" % gravity.y
	gravity_z.text = "Z: %.3f" % gravity.z

	# 获取磁力计数据 (μT)
	var magneto = Input.get_magnetometer()
	magneto_x.text = "X: %.3f" % magneto.x
	magneto_y.text = "Y: %.3f" % magneto.y
	magneto_z.text = "Z: %.3f" % magneto.z

	# 更新状态
	if accel == Vector3.ZERO and gyro == Vector3.ZERO:
		status_label.text = "状态: 等待传感器数据..."
		status_label.modulate = Color.YELLOW
	else:
		status_label.text = "状态: 正常接收数据"
		status_label.modulate = Color.GREEN
