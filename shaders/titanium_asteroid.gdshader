shader_type canvas_item;
// Titanium asteroid:
// Uses the same matte iron-rock body logic as the regular asteroid surface,
// but damage exposes cool titanium energy in the crack network.

uniform float hp_ratio   : hint_range(0.0, 1.0) = 1.0;
uniform float hit_flash  : hint_range(0.0, 1.0) = 0.0;
uniform float rand_seed  : hint_range(0.0, 100.0) = 0.0;
uniform float size_factor: hint_range(0.0, 1.0) = 0.5;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.27);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i),                  hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm2(vec2 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.1 + vec2(3.7, 1.9)) * 0.35;
}

vec2 voronoi_cell(vec2 p) {
	vec2  cell = floor(p);
	vec2  f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float best = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = hash22(cell + n) * 0.78 + 0.11 + n;
			float d = length(f - pt);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				best = hash21(cell + n);
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f2 - f1, best);
}

float voronoi_edge(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = hash22(cell + n) * 0.78 + 0.11 + n;
			float d = length(f - pt);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return f2 - f1;
}

void fragment() {
	vec2 uv = UV - 0.5;
	vec2 seed2 = vec2(rand_seed * 0.371, rand_seed * 0.619);
	vec2 seed3 = vec2(rand_seed * 0.853, rand_seed * 0.241);
	float damage = 1.0 - hp_ratio;

	float ast_dark_bias = fract(rand_seed * 0.543) * 0.22 - 0.11;
	float ast_tilt_scale = 0.16 + fract(rand_seed * 0.271) * 0.20;
	float ast_plate_var = fract(rand_seed * 0.137) * 1.20;
	float ao_angle = fract(rand_seed * 0.173) * 6.2832;
	vec2 ao_dir = vec2(cos(ao_angle), sin(ao_angle));

	float sh_large = fbm2(uv * 2.2 + seed2) - 0.50;
	float sh_med = vnoise(uv * 5.8 + seed2 + 1.3) - 0.50;
	float sh_fine = vnoise(uv * 12.5 + seed2 + 2.8) - 0.50;
	float shape_disp = sh_large * 0.13 + sh_med * 0.07 + sh_fine * 0.03;
	float eff_dist = length(uv) * 2.0 + shape_disp;

	if (eff_dist > 1.04) {
		discard;
	}

	float dist = length(uv) * 2.0;
	float plate_freq = 2.4 + size_factor * 2.0 + ast_plate_var;
	float prot = fract(rand_seed * 0.431) * 6.2832;
	vec2 puv = vec2(
		uv.x * cos(prot) - uv.y * sin(prot),
		uv.x * sin(prot) + uv.y * cos(prot)
	);
	vec2 plate_data = voronoi_cell(puv * plate_freq + seed2 * 0.65);
	float plate_edge = plate_data.x;
	float plate_id = plate_data.y;

	float seam_var = vnoise(uv * 17.0 + seed3) * 0.10 - 0.05;
	float seam = 1.0 - smoothstep(0.07 + seam_var, 0.22 + seam_var, plate_edge);
	float plate_tilt = (plate_id - 0.5 + ast_dark_bias * 0.4) * ast_tilt_scale;

	float surf1 = vnoise(uv * 6.5 + seed2);
	float surf2 = vnoise(uv * 13.0 + seed2 * 1.4 + vec2(1.2, 0.8));
	float rough = vnoise(uv * 30.0 + seed2 * 0.9 + vec2(2.4, 1.7));
	float ridge = 1.0 - abs(vnoise(uv * 9.5 + seed2 + vec2(4.8, 2.1)) * 2.0 - 1.0);
	float macro = vnoise(uv * 1.4 + seed3 * 0.7);
	float ao_dot = dot(normalize(uv + vec2(0.001)), ao_dir) * 0.5 + 0.5;
	float light_ao = mix(0.74, 1.0, ao_dot);

	vec3 iron_deep = vec3(0.048, 0.046, 0.052);
	vec3 charcoal = vec3(0.090, 0.090, 0.095);
	vec3 iron_mid = vec3(0.220, 0.220, 0.232);
	vec3 iron_lift = vec3(0.305, 0.305, 0.320);
	vec3 iron_hi = vec3(0.370, 0.370, 0.388);

	float base_thresh_lo = 0.26 + macro * 0.12 + ast_dark_bias * 0.08;
	float base_thresh_hi = 0.62 + macro * 0.10 + ast_dark_bias * 0.06;
	float base_t = smoothstep(base_thresh_lo, base_thresh_hi, surf1 + plate_tilt * 0.55);
	vec3 base = mix(iron_deep, iron_mid, base_t);

	float patch = smoothstep(0.44, 0.20, surf1) * smoothstep(0.52, 0.18, ridge);
	base = mix(base, iron_deep, patch * 0.70);

	float plate_inside = 1.0 - seam;
	float facet_t = smoothstep(0.52, 0.84, surf1 + plate_tilt * 0.45);
	float facet_mask = plate_inside * facet_t;
	base = mix(base, iron_lift, facet_mask * 0.36);

	float hi_cond = smoothstep(0.74, 0.97, surf2 + plate_tilt * 0.25)
		* facet_mask
		* smoothstep(0.72, 0.96, surf1);
	base = mix(base, iron_hi, hi_cond * 0.13);
	base = mix(base, iron_deep * 0.70, seam * 0.65);
	base *= 0.84 + rough * 0.18;
	base *= light_ao;

	float dent_str = smoothstep(0.25, 0.72, size_factor);
	if (dent_str > 0.005) {
		float dent_freq = 1.6 + size_factor * 1.6;
		vec2 dent_data = voronoi_cell(uv * dent_freq + seed3 * 1.0 + vec2(4.3, 6.9));
		float dent_sel = smoothstep(0.40, 0.10, dent_data.y);
		float dent_depth = smoothstep(0.38, 0.10, dent_data.x) * dent_sel;
		float dent_rim = smoothstep(0.10, 0.26, dent_data.x)
			* smoothstep(0.40, 0.26, dent_data.x) * dent_sel;
		base = mix(base, iron_deep * 0.55, dent_depth * dent_str * 0.50);
		base = mix(base, iron_lift * 0.65, dent_rim * dent_str * 0.18);
	}

	float small_str = smoothstep(0.32, 0.0, size_factor);
	if (small_str > 0.005) {
		float blob1 = vnoise(uv * 2.1 + seed2 * 1.6 + vec2(1.4, 3.8));
		float blob2 = vnoise(uv * 1.7 + seed3 * 1.3 + vec2(4.9, 1.2));
		float dark_region = smoothstep(0.58, 0.28, blob1) * smoothstep(0.54, 0.30, blob2);
		base = mix(base, iron_deep, dark_region * small_str * 0.65);
	}

	vec2 warp1 = vec2(
		vnoise(uv * 3.8 + seed2),
		vnoise(uv * 3.8 + seed2 + vec2(4.1, 2.3))
	) * 0.44 - 0.22;
	vec2 wp1 = uv + warp1;
	vec2 warp2 = vec2(
		vnoise(wp1 * 6.5 + seed3 * 1.3 + vec2(1.7, 5.5)),
		vnoise(wp1 * 6.5 + seed3 * 0.8 + vec2(6.3, 2.1))
	) * 0.18 - 0.09;
	vec2 crk_uv = uv + warp1 + warp2;

	float dorm_ve = voronoi_edge(crk_uv * 7.8 + seed2 * 0.55 + vec2(9.1, 5.3));
	float dorm_line = smoothstep(0.038, 0.0, dorm_ve);
	float dorm_dark = dorm_line * (0.05 + damage * 0.07);
	base = mix(base, charcoal, dorm_dark);

	float ve1 = voronoi_edge(crk_uv * 3.8 + seed2 * 0.35);
	float ve2 = voronoi_edge(crk_uv * 2.3 + seed2 * 1.10 + vec2(5.5, 3.4));
	float crack1 = smoothstep(0.14, 0.0, ve1);
	float crack2 = smoothstep(0.11, 0.0, ve2) * 0.70;
	float cracks = max(crack1, crack2);
	float core_crack_boost = max(0.0, 1.0 - dist * 2.0) * 0.4 + 1.0;
	cracks *= core_crack_boost;

	float crack_vis = damage * damage * 0.88 + damage * 0.12;
	cracks *= crack_vis;

	float halo = max(
		smoothstep(0.40, 0.0, ve1),
		smoothstep(0.32, 0.0, ve2) * 0.75
	) * crack_vis * 0.28;

	float core_fall = max(0.0, 1.0 - dist * 1.20);
	float core_glow = core_fall * core_fall * damage * 0.24;
	vec3 core_col = vec3(0.74, 0.90, 1.00);
	vec3 crack_col = vec3(0.58, 0.84, 1.00);
	vec3 halo_col = vec3(0.28, 0.58, 0.88);

	float rim = smoothstep(0.64, 0.98, dist);
	float rim_dir = dot(normalize(uv + vec2(0.12, -0.18)), vec2(0.50, -0.50)) * 0.5 + 0.5;
	vec3 rim_col = mix(vec3(0.03, 0.06, 0.10), vec3(0.15, 0.24, 0.34), rim_dir);

	float flicker_amt = damage * damage * 0.08;
	float flicker = 1.0
		+ sin(TIME * 23.0 + rand_seed * 6.28) * flicker_amt
		+ sin(TIME * 41.0 + rand_seed * 3.14) * flicker_amt * 0.45;

	vec3 col = base;
	col += crack_col * (cracks * (0.48 + damage * 0.70)) * flicker;
	col += halo_col * halo;
	col += core_col * core_glow;
	col += rim_col * rim;
	col *= flicker;
	col = mix(col, vec3(0.86, 0.95, 1.0), hit_flash * 0.65);

	float alpha = smoothstep(1.04, 0.87, eff_dist);
	COLOR = vec4(col, alpha);
}
