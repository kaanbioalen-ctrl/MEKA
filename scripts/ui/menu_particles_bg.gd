extends Node2D
## Menü arka planı — Nebula Menu (React/OGL/WebGL) projesinin birebir Godot 4 portudur.
## Kaynak: Particles.tsx + vertex/fragment shader'ları
##
## Orijinal vertex shader mantığı:
##   pos = position * uSpread;  pos.z *= 10.0
##   mPos.x += sin(t * rand.z + 6.28 * rand.w) * mix(0.1, 1.5, rand.x)
##   mPos.y += sin(t * rand.y + 6.28 * rand.x) * mix(0.1, 1.5, rand.w)
##   mPos.z += sin(t * rand.w + 6.28 * rand.y) * mix(0.1, 1.5, rand.z)
##   gl_PointSize = uBaseSize * (1 + sizeRand * (r.x-0.5)) / length(mvPos)
##
## Orijinal fragment shader mantığı:
##   float d = length(uv - vec2(0.5));
##   float circle = smoothstep(0.5, 0.4, d) * 0.8;
##   gl_FragColor = vec4(vColor + 0.2*sin(uv.yxx + uTime + rand.y*6.28), circle);

# ── Ayarlar (App.tsx'teki prop'larla birebir) ──────────────────────────────────

@export_group("Particle Settings")
@export var particle_count:     int   = 500
@export var particle_spread:    float = 12.0   # uSpread — 3D dünya birimi
@export var speed:              float = 0.15
@export var particle_base_size: float = 120.0  # uBaseSize (px, pixel_ratio=1 varsayımıyla)
@export var size_randomness:    float = 1.0    # uSizeRandomness
@export var alpha_particles:    bool  = true   # fragment shader modu
@export var disable_rotation:   bool  = false

@export_group("Interaction")
@export var move_on_hover:   bool  = true
@export var hover_factor:    float = 1.5

# ── İç değişkenler ────────────────────────────────────────────────────────────

# Kamera ayarları (Camera.tsx: fov=15, position.z=20)
const _CAM_Z:   float = 20.0
const _FOV_DEG: float = 15.0

# Renk paleti (App.tsx: #ffffff, #a0a0a0, #606060)
const _PALETTE: Array[Color] = [
	Color(1.000, 1.000, 1.000),
	Color(0.627, 0.627, 0.627),
	Color(0.376, 0.376, 0.376),
]

# Parçacık verisi
var _positions: PackedVector3Array = []  # Birim küre içi 3D koordinatlar
var _randoms:   Array[Vector4]     = []  # Her parçacığın random vec4'ü
var _colors:    Array[Color]       = []  # Palet rengi

# Rotasyon durumu (JS: rotation.x/y/z)
var _rot_x: float = 0.0
var _rot_y: float = 0.0
var _rot_z: float = 0.0

# Hover ofseti (dünya birimi, smooth)
var _hover_x: float = 0.0
var _hover_y: float = 0.0

# Geçen süre — JS'deki elapsed (ms cinsinden başlar, 0.001 ile shader'a verilir)
var _elapsed_ms: float = 0.0

# Precalc: perspektif çarpanı (f = 1/tan(fov/2))
var _f: float = 0.0


func _ready() -> void:
	# Node viewport merkezine — _draw() local koordinatlarda çizer
	var vp := get_viewport_rect().size
	position = vp * 0.5
	_f = 1.0 / tan(deg_to_rad(_FOV_DEG * 0.5))
	_generate_particles()


# ── Parçacık üretimi (JS: positions / randoms / colors döngüsü) ───────────────

func _generate_particles() -> void:
	_positions.clear()
	_randoms.clear()
	_colors.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 4815162342  # Sabit seed — her açılışta tutarlı görünüm

	for _i in range(particle_count):
		# Birim küre içi homojen dağılım (rejection sampling)
		# JS: do { x,y,z = rand*2-1 } while (len>1||len==0)
		var px := 0.0; var py := 0.0; var pz := 0.0
		var len_sq := 0.0
		for _attempt in range(200):
			px = rng.randf() * 2.0 - 1.0
			py = rng.randf() * 2.0 - 1.0
			pz = rng.randf() * 2.0 - 1.0
			len_sq = px*px + py*py + pz*pz
			if len_sq <= 1.0 and len_sq > 0.0:
				break

		# JS: r = Math.cbrt(Math.random()) — küre içini homojen doldurmak için
		var r := pow(rng.randf(), 1.0 / 3.0)
		var inv_len := r / sqrt(len_sq)
		_positions.append(Vector3(px * inv_len, py * inv_len, pz * inv_len))

		# JS: randoms.set([rand,rand,rand,rand])
		_randoms.append(Vector4(rng.randf(), rng.randf(), rng.randf(), rng.randf()))

		# JS: palette[Math.floor(Math.random() * palette.length)]
		_colors.append(_PALETTE[rng.randi() % _PALETTE.size()])


# ── Güncelleme ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# JS: elapsed += delta * speed  (ms biriminde birikir)
	_elapsed_ms += delta * speed * 1000.0

	# JS: rotation.x = sin(elapsed*0.0002)*0.1
	#     rotation.y = cos(elapsed*0.0005)*0.15
	#     rotation.z += 0.01*speed  (frame başına)
	if not disable_rotation:
		_rot_x = sin(_elapsed_ms * 0.0002) * 0.1
		_rot_y = cos(_elapsed_ms * 0.0005) * 0.15
		_rot_z += 0.01 * speed * delta * 60.0  # delta-normalize (60fps referans)

	# Hover — JS: particles.position.x = -mouse.x * hoverFactor
	if move_on_hover:
		var m := get_viewport().get_mouse_position()
		var s := get_viewport().get_visible_rect().size
		var nx :=  ((m.x / s.x) * 2.0 - 1.0)
		var ny := -((m.y / s.y) * 2.0 - 1.0)
		# Smooth geçiş — orijinalde direkt atama, burada lerp daha pürüzsüz görünür
		_hover_x = lerp(_hover_x, -nx * hover_factor, delta * 5.0)
		_hover_y = lerp(_hover_y, -ny * hover_factor, delta * 5.0)
	else:
		_hover_x = lerp(_hover_x, 0.0, delta * 5.0)
		_hover_y = lerp(_hover_y, 0.0, delta * 5.0)

	queue_redraw()


# ── Çizim ─────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var vp    := get_viewport_rect().size
	var half_w := vp.x * 0.5
	var half_h := vp.y * 0.5
	var aspect := vp.x / vp.y

	# uTime — JS: program.uniforms.uTime.value = elapsed * 0.001
	var t := _elapsed_ms * 0.001

	# Rotasyon matrisi — Godot Basis (Euler XYZ)
	var basis := Basis.from_euler(Vector3(_rot_x, _rot_y, _rot_z))

	for i in range(_positions.size()):
		var pos  := _positions[i]
		var rand := _randoms[i]
		var col  := _colors[i]

		# ── Vertex shader: pos = position * uSpread ──────────────────────────
		var wp := Vector3(
			pos.x * particle_spread,
			pos.y * particle_spread,
			pos.z * particle_spread,
		)
		wp.z *= 10.0  # pos.z *= 10.0

		# ── modelMatrix (rotasyon + hover pozisyonu) ─────────────────────────
		var rp := basis * wp
		rp.x += _hover_x
		rp.y += _hover_y

		# ── Sinüs dalgası hareketi (vertex shader'daki mPos += ...) ──────────
		rp.x += sin(t * rand.z + TAU * rand.w) * lerpf(0.1, 1.5, rand.x)
		rp.y += sin(t * rand.y + TAU * rand.x) * lerpf(0.1, 1.5, rand.w)
		rp.z += sin(t * rand.w + TAU * rand.y) * lerpf(0.1, 1.5, rand.z)

		# ── View space: kamera (0,0,_CAM_Z) -Z'ye bakıyor ───────────────────
		# OpenGL view: mvPos = viewMatrix * mPos, viewMatrix = translate(-camPos)
		# view_z negatif (kamera -Z'ye bakar) ama perspektif için pozitif taraf lazım
		var view_z := _CAM_Z - rp.z   # kamera arkasındakileri elek
		if view_z < 0.01:
			continue

		# ── Perspektif projeksiyon ────────────────────────────────────────────
		# ndc = position_view.xy / (-view_z) * f  (OpenGL convention: z negatif)
		# Bizim basitleştirmemiz: view_z zaten pozitif kullanılıyor
		var ndc_x := rp.x / view_z * _f
		var ndc_y := rp.y / view_z * _f

		# Ekran dışı parçacıkları atla
		if absf(ndc_x) > aspect * 1.05 or absf(ndc_y) > 1.05:
			continue

		# NDC → lokal ekran koordinatı (node viewport merkezinde)
		var sx :=  ndc_x * half_w
		var sy := -ndc_y * half_h   # Y ekseni ters

		# ── Nokta boyutu: gl_PointSize = uBaseSize * rand_size / length(mvPos) ─
		var mv_len := sqrt(rp.x*rp.x + rp.y*rp.y + (rp.z - _CAM_Z)*(rp.z - _CAM_Z))
		if mv_len < 0.001:
			mv_len = 0.001
		var size_mult := 1.0 + size_randomness * (rand.x - 0.5)
		var point_diam := (particle_base_size * size_mult) / mv_len
		var radius     := clampf(point_diam * 0.5, 0.5, 15.0)  # max 15px yarıçap = 30px çap

		# ── Fragment shader: renk + shimmer ──────────────────────────────────
		# sin(uv.yxx + uTime + rand.y*6.28) — uv.y ≈ 0.5 merkez için
		var shimmer := sin(0.5 + t + rand.y * TAU) * 0.2
		var fr := clampf(col.r + shimmer, 0.0, 1.0)
		var fg := clampf(col.g + shimmer, 0.0, 1.0)
		var fb := clampf(col.b + shimmer, 0.0, 1.0)

		var screen_pos := Vector2(sx, sy)

		if alpha_particles:
			# smoothstep(0.5, 0.4, d) * 0.8 → core yumuşak, halo soluk
			draw_circle(screen_pos, radius,        Color(fr, fg, fb, 0.92))
			draw_circle(screen_pos, radius * 2.2,  Color(fr, fg, fb, 0.28))
			draw_circle(screen_pos, radius * 4.0,  Color(fr, fg, fb, 0.08))
		else:
			# Solid daire (alphaParticles=false dalı)
			draw_circle(screen_pos, radius, Color(fr, fg, fb, 1.0))
