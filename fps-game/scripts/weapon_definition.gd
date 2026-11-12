class_name WeaponDefinition
extends Resource
@export var id: String = "pistol"
@export var ammo_id: String = "bullets"
@export var damage: float = 22.0
@export var pellets: int = 1
@export var spread: float = 0.003
@export var interval: float = 0.24
@export var magazine: int = 12
@export var reload_time: float = 1.0
@export var model: String = ""
@export var view_offset: Vector3 = Vector3(0.2, -0.17, -0.44)
@export var kick: float = 0.1
@export var sound: String = "pistol"
@export var pitch: float = 1.0
@export var slot: int = 1
@export var projectile: bool = false
