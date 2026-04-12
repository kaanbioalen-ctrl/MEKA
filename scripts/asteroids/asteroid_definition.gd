extends Resource
class_name AsteroidDefinition

@export var definition_id: StringName = &"iron_medium"
@export var display_name: String = "Iron Asteroid"

@export_group("Core Stats")
@export_range(1.0, 500.0, 1.0) var max_hp: float = 6.0
@export_range(4.0, 300.0, 1.0) var radius: float = 34.0
@export_range(10.0, 300.0, 1.0) var speed: float = 36.0

@export_group("Motion")
@export_range(0.0, 0.8, 0.01) var drift_variation: float = 0.04
@export_range(0.0, 4.0, 0.05) var drift_frequency: float = 0.45
@export_range(0.0, 6.0, 0.05) var drift_response: float = 0.75
@export_range(-2.0, 2.0, 0.01) var rotation_speed: float = 0.18

@export_group("Field Response")
@export_range(0.0, 2.0, 0.01) var magnetic_influence: float = 1.0
@export_range(0.1, 4.0, 0.05) var magnetic_resistance: float = 1.0
@export_range(0.0, 400.0, 1.0) var min_pull: float = 14.0
@export_range(0.0, 4.0, 0.05) var velocity_blend: float = 1.4
@export_range(0.0, 4.0, 0.05) var side_damping: float = 0.85
@export_range(0.0, 200.0, 1.0) var pickup_commit_distance: float = 56.0

@export_group("Ambient Motion")
@export_range(0.0, 120.0, 0.5) var orbital_offset_motion: float = 0.0
@export_range(0.0, 6.0, 0.05) var orbital_frequency: float = 0.0
@export_range(0.0, 120.0, 0.5) var resonance_pulse_motion: float = 0.0
@export_range(0.0, 6.0, 0.05) var resonance_frequency: float = 0.0

@export_group("Drops")
@export_range(0, 10, 1) var energy_drop_count: int = 1
@export var orb_resource_kind: StringName = &"iron"
@export_range(0, 10, 1) var energy_orb_drop_count: int = 0
@export_range(1, 500, 1) var orb_value: int = 1

@export_group("Visuals")
@export var glow_color: Color = Color(0.72, 0.78, 0.84, 1.0)
@export var mid_color: Color = Color(0.6, 0.66, 0.74, 1.0)
@export var core_color: Color = Color(0.82, 0.86, 0.92, 1.0)
@export var death_core_color: Color = Color(0.78, 0.84, 0.9, 1.0)
@export var death_burst_color: Color = Color(0.58, 0.64, 0.72, 1.0)
@export var death_arc_color: Color = Color(0.92, 0.96, 1.0, 1.0)
