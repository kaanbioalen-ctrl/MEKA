shader_type canvas_item;
render_mode blend_mix;

// ── Field shape ────────────────────────────────────────────────────────────────
// ring_radius must equal the MeshInstance2D scale.x set by mining_field_visual.gd
uniform float ring_radius        : hint_range(10.0, 1000.0) = 160.0;
uniform float border_thickness   : hint_range(0.5, 20.0)    = 5.0;
uniform float field_opacity      : hint_range(0.0, 1.0)     = 0.08;
uniform float edge_opacity       : hint_range(0.0, 1.0)     = 0.65;
uniform float edge_glow_strength : hint_range(0.0, 5.0)     = 1.8;
uniform float inner_falloff      : hint_range(0.05, 2.0)    = 0.70;

// ── Colour ─────────────────────────────────────────────────────────────────────
uniform vec4 base_tint : source_color = vec4(0.18, 0.72, 0.95, 1.0);
uniform vec4 edge_tint : source_color = vec4(0.72, 0.94, 1.00, 1.0);

// ── Distortion / noise ─────────────────────────────────────────────────────────
uniform float distortion_strength : hint_range(0.0,  0.15) = 0.032;
uniform float distortion_speed    : hint_range(0.0,  5.0)  = 0.65;
uniform float noise_scale         : hint_range(0.5, 12.0)  = 3.5;
uniform float noise_scroll_speed  : hint_range(0.0,  3.0)  = 0.30;

// ── Damage ripple ──────────────────────────────────────────────────────────────
uniform float ripple_time       : hint_range(-1.0, 30.0)  = -1.0; // -1 = inactive
uniform float ripple_strength   : hint_range(0.0,  2.0)   = 0.60;
uniform float ripple_speed      : hint_range(1.0, 20.0)   = 7.5;
uniform float ripple_width      : hint_range(0.02, 0.5)   = 0.14;
uniform float ripple_fade_speed : hint_range(0.5,  8.0)   = 3.0;
uniform float damage_flash_amount : hint_range(0.0, 1.0)  = 0.0;
uniform vec4  damage_tint_shift : source_color = vec4(1.0, 0.28, 0.18, 1.0);

// ──────────────────────────────────────────────────────────────────────────────
// Noise helpers
// ──────────────────────────────────────────────────────────────────────────────

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, output 0..1
float _vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep
	return mix(
		mix(_hash(i),                 _hash(i + vec2(1.0, 0.0)), f.x),
		mix(_hash(i + vec2(0.0, 1.0)), _hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// 3-octave FBM, output approx 0..1
float _fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * _vnoise(p);
		p  *= 2.1;
		a  *= 0.48;
	}
	return v / 0.97; // roughly normalise to 0..1
}

// ──────────────────────────────────────────────────────────────────────────────
void fragment() {
	// ── Radial coordinates ────────────────────────────────────────────────────
	// UV: (0.5,0.5) = node origin (player centre).
	// raw_d = 0 at centre, 1.0 at field edge, >1 outside.
	vec2  uvc   = UV - 0.5;
	float raw_d = length(uvc) * 2.0;
	float bf    = border_thickness / ring_radius; // border width in UV fraction

	// Hard early-exit for fully transparent exterior
	if (raw_d > 1.0 + bf * (edge_glow_strength * 1.4 + 0.5)) {
		COLOR = vec4(0.0);
		return;
	}

	// ── Noise basis ───────────────────────────────────────────────────────────
	vec2 scroll = vec2(
		TIME * noise_scroll_speed * 0.70,
		TIME * noise_scroll_speed * 0.45
	);
	vec2 nc = UV * noise_scale + scroll;

	// Three independent noise samples for texture variation
	float n1 = _vnoise(nc);
	float n2 = _vnoise(nc * 1.85 + vec2(3.14, 1.59));
	float n3 = _fbm(nc * 0.60 + TIME * distortion_speed * 0.07);
	float tex = clamp(n1 * 0.40 + n2 * 0.28 + n3 * 0.32, 0.0, 1.0);

	// Displacement vector: two orthogonal FBM samples
	float dx = _fbm(nc              + TIME * distortion_speed * 0.11) - 0.5;
	float dy = _fbm(nc.yx + vec2(5.2, 1.3) + TIME * distortion_speed * 0.09) - 0.5;
	// Displacement fades toward the field edge so the border stays clean
	vec2  disp     = vec2(dx, dy) * distortion_strength * smoothstep(1.0, 0.0, raw_d);
	float warped_d = length(uvc + disp) * 2.0;

	// ── Damage ripple ─────────────────────────────────────────────────────────
	float ripple_add_a  = 0.0;
	float ripple_warp   = 0.0;
	if (ripple_time >= 0.0) {
		float fade   = exp(-ripple_time * ripple_fade_speed);
		float front  = clamp(ripple_time * ripple_speed, 0.0, 1.05);
		float dw     = abs(raw_d - front);
		float wave_m = smoothstep(ripple_width, 0.0, dw) * fade;
		ripple_add_a = wave_m * ripple_strength;
		// Tiny warp at the wavefront
		ripple_warp  = wave_m * 0.025 * sign(raw_d - front) * fade;
	}
	warped_d = clamp(warped_d + ripple_warp, 0.0, 2.0);

	// ── Layer alphas ──────────────────────────────────────────────────────────

	// Inner fill: use warped distance for the living-distortion illusion.
	// Falloff ramp: near-zero at centre, builds up toward the edge.
	float inside_m    = smoothstep(1.0, 0.95, warped_d);
	float radial_ramp = pow(clamp(warped_d, 0.0, 1.0), inner_falloff);
	float inner_tex   = tex * 0.45 + 0.55;
	float inner_a     = inside_m * radial_ramp * inner_tex * field_opacity;

	// Border band centred on raw_d == 1.0 (not warped — keeps it crisp).
	float d_to_border  = abs(raw_d - 1.0);
	float border_m     = smoothstep(bf * 1.3, 0.0, d_to_border);
	// Subtle animated break-up on the border
	float brd_noise    = _vnoise(UV * noise_scale * 2.4 + scroll * 1.8) * 0.22 + 0.78;
	// Micro-pulse traveling around the ring
	float bpulse       = sin(raw_d * 14.0 - TIME * 2.1) * 0.06 + 0.94;
	float border_a     = border_m * edge_opacity * brd_noise * bpulse;

	// Outer glow — exponential falloff beyond the border
	float beyond  = max(0.0, raw_d - 1.0);
	float g_decay = bf * max(0.3, edge_glow_strength * 0.5);
	float glow_a  = exp(-beyond / (g_decay + 0.001)) * edge_opacity * 0.28;
	glow_a       *= smoothstep(1.0 + bf * edge_glow_strength * 2.2, 1.0, raw_d);

	// ── Ripple contributions ──────────────────────────────────────────────────
	inner_a  = min(1.0, inner_a  + ripple_add_a * 0.22);
	border_a = min(1.0, border_a + ripple_add_a * 0.50);
	glow_a   = min(1.0, glow_a   + ripple_add_a * 0.28);

	// ── Colours ───────────────────────────────────────────────────────────────
	float fl = damage_flash_amount;

	vec3 c_inner  = mix(base_tint.rgb, damage_tint_shift.rgb, fl * 0.38);
	vec3 c_border = mix(
		mix(base_tint.rgb, edge_tint.rgb, 0.78),
		damage_tint_shift.rgb, fl * 0.62
	);
	vec3 c_glow   = mix(edge_tint.rgb, damage_tint_shift.rgb, fl * 0.50);

	// Ripple brightens inner and border
	c_inner  = mix(c_inner,  mix(edge_tint.rgb, vec3(1.0), 0.20), ripple_add_a * 0.35);
	c_border = mix(c_border, vec3(1.0),                            ripple_add_a * 0.30);

	// Subtle noise tint inside the field for extra life
	c_inner = mix(c_inner, edge_tint.rgb, tex * 0.18);

	// ── Compose ───────────────────────────────────────────────────────────────
	float sum = inner_a + border_a + glow_a + 0.0001;
	vec3  col = (c_inner * inner_a + c_border * border_a + c_glow * glow_a) / sum;

	float total_a = clamp(inner_a + border_a + glow_a + fl * 0.16, 0.0, 0.97);

	COLOR = vec4(col, total_a);
}
