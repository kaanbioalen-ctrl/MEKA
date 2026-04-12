shader_type canvas_item;
render_mode blend_mix;

// ── Alan şekli ────────────────────────────────────────────────────────────────
uniform float ring_radius       : hint_range(10.0, 1000.0) = 100.0;
uniform float edge_thickness    : hint_range(0.5,  20.0)   = 4.5;

// ── İç alan ───────────────────────────────────────────────────────────────────
// Hafif karanlık dolgu — mevcut arka planı kısmen kararatır (gravity well hissi)
uniform float fill_opacity      : hint_range(0.0, 0.40)    = 0.07;

// ── Halka dalgaları (içe doğru hareket eder) ──────────────────────────────────
uniform float wave_count        : hint_range(1.0, 12.0)    = 5.0;
uniform float wave_speed        : hint_range(0.0, 10.0)    = 2.8;
uniform float wave_sharpness    : hint_range(1.0, 8.0)     = 3.5;  // yüksek = ince keskin halkalar
uniform float wave_opacity      : hint_range(0.0,  0.8)    = 0.28;

// ── Organik gürültü ───────────────────────────────────────────────────────────
uniform float noise_scale       : hint_range(0.5,  8.0)    = 3.2;
uniform float noise_speed       : hint_range(0.0,  3.0)    = 0.28;
uniform float noise_warp        : hint_range(0.0,  0.5)    = 0.13; // halka konumunu bozar

// ── Renkler ───────────────────────────────────────────────────────────────────
uniform vec4 inner_tint  : source_color = vec4(0.08, 0.28, 0.55, 1.0); // karanlık mavi dolgu
uniform vec4 wave_tint   : source_color = vec4(0.35, 0.78, 1.00, 1.0); // halka rengi
uniform vec4 edge_tint   : source_color = vec4(0.60, 0.92, 1.00, 1.0); // kenar rengi

// ── Kenar parlaması ───────────────────────────────────────────────────────────
uniform float edge_opacity      : hint_range(0.0,  1.0)    = 0.65;
uniform float edge_glow_strength: hint_range(0.0,  5.0)    = 1.8;

// ─────────────────────────────────────────────────────────────────────────────
// Gürültü
// ─────────────────────────────────────────────────────────────────────────────
float _h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float _vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_h(i),                   _h(i + vec2(1.0, 0.0)), f.x),
		mix(_h(i + vec2(0.0, 1.0)),  _h(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// ─────────────────────────────────────────────────────────────────────────────
void fragment() {
	vec2  uvc   = UV - 0.5;
	float raw_d = length(uvc) * 2.0;
	float bf    = edge_thickness / ring_radius;

	float outer_limit = 1.0 + bf * (edge_glow_strength + 0.4);
	if (raw_d >= outer_limit) { COLOR = vec4(0.0); return; }

	// ── Alan içi ─────────────────────────────────────────────────────────────
	if (raw_d < 1.0) {
		// Gürültü ile halka konumunu hafifçe boz (organik his)
		vec2  nc    = UV * noise_scale + TIME * noise_speed;
		float nx    = _vn(nc)                        - 0.5;
		float ny    = _vn(nc.yx + vec2(5.17, 1.31)) - 0.5;
		// Merkeze yakın daha az, kenara yakın daha fazla bozulma
		float warp  = (nx + ny) * noise_warp * smoothstep(0.05, 0.9, raw_d);
		float wd    = clamp(raw_d + warp, 0.0, 1.0);

		// İçe doğru hareket eden halkalar
		// +TIME → faz artar → dalga frontları içe doğru kayar
		float phase = wd * wave_count * TAU + TIME * wave_speed;
		float ring  = sin(phase) * 0.5 + 0.5;              // 0..1
		ring        = pow(ring, wave_sharpness);             // keskin halkalar

		// Kenara yakın halkalar daha belirgin, merkez soluk (player görünsün)
		float radial = smoothstep(0.04, 0.75, raw_d);
		float ring_a = ring * wave_opacity * radial;

		// Hafif karanlık dolgu (gravity well — arka planı biraz kararatır)
		float fill_a = fill_opacity * smoothstep(0.0, 0.8, raw_d);

		// Kenar sınırında rengi edge_tint'e kır
		float etb = smoothstep(0.62, 1.0, raw_d);

		// Renk: karanlık iç + halka parlaması + kenar geçişi
		vec3 col = mix(inner_tint.rgb, wave_tint.rgb, ring * 0.72);
		col       = mix(col, edge_tint.rgb, etb * 0.40);

		float total_a = clamp(fill_a + ring_a, 0.0, 0.82);

		COLOR = vec4(col, total_a);
		return;
	}

	// ── Dış kenar parlaması ───────────────────────────────────────────────────
	float d_beyond  = raw_d - 1.0;
	float border_m  = smoothstep(bf * 1.2, 0.0, d_beyond);
	float brd_noise = _vn(UV * noise_scale * 2.3 + TIME * noise_speed * 0.7) * 0.15 + 0.85;
	float border_a  = border_m * edge_opacity * brd_noise;

	float g_decay = bf * max(0.25, edge_glow_strength * 0.48);
	float glow_a  = exp(-d_beyond / (g_decay + 0.001)) * edge_opacity * 0.28;
	glow_a       *= smoothstep(outer_limit, 1.0 + bf * 0.5, raw_d);

	COLOR = vec4(edge_tint.rgb, clamp(border_a + glow_a, 0.0, 0.95));
}
