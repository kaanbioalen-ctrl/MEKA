extends Node2D

@export_range(1.0, 1024.0, 1.0) var radius: float = 200.0
@export var ring_color: Color = Color(0.28, 0.88, 1.0, 0.09)  # çok soluk — max menzil göstergesi
@export_range(0.5, 8.0, 0.1) var ring_width: float = 1.0
@export var draw_fill: bool = false
@export_range(0.0, 1.0, 0.01) var fill_opacity: float = 0.0
@export var dashed: bool = true
@export_range(4, 256, 1) var dash_count: int = 48
@export_range(0.05, 0.95, 0.01) var dash_fill_ratio: float = 0.30


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	pass
