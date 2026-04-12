shader_type canvas_item;
// Iron asteroid — dry, dense, matte metallic rock.
// Hard plate-cell structure, ridged rocky texture, dormant buried traces.
// Palette: near-black iron → charcoal → iron gray. Matte, no wet highlights.

uniform float hp_ratio   : hint_range(0.0, 1.0) = 1.0;
uniform float hit_flash  : hint_range(0.0, 1.0) = 0.0;
uniform float rand_seed  : hint_range(0.0, 100.0) = 0.0;
uniform float size_factor: hint_range(0.0, 1.0) = 0.5;  // 0=small  1=large

// ── Helpers ────────────────────────────────────────────────────────────────────

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

// Voronoi returning (F2-F1 edge distance, nearest-cell hash).
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
	// Second seed vector — different phase so systems don't correlate
	vec2  seed3  = vec2(rand_seed * 0.853, rand_seed * 0.241);
	float damage  = 1.0 - hp_ratio;

	// ── Per-asteroid character values ───────────────────────────────────────────
	// These scalars are stable per instance (derived from rand_seed only).
	// They ensure plate layout, crack flow, and dark/light balance all differ.
	float ast_dark_bias  = fract(rand_seed * 0.543) * 0.22 - 0.11;  // -0.11..+0.11
	float ast_tilt_scale = 0.16 + fract(rand_seed * 0.271) * 0.20;  // 0.16..0.36
	float ast_plate_var  = fract(rand_seed * 0.137) * 1.20;          // 0..1.2 freq add
	// Unique AO direction per asteroid — rotates the fake shading gradient
	float ao_angle  = fract(rand_seed * 0.173) * 6.2832;
	vec2  ao_dir    = vec2(cos(ao_angle), sin(ao_angle));

	// ── Irregular silhouette ────────────────────────────────────────────────────
	float sh_large = fbm2(uv * 2.2 + seed2)           - 0.50;
	float sh_med   = vnoise(uv * 5.8 + seed2 + 1.3)   - 0.50;
	float sh_fine  = vnoise(uv * 12.5 + seed2 + 2.8)  - 0.50;
	float shape_disp = sh_large * 0.13 + sh_med * 0.07 + sh_fine * 0.03;
	float eff_dist   = length(uv) * 2.0 + shape_disp;

	if (eff_dist > 1.04) discard;
	float dist = length(uv) * 2.0;

	// ── Plate structure ──────────────────────────────────────────────────────────
	// Frequency varies per asteroid (ast_plate_var) and by size:
	//   small → 2–3 large plates (readable),  large → 5–7 detailed plates.
	float plate_freq = 2.4 + size_factor * 2.0 + ast_plate_var;
	// Rotate plate UV per asteroid so the voronoi grain runs differently each time
	float prot       = fract(rand_seed * 0.431) * 6.2832;
	vec2  puv        = vec2(uv.x * cos(prot) - uv.y * sin(prot),
	                        uv.x * sin(prot) + uv.y * cos(prot));
	vec2  plate_data = voronoi_cell(puv * plate_freq + seed2 * 0.65);
	float plate_edge = plate_data.x;
	float plate_id   = plate_data.y;

	// Irregular seam width: noise shifts the smoothstep threshold locally.
	// Produces non-uniform, slightly jagged plate boundaries.
	float seam_var = vnoise(uv * 17.0 + seed3) * 0.10 - 0.05;
	float seam = 1.0 - smoothstep(0.07 + seam_var, 0.22 + seam_var, plate_edge);

	// Per-plate tilt: drives different facet brightness per plate.
	// Magnitude (ast_tilt_scale) and bias (ast_dark_bias) vary per asteroid
	// so some asteroids are overall darker/lighter than others.
	float plate_tilt = (plate_id - 0.5 + ast_dark_bias * 0.4) * ast_tilt_scale;

	// ── Surface noise ────────────────────────────────────────────────────────────
	float surf1 = vnoise(uv * 6.5  + seed2);
	float surf2 = vnoise(uv * 13.0 + seed2 * 1.4 + vec2(1.2, 0.8));
	float rough  = vnoise(uv * 30.0 + seed2 * 0.9 + vec2(2.4, 1.7));

	// Ridged: abs(n*2-1) → angular ridges rather than smooth blobs.
	float ridge = 1.0 - abs(vnoise(uv * 9.5 + seed2 + vec2(4.8, 2.1)) * 2.0 - 1.0);

	// Large-scale irregular variation — rotated per asteroid for asymmetry.
	// Creates uneven shading transitions and non-repeating surface gradients.
	float macro = vnoise(uv * 1.4 + seed3 * 0.7);   // 0..1, very slow

	// Fake directional AO: simple dot product with per-asteroid ao_dir.
	// Gives one hemisphere subtly lighter and the other darker — like a
	// very soft distant light source. Direction differs per instance.
	float ao_dot   = dot(normalize(uv + vec2(0.001)), ao_dir) * 0.5 + 0.5;
	float light_ao = mix(0.74, 1.0, ao_dot);  // shadow side 74%, light side 100%

	// ── Matte color palette — no wet / glossy values ─────────────────────────────
	// All values well below 0.5. Silver-bright → dry rough iron highlight.
	vec3 iron_deep   = vec3(0.048, 0.046, 0.052);   // dense black iron
	vec3 charcoal    = vec3(0.090, 0.090, 0.095);   // compressed charcoal
	vec3 iron_mid    = vec3(0.220, 0.220, 0.232);   // dry medium iron
	vec3 iron_lift   = vec3(0.305, 0.305, 0.320);   // matte raised facet (was iron_bright)
	vec3 iron_hi     = vec3(0.370, 0.370, 0.388);   // driest highlight (replaces silver)

	// ── Base color: faceted hard transitions ─────────────────────────────────────
	// The macro term shifts the step threshold across the surface unevenly.
	float base_thresh_lo = 0.26 + macro * 0.12 + ast_dark_bias * 0.08;
	float base_thresh_hi = 0.62 + macro * 0.10 + ast_dark_bias * 0.06;
	float base_t = smoothstep(base_thresh_lo, base_thresh_hi, surf1 + plate_tilt * 0.55);
	vec3  base   = mix(iron_deep, iron_mid, base_t);

	// Dense iron-rich patches (inclusions): where surf1 AND ridge both dip.
	float patch = smoothstep(0.44, 0.20, surf1) * smoothstep(0.52, 0.18, ridge);
	base = mix(base, iron_deep, patch * 0.70);

	// Raised facets (plate interiors, not seams).
	// Heavily attenuated compared to previous version — matte, not glossy.
	float plate_inside = 1.0 - seam;
	float facet_t      = smoothstep(0.52, 0.84, surf1 + plate_tilt * 0.45);
	float facet_mask   = plate_inside * facet_t;
	base = mix(base, iron_lift, facet_mask * 0.36);

	// Dry highlight: restricted to the very brightest facets only.
	// Threshold pushed high so it appears on maybe 10–15% of surface.
	float hi_cond = smoothstep(0.74, 0.97, surf2 + plate_tilt * 0.25)
	              * facet_mask
	              * smoothstep(0.72, 0.96, surf1);
	base = mix(base, iron_hi, hi_cond * 0.13);   // was silver * 0.30 — now 0.13

	// Seam: deep compressed dark joint
	base = mix(base, iron_deep * 0.70, seam * 0.65);

	// Micro roughness
	base *= 0.84 + rough * 0.18;

	// Apply directional AO gradient
	base *= light_ao;

	// ── Dents / compressed plate formations (medium + large only) ────────────────
	float dent_str = smoothstep(0.25, 0.72, size_factor);
	if (dent_str > 0.005) {
		float dent_freq = 1.6 + size_factor * 1.6;
		vec2  dent_data = voronoi_cell(uv * dent_freq + seed3 * 1.0 + vec2(4.3, 6.9));
		float dent_sel   = smoothstep(0.40, 0.10, dent_data.y);
		// Shadow inside dent — deeper than before
		float dent_depth = smoothstep(0.38, 0.10, dent_data.x) * dent_sel;
		// Slight raised lip
		float dent_rim   = smoothstep(0.10, 0.26, dent_data.x)
		                 * smoothstep(0.40, 0.26, dent_data.x) * dent_sel;
		base = mix(base, iron_deep * 0.55, dent_depth * dent_str * 0.50);
		base = mix(base, iron_lift  * 0.65, dent_rim   * dent_str * 0.18);
	}

	// ── Strong dark regions for small asteroids (readability) ────────────────────
	// 1–2 broad dark blobs give small sprites a clear, readable silhouette.
	// Fades out as size_factor rises so large asteroids keep fine plate detail.
	float small_str = smoothstep(0.32, 0.0, size_factor);
	if (small_str > 0.005) {
		// Two overlapping low-frequency blobs at per-asteroid offsets
		float blob1 = vnoise(uv * 2.1 + seed2 * 1.6 + vec2(1.4, 3.8));
		float blob2 = vnoise(uv * 1.7 + seed3 * 1.3 + vec2(4.9, 1.2));
		float dark_region = smoothstep(0.58, 0.28, blob1) * smoothstep(0.54, 0.30, blob2);
		base = mix(base, iron_deep, dark_region * small_str * 0.65);
	}

	// ── Domain warping (shared path for dormant traces and damage cracks) ────────
	vec2 warp1 = vec2(
		vnoise(uv * 3.8 + seed2),
		vnoise(uv * 3.8 + seed2 + vec2(4.1, 2.3))
	) * 0.44 - 0.22;
	vec2 wp1   = uv + warp1;
	// Warp 2 uses seed3 so crack flow direction differs per asteroid
	vec2 warp2 = vec2(
		vnoise(wp1 * 6.5 + seed3 * 1.3 + vec2(1.7, 5.5)),
		vnoise(wp1 * 6.5 + seed3 * 0.8 + vec2(6.3, 2.1))
	) * 0.18 - 0.09;
	vec2 crk_uv = uv + warp1 + warp2;

	// ── Dormant energy traces (buried, barely visible when undamaged) ────────────
	float dorm_ve   = voronoi_edge(crk_uv * 7.8 + seed2 * 0.55 + vec2(9.1, 5.3));
	float dorm_line = smoothstep(0.038, 0.0, dorm_ve);
	// At full HP: faint dark depression.  At max damage: slightly more visible.
	float dorm_dark = dorm_line * (0.05 + damage * 0.07);
	base = mix(base, iron_deep, dorm_dark);

	// ── Active crack network ──────────────────────────────────────────────────────
	float ve1 = voronoi_edge(crk_uv * 3.8 + seed2 * 0.35);
	float ve2 = voronoi_edge(crk_uv * 2.3 + seed2 * 1.10 + vec2(5.5, 3.4));

	float crack1 = smoothstep(0.14, 0.0, ve1);
	float crack2 = smoothstep(0.11, 0.0, ve2) * 0.70;
	float cracks  = max(crack1, crack2);

	float core_crack_boost = max(0.0, 1.0 - dist * 2.0) * 0.4 + 1.0;
	cracks *= core_crack_boost;

	float crack_vis = damage * damage * 0.88 + damage * 0.12;
	cracks *= crack_vis;

	float halo = max(
		smoothstep(0.40, 0.0, ve1),
		smoothstep(0.32, 0.0, ve2) * 0.75
	) * crack_vis * 0.28;

	// ── Inner core glow ───────────────────────────────────────────────────────────
	float core_fall = max(0.0, 1.0 - dist * 1.20);
	float core_glow = core_fall * core_fall * damage * 0.22;
	vec3  core_col  = vec3(0.78, 0.76, 0.72);
	vec3  crack_col = vec3(0.82, 0.80, 0.76);

	// ── Rim light — soft, cool-toned, thin edge only ──────────────────────────────
	// smoothstep starts at 0.64 so it only catches the outer ~18% of the disc.
	// Colors are cool gray (slight blue-shift) and very dim — pure silhouette aid.
	float rim     = smoothstep(0.64, 0.98, dist);
	float rim_dir = dot(normalize(uv + vec2(0.12, -0.18)), vec2(0.50, -0.50)) * 0.5 + 0.5;
	vec3  rim_col = mix(vec3(0.05, 0.06, 0.09), vec3(0.18, 0.20, 0.26), rim_dir);

	// ── Flicker (only at low HP) ───────────────────────────────────────────────────
	float flicker_amt = damage * damage * 0.08;
	float flicker = 1.0
		+ sin(TIME * 23.0 + rand_seed * 6.28) * flicker_amt
		+ sin(TIME * 41.0 + rand_seed * 3.14) * flicker_amt * 0.45;

	// ── Combine ────────────────────────────────────────────────────────────────────
	vec3 col = base;
	col += crack_col * (cracks * (0.45 + damage * 0.65)) * flicker;
	col += crack_col * halo;
	col += core_col  * core_glow;
	col += rim_col   * rim;
	col *= flicker;

	// ── Hit flash ─────────────────────────────────────────────────────────────────
	col = mix(col, vec3(0.90, 0.90, 0.92), hit_flash * 0.65);

	// ── Alpha ──────────────────────────────────────────────────────────────────────
	float alpha = smoothstep(1.04, 0.87, eff_dist);

	COLOR = vec4(col, alpha);
}
