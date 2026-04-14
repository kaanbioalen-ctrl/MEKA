shader_type canvas_item;
// Sulfur asteroid - dry mineral yellow body with hot sulfur cracks.

uniform float hp_ratio    : hint_range(0.0, 1.0) = 1.0;
uniform float hit_flash   : hint_range(0.0, 1.0) = 0.0;
uniform float rand_seed   : hint_range(0.0, 100.0) = 0.0;
uniform float size_factor : hint_range(0.0, 1.0) = 0.5;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(3.7, 1.9);
		a *= 0.5;
	}
	return v;
}

float ridge_noise(vec2 p) {
	return 1.0 - abs(vnoise(p) * 2.0 - 1.0);
}

void fragment() {
	vec2 uv = UV - 0.5;
	vec2 seed2 = vec2(rand_seed * 0.371, rand_seed * 0.619);
	float damage = 1.0 - hp_ratio;

	float sh_large = fbm2(uv * 2.4 + seed2) - 0.5;
	float sh_med = vnoise(uv * 6.4 + seed2 + 1.7) - 0.5;
	float sh_fine = vnoise(uv * 13.8 + seed2 + 3.2) - 0.5;
	float shape_disp = sh_large * 0.11 + sh_med * 0.06 + sh_fine * 0.025;
	float eff_dist = length(uv) * 2.0 + shape_disp;
	if (eff_dist > 1.04) {
		discard;
	}
	float dist = length(uv) * 2.0;

	float surf1 = vnoise(uv * 5.8 + seed2);
	float surf2 = fbm2(uv * 8.5 + seed2 * 1.3 + vec2(2.0, 0.7));
	float grains = ridge_noise(uv * 16.0 + seed2 * 0.9 + vec2(0.8, 4.1));
	float pockets = vnoise(uv * (2.0 + size_factor * 1.4) + seed2 * 0.6 + vec2(8.1, 3.7));

	vec3 sulfur_deep = vec3(0.22, 0.17, 0.03);
	vec3 sulfur_mid = vec3(0.62, 0.50, 0.08);
	vec3 sulfur_bright = vec3(0.90, 0.76, 0.16);
	vec3 sulfur_hot = vec3(1.00, 0.90, 0.40);
	vec3 sulfur_crack = vec3(1.00, 0.82, 0.18);
	vec3 sulfur_core = vec3(1.00, 0.95, 0.58);
	vec3 sulfur_rim = vec3(0.95, 0.82, 0.20);

	float base_t = smoothstep(0.24, 0.78, surf1 + sh_large * 0.35);
	vec3 base = mix(sulfur_deep, sulfur_mid, base_t);

	float bright_facets = smoothstep(0.60, 0.92, surf2) * (0.65 + grains * 0.35);
	base = mix(base, sulfur_bright, bright_facets * 0.55);

	float crystal_dust = smoothstep(0.48, 0.88, grains);
	base = mix(base, sulfur_hot, crystal_dust * 0.18);

	float pits = smoothstep(0.42, 0.16, pockets);
	base = mix(base, sulfur_deep * 0.72, pits * 0.42);

	vec2 crack_uv = uv + vec2(
		vnoise(uv * 3.8 + seed2 + vec2(4.0, 1.1)),
		vnoise(uv * 3.8 + seed2 + vec2(1.4, 5.3))
	) * 0.18 - 0.09;
	float crack_field = ridge_noise(crack_uv * 7.0 + seed2 * 0.8);
	float crack_field2 = ridge_noise(crack_uv * 12.0 + seed2 * 1.1 + vec2(2.8, 6.1));
	float cracks = smoothstep(0.90, 0.98, crack_field) * 0.75;
	cracks = max(cracks, smoothstep(0.93, 0.992, crack_field2));
	cracks *= damage * damage * 0.92 + damage * 0.12;

	float halo = smoothstep(0.78, 1.0, crack_field) * cracks * 0.85;
	float core_glow = max(0.0, 1.0 - dist * 1.18);
	core_glow = core_glow * core_glow * damage * 0.24;

	float rim = smoothstep(0.68, 0.99, dist);
	float rim_dir = dot(normalize(uv + vec2(0.001)), normalize(vec2(0.55, -0.45))) * 0.5 + 0.5;
	vec3 rim_col = sulfur_rim * mix(0.55, 1.0, rim_dir);

	float flicker_amt = damage * damage * 0.10;
	float flicker = 1.0
		+ sin(TIME * 22.0 + rand_seed * 6.28) * flicker_amt
		+ sin(TIME * 37.0 + rand_seed * 3.14) * flicker_amt * 0.35;

	vec3 col = base;
	col += sulfur_crack * (cracks * (0.52 + damage * 0.70)) * flicker;
	col += sulfur_hot * halo * 0.45;
	col += sulfur_core * core_glow;
	col += rim_col * rim * 0.26;
	col *= flicker;

	col = mix(col, vec3(1.0, 0.96, 0.72), hit_flash * 0.68);

	float alpha = smoothstep(1.04, 0.87, eff_dist);
	COLOR = vec4(col, alpha);
}
