shader_type canvas_item;
// Deep mineral space background — cold, heavy, metallic.
// Designed to match dark iron asteroid visuals.
// Palette: near-black → deep space blue → desaturated blue-gray.
// No warm tones, no fantasy nebula colors.

uniform vec2 camera_pos = vec2(0.0, 0.0);

const float ASPECT = 16.0 / 9.0;

// ── Helpers ───────────────────────────────────────────────────────────────────

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.27);
	return fract(p.x * p.y);
}

vec2 fix_aspect(vec2 uv) {
	return vec2(uv.x * ASPECT, uv.y);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i),                  hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Cold, distant star: white-blue tones, precise dot
float star_layer(vec2 uv, float scale, float size, float threshold) {
	vec2  g    = fix_aspect(uv) * scale;
	vec2  cell = floor(g);
	vec2  f    = fract(g) - 0.5;
	float h    = hash21(cell);
	if (h < threshold) return 0.0;
	vec2  spos = vec2(hash21(cell + 7.3), hash21(cell + 13.7)) - 0.5;
	float d    = length(f - spos * 0.8);
	return smoothstep(size, 0.0, d) * h;
}

// ── Fragment ──────────────────────────────────────────────────────────────────

void fragment() {
	vec2 far_uv  = SCREEN_UV + camera_pos * 0.000020;
	vec2 mid_uv  = SCREEN_UV + camera_pos * 0.000055;

	// ── Near-black deep space base — very faint cold blue ─────────────────────
	vec3 col = vec3(0.002, 0.003, 0.009);

	// ── Fine mineral grain / particle noise ───────────────────────────────────
	// Gives the background a rocky, mineral texture vs. soft smooth gas look.
	// Two scales: coarse grain (rock fragments) + fine grain (mineral dust)
	float grain_c = smooth_noise(fix_aspect(far_uv) * 52.0);
	float grain_f = smooth_noise(fix_aspect(far_uv) * 138.0);
	float grain   = grain_c * 0.55 + grain_f * 0.45;
	col += vec3(0.003, 0.004, 0.007) * grain * 0.28;

	// ── Stars — cold, distant, white-blue ─────────────────────────────────────
	// No warm tones. Reduced brightness vs. original. Slightly higher threshold
	// (fewer stars) to leave more empty space between clusters.

	// Far micro-stars (barely visible, very faint)
	float s1 = star_layer(far_uv,        82.0, 0.020, 0.34);
	float s2 = star_layer(far_uv + 0.17, 66.0, 0.017, 0.39);
	col += vec3(0.42, 0.48, 0.66) * s1 * 0.26;
	col += vec3(0.38, 0.44, 0.63) * s2 * 0.22;

	// Mid-distance stars (slightly larger, still cold)
	float s3 = star_layer(mid_uv,        42.0, 0.026, 0.30);
	float s4 = star_layer(mid_uv + 0.33, 34.0, 0.022, 0.35);
	col += vec3(0.56, 0.62, 0.80) * s3 * 0.34;
	col += vec3(0.53, 0.59, 0.77) * s4 * 0.30;

	// ── Center focus — slightly darker gameplay area ────────────────────────────
	// Pushes visual complexity toward the edges.
	// Center is clean and dark so asteroids (objects) read clearly.
	vec2  cvec    = SCREEN_UV - 0.5;
	float cdist   = length(cvec * vec2(1.0, 1.45));
	// Very gentle dip at center (~5% darker) — not aggressive
	float cdip    = smoothstep(0.0, 0.28, cdist) * (1.0 - smoothstep(0.28, 0.60, cdist));
	col          *= 1.0 - cdip * 0.05;
	// ── Vignette — cold, strong edge falloff ───────────────────────────────────
	// Pushes edges very dark so depth gradient reads clearly.
	// Center at 0.65× keeps stars and dust visible; edges at 0.14× near-black.
	vec2  vign_uv = SCREEN_UV * 2.0 - 1.0;
	float vign    = 1.0 - dot(vign_uv * vec2(0.52, 0.74), vign_uv * vec2(0.52, 0.74));
	vign          = clamp(pow(vign, 0.62), 0.0, 1.0);
	col          *= mix(0.14, 0.65, vign);

	COLOR = vec4(col, 1.0);
}
