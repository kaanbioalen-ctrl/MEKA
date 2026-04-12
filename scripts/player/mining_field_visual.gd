extends Node2D
class_name MiningFieldVisual
## Gravitasyonel alan görseli.
## Sprite2D + ShaderMaterial — hint_screen_texture kullanmaz.
## Shader tamamen matematiksel: içe doğru hareket eden halkalar + gravity fill.
##
## Neden hint_screen_texture yok:
##   MilkyWayBg CanvasLayer=-1'de. hint_screen_texture farklı CanvasLayer
##   içeriğini görmez → beyaz kare döndürürdü.
##
## Render sırası:
##   Sprite2D z_index=-1 → VisualRoot (orbs, z=0) bunun üstünde çizilir ✓
##   Alan merkezinde alpha=0 → player orb tam görünür ✓
##
## player.gd arayüzü (değişmez):
##   node.set("radius", value)  →  alan boyutunu günceller
##   node.queue_redraw()        →  zararsız, shader kendisi animasyon yapar
##   node.trigger_ripple()      →  dalga ivmesi

const _SHADER_PATH := "res://shaders/space_warp_field.gdshader"

# ── Inspector ──────────────────────────────────────────────────────────────────

@export_range(10.0, 1000.0, 1.0) var radius: float = 100.0:
	set(v):
		radius = v
		_sync_radius()

# İç alan
@export_range(0.0, 0.40, 0.01) var fill_opacity: float = 0.07

# Dalgalar
@export_range(1.0, 12.0, 0.5)  var wave_count:    float = 5.0
@export_range(0.0, 10.0, 0.1)  var wave_speed:    float = 2.8
@export_range(1.0,  8.0, 0.5)  var wave_sharpness: float = 3.5
@export_range(0.0,  0.8, 0.01) var wave_opacity:  float = 0.28

# Gürültü
@export_range(0.5,  8.0, 0.1)  var noise_scale:   float = 3.2
@export_range(0.0,  3.0, 0.05) var noise_speed:   float = 0.28
@export_range(0.0,  0.5, 0.01) var noise_warp:    float = 0.13

# Renkler
@export var inner_tint: Color = Color(0.08, 0.28, 0.55, 1.0)
@export var wave_tint:  Color = Color(0.35, 0.78, 1.00, 1.0)
@export var edge_tint:  Color = Color(0.60, 0.92, 1.00, 1.0)

# Kenar
@export_range(0.5, 20.0, 0.5)  var edge_thickness:     float = 4.5
@export_range(0.0,  1.0, 0.01) var edge_opacity:        float = 0.65
@export_range(0.0,  5.0, 0.1)  var edge_glow_strength:  float = 1.8

# ── Private ────────────────────────────────────────────────────────────────────

var _sprite:  Sprite2D       = null
var _mat:     ShaderMaterial = null

# trigger_ripple: wave_speed geçici olarak artırılır
var _pulse:   float = 0.0
var _base_spd: float = 0.0
const _PULSE_DECAY := 3.5


func _ready() -> void:
	_base_spd = wave_speed
	_build_visual()
	_push_all_uniforms()


func _build_visual() -> void:
	var shader := load(_SHADER_PATH) as Shader
	if shader == null:
		push_error("MiningFieldVisual: shader bulunamadı: '%s'" % _SHADER_PATH)
		return

	_mat        = ShaderMaterial.new()
	_mat.shader = shader

	# 2×2 beyaz texture.
	# 2×2 texture × scale(R, R) = rendered size (2R × 2R).
	# centered=true → spans (−R,−R)…(+R,+R). UV (0.5,0.5) = merkez ✓
	var img        := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	_sprite          = Sprite2D.new()
	_sprite.texture  = ImageTexture.create_from_image(img)
	_sprite.centered = true
	_sprite.material = _mat
	# z_index=-1 → VisualRoot orb katmanları (z=0) bunun ÜSTÜNDE render edilir
	_sprite.z_index  = -1
	add_child(_sprite)

	_sync_radius()


func _sync_radius() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2(radius, radius)
	if _mat != null:
		_mat.set_shader_parameter("ring_radius", radius)


func _push_all_uniforms() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("ring_radius",        radius)
	_mat.set_shader_parameter("edge_thickness",     edge_thickness)
	_mat.set_shader_parameter("fill_opacity",       fill_opacity)
	_mat.set_shader_parameter("wave_count",         wave_count)
	_mat.set_shader_parameter("wave_speed",         wave_speed)
	_mat.set_shader_parameter("wave_sharpness",     wave_sharpness)
	_mat.set_shader_parameter("wave_opacity",       wave_opacity)
	_mat.set_shader_parameter("noise_scale",        noise_scale)
	_mat.set_shader_parameter("noise_speed",        noise_speed)
	_mat.set_shader_parameter("noise_warp",         noise_warp)
	_mat.set_shader_parameter("inner_tint",         inner_tint)
	_mat.set_shader_parameter("wave_tint",          wave_tint)
	_mat.set_shader_parameter("edge_tint",          edge_tint)
	_mat.set_shader_parameter("edge_opacity",       edge_opacity)
	_mat.set_shader_parameter("edge_glow_strength", edge_glow_strength)


## player.gd tarafından çağrılabilir — kısa süreli dalga hızlanması.
func trigger_ripple() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	if _pulse > 0.0 and _mat != null:
		_pulse = maxf(0.0, _pulse - delta * _PULSE_DECAY)
		_mat.set_shader_parameter("wave_speed",
				lerpf(_base_spd, _base_spd * 3.5, _pulse))
