shader_type canvas_item;
// Gold asteroid — warm stone matrix with buried gold ore veins.
// Same architecture as iron_asteroid.gdshader; material identity is entirely different.
//
// Key visual differences from iron:
//   Rock base  : warm brown/amber stone (not cold iron gray)
//   Ore veins  : always faintly visible — gold ore seams in the matrix (iron hides its traces)
//   Cracks     : glow with molten gold energy when damaged (iron uses cool gray)
//   Core       : radiates intense amber-gold at high damage (iron uses gray-white)
//   Rim        : very faint warm amber hint (iron uses cold blue-gray)
//   Hit flash  : gold-white (iron uses silver-white)

uniform float hp_ratio   : hint_range(0.0, 1.0) = 1.0;
uniform float hit_flash  : hint_range(0.0, 1.0) = 0.0;
uniform float rand_seed  : hint_range(0.0, 100.0) = 0.0;
uniform float size_factor: hint_range(0.0, 1.0) = 0.5;  // 0=small  1=large

// ── Helpers (identical to iron_asteroid) ──────────────────────────────────────

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
	vec2  f    = fract(p);
	float f1   = 8.0, f2 = 8.0;
	float best = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2  n  = vec2(float(x), float(y));
			vec2  pt = hash22(cell + n) * 0.78 + 0.11 + n;
			float d  = length(f - pt);
			if (d < f1) { f2 = f1; f1 = d; best = hash21(cell + n); }
			else if (d < f2) { f2 = d; }
		}
	}
	return vec2(f2 - f1, best);
}

float voronoi_edge(vec2 p) {
	vec2  cell = floor(p);
	vec2  f    = fract(p);
	float f1   = 8.0, f2 = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2  n  = vec2(float(x), float(y));
			vec2  pt = hash22(cell + n) * 0.78 + 0.11 + n;
			float d  = length(f - pt);
			if (d < f1) { f2 = f1; f1 = d; }
			else if (d < f2) { f2 = d; }
		}
	}
	return f2 - f1;
}

// ── Fragment ───────────────────────────────────────────────────────────────────

void fragment() {
	vec2  uv     = UV - 0.5;
	vec2  seed2  = vec2(rand_seed * 0.371, rand_seed * 0.619);
	vec2  seed3  = vec2(rand_seed * 0.853, rand_seed * 0.241);
	float damage  = 1.0 - hp_ratio;

	// ── Per-asteroid character (same derivation as iron) ───────────────────────
	float ast_dark_bias  = fract(rand_seed * 0.543) * 0.22 - 0.11;
	float ast_tilt_scale = 0.16 + fract(rand_seed * 0.271) * 0.20;
	float ast_plate_var  = fract(rand_seed * 0.137) * 1.20;
	float ao_angle  = fract(rand_seed * 0.173) * 6.2832;
	vec2  ao_dir    = vec2(cos(ao_angle), sin(ao_angle));

	// ── Irregular silhouette ───────────────────────────────────────────────────
	float sh_large   = fbm2(uv * 2.2 + seed2)           - 0.50;
	float sh_med     = vnoise(uv * 5.8 + seed2 + 1.3)   - 0.50;
	float sh_fine    = vnoise(uv * 12.5 + seed2 + 2.8)  - 0.50;
	float shape_disp = sh_large * 0.13 + sh_med * 0.07 + sh_fine * 0.03;
	float eff_dist   = length(uv) * 2.0 + shape_disp;

	if (eff_dist > 1.04) discard;
	float dist = length(uv) * 2.0;

	// ── Plate structure ────────────────────────────────────────────────────────
	float plate_freq = 2.4 + size_factor * 2.0 + ast_plate_var;
	float prot       = fract(rand_seed * 0.431) * 6.2832;
	vec2  puv        = vec2(uv.x * cos(prot) - uv.y * sin(prot),
	                        uv.x * sin(prot) + uv.y * cos(prot));
	vec2  plate_data = voronoi_cell(puv * plate_freq + seed2 * 0.65);
	float plate_edge = plate_data.x;
	float plate_id   = plate_data.y;

	float seam_var = vnoise(uv * 17.0 + seed3) * 0.10 - 0.05;
	float seam     = 1.0 - smoothstep(0.07 + seam_var, 0.22 + seam_var, plate_edge);
	float plate_tilt = (plate_id - 0.5 + ast_dark_bias * 0.4) * ast_tilt_scale;

	// ── Surface noise ──────────────────────────────────────────────────────────
	float surf1 = vnoise(uv * 6.5  + seed2);
	float surf2 = vnoise(uv * 13.0 + seed2 * 1.4 + vec2(1.2, 0.8));
	float rough  = vnoise(uv * 30.0 + seed2 * 0.9 + vec2(2.4, 1.7));
	float ridge  = 1.0 - abs(vnoise(uv * 9.5 + seed2 + vec2(4.8, 2.1)) * 2.0 - 1.0);
	float macro  = vnoise(uv * 1.4 + seed3 * 0.7);
	float ao_dot   = dot(normalize(uv + vec2(0.001)), ao_dir) * 0.5 + 0.5;
	float light_ao = mix(0.74, 1.0, ao_dot);

	// ── Warm stone palette — distinctly different from iron's cold gray ─────────
	// Rock reads as gold-bearing stone matrix: warm brown-black, not iron-gray.
	// All values parallel to iron's brightness levels but shifted warm.
	vec3 rock_deep = vec3(0.052, 0.038, 0.024);   // dense brown-black matrix
	vec3 rock_dark = vec3(0.092, 0.068, 0.040);   // deep warm brown
	vec3 rock_mid  = vec3(0.198, 0.150, 0.088);   // warm stone mid-tone
	vec3 rock_lift = vec3(0.288, 0.218, 0.130);   // raised warm facet
	vec3 rock_hi   = vec3(0.362, 0.278, 0.168);   // driest warm highlight

	// ── Base color: same facet logic as iron, warm tones ─────────────────────
	float base_thresh_lo = 0.26 + macro * 0.12 + ast_dark_bias * 0.08;
	float base_thresh_hi = 0.62 + macro * 0.10 + ast_dark_bias * 0.06;
	float base_t = smoothstep(base_thresh_lo, base_thresh_hi, surf1 + plate_tilt * 0.55);
	vec3  base   = mix(rock_deep, rock_mid, base_t);

	// Dense mineral patches (iron-ore inclusions in the matrix)
	float patch = smoothstep(0.44, 0.20, surf1) * smoothstep(0.52, 0.18, ridge);
	base = mix(base, rock_deep, patch * 0.70);

	// Raised facets
	float plate_inside = 1.0 - seam;
	float facet_t      = smoothstep(0.52, 0.84, surf1 + plate_tilt * 0.45);
	float facet_mask   = plate_inside * facet_t;
	base = mix(base, rock_lift, facet_mask * 0.36);

	// Dry warm highlight (very restricted, only brightest facets)
	float hi_cond = smoothstep(0.74, 0.97, surf2 + plate_tilt * 0.25)
	              * facet_mask
	              * smoothstep(0.72, 0.96, surf1);
	base = mix(base, rock_hi, hi_cond * 0.13);

	// Seam: compressed dark joint (same as iron)
	base = mix(base, rock_deep * 0.70, seam * 0.65);

	// Micro roughness + AO
	base *= 0.84 + rough * 0.18;
	base *= light_ao;

	// ── Dents / plate formations (medium + large only) ─────────────────────────
	float dent_str = smoothstep(0.25, 0.72, size_factor);
	if (dent_str > 0.005) {
		float dent_freq = 1.6 + size_factor * 1.6;
		vec2  dent_data = voronoi_cell(uv * dent_freq + seed3 * 1.0 + vec2(4.3, 6.9));
		float dent_sel   = smoothstep(0.40, 0.10, dent_data.y);
		float dent_depth = smoothstep(0.38, 0.10, dent_data.x) * dent_sel;
		float dent_rim   = smoothstep(0.10, 0.26, dent_data.x)
		                 * smoothstep(0.40, 0.26, dent_data.x) * dent_sel;
		base = mix(base, rock_deep * 0.55, dent_depth * dent_str * 0.50);
		base = mix(base, rock_lift * 0.60, dent_rim   * dent_str * 0.18);
	}

	// ── Strong dark regions for small asteroids ────────────────────────────────
	float small_str = smoothstep(0.32, 0.0, size_factor);
	if (small_str > 0.005) {
		float blob1 = vnoise(uv * 2.1 + seed2 * 1.6 + vec2(1.4, 3.8));
		float blob2 = vnoise(uv * 1.7 + seed3 * 1.3 + vec2(4.9, 1.2));
		float dark_region = smoothstep(0.58, 0.28, blob1) * smoothstep(0.54, 0.30, blob2);
		base = mix(base, rock_deep, dark_region * small_str * 0.65);
	}

	// ── Domain warping (shared path for veins and cracks) ─────────────────────
	vec2 warp1 = vec2(
		vnoise(uv * 3.8 + seed2),
		vnoise(uv * 3.8 + seed2 + vec2(4.1, 2.3))
	) * 0.44 - 0.22;
	vec2 wp1   = uv + warp1;
	vec2 warp2 = vec2(
		vnoise(wp1 * 6.5 + seed3 * 1.3 + vec2(1.7, 5.5)),
		vnoise(wp1 * 6.5 + seed3 * 0.8 + vec2(6.3, 2.1))
	) * 0.18 - 0.09;
	vec2 crk_uv = uv + warp1 + warp2;

	// ── Gold ore veins — KEY DIFFERENCE FROM IRON ─────────────────────────────
	// Iron hides its energy traces (barely visible even at full damage).
	// Gold shows ore seams even when undamaged — this asteroid contains gold,
	// and that gold is physically present in the rock, just contained.
	//
	// At full HP:  faint warm amber seams — ore veins in the stone matrix.
	// As damaged:  veins light up, gold energy flows along existing ore paths.
	// At max damage: vein network blazes with molten gold.
	float vein_ve   = voronoi_edge(crk_uv * 8.8 + seed2 * 0.48 + vec2(3.7, 7.1));
	float vein_line = smoothstep(0.048, 0.0, vein_ve);

	// crack_vis: same quadratic as iron — nearly zero until ~20% damage
	float crack_vis = damage * damage * 0.88 + damage * 0.12;

	// Ambient ore warmth — always present in vein areas (this is the gold in the rock)
	float vein_ambient = vein_line * 0.22;
	// Active energy glow — grows with damage along ore paths
	float vein_energy  = vein_line * crack_vis;

	// Ore vein colors: cool dark amber (undamaged) → bright molten gold (damaged)
	vec3 ore_dark    = vec3(0.48, 0.28, 0.03);   // gold ore in stone (full HP)
	vec3 ore_glow    = vec3(0.96, 0.70, 0.06);   // molten gold stream (damaged)
	// Mix between ore and glow based on damage
	vec3 vein_col    = mix(ore_dark, ore_glow, crack_vis * crack_vis);

	// Apply ambient ore seam (always-on warm tint in vein areas)
	// This is subtle — it should read as "warm rock inclusions", not as glowing strips
	base += ore_dark * vein_ambient * 0.38;

	// ── Active crack network ───────────────────────────────────────────────────
	float ve1 = voronoi_edge(crk_uv * 3.8 + seed2 * 0.35);
	float ve2 = voronoi_edge(crk_uv * 2.3 + seed2 * 1.10 + vec2(5.5, 3.4));

	float crack1 = smoothstep(0.14, 0.0, ve1);
	float crack2 = smoothstep(0.11, 0.0, ve2) * 0.70;
	float cracks  = max(crack1, crack2);

	float core_crack_boost = max(0.0, 1.0 - dist * 2.0) * 0.4 + 1.0;
	cracks *= core_crack_boost;
	cracks *= crack_vis;

	// Crack halo: soft glow around crack lines
	float halo = max(
		smoothstep(0.40, 0.0, ve1),
		smoothstep(0.32, 0.0, ve2) * 0.75
	) * crack_vis * 0.32;

	// ── Gold energy colors ─────────────────────────────────────────────────────
	// crack_col: color of the crack line itself (bright molten gold)
	// halo_col:  softer warm glow around cracks (amber)
	// core_col:  inner radiance of the asteroid at high damage
	vec3 crack_col = vec3(0.98, 0.72, 0.10);    // molten gold crack line
	vec3 halo_col  = mix(vec3(0.55, 0.28, 0.02), vec3(0.90, 0.58, 0.04), crack_vis);

	float core_fall = max(0.0, 1.0 - dist * 1.18);
	float core_glow = core_fall * core_fall * damage * 0.28;
	// Core color: dark amber at low damage → hot gold at high damage
	vec3 core_col   = mix(vec3(0.65, 0.38, 0.02), vec3(1.00, 0.84, 0.30), damage);

	// ── Warm amber rim — very faint, silhouette aid only ─────────────────────
	// Warmer than iron's cold blue-gray rim, but equally subtle.
	float rim     = smoothstep(0.64, 0.98, dist);
	float rim_dir = dot(normalize(uv + vec2(0.12, -0.18)), vec2(0.50, -0.50)) * 0.5 + 0.5;
	vec3  rim_col = mix(vec3(0.06, 0.04, 0.01), vec3(0.20, 0.14, 0.04), rim_dir);

	// ── Flicker (low HP — gold energy becomes unstable) ───────────────────────
	float flicker_amt = damage * damage * 0.09;
	float flicker = 1.0
		+ sin(TIME * 23.0 + rand_seed * 6.28) * flicker_amt
		+ sin(TIME * 41.0 + rand_seed * 3.14) * flicker_amt * 0.45;

	// ── Combine ───────────────────────────────────────────────────────────────
	vec3 col = base;

	// Gold crack energy
	col += crack_col * (cracks * (0.52 + damage * 0.72)) * flicker;
	// Warm halo around cracks (broader glow)
	col += halo_col  * halo;
	// Gold ore vein energy (along existing vein paths, grows with damage)
	col += vein_col  * vein_energy * 0.62 * flicker;
	// Inner core illumination (at high damage, interior radiates)
	col += core_col  * core_glow;
	// Rim
	col += rim_col   * rim;

	col *= flicker;

	// ── Hit flash: gold-white (not silver-white like iron) ────────────────────
	col = mix(col, vec3(0.98, 0.90, 0.55), hit_flash * 0.65);

	// ── Alpha ─────────────────────────────────────────────────────────────────
	float alpha = smoothstep(1.04, 0.87, eff_dist);

	COLOR = vec4(col, alpha);
}
