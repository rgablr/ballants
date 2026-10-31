shader_type sky;
// GARDEN SKY -- the painted background behind every garden level, drawn
// entirely in code (no image files): a blue gradient, the sun, soft puffy
// clouds, and on the horizon a hazy neighbourhood -- rolling hills, a row of
// house silhouettes with roofs and chimneys, and clumps of trees between
// them. Everything here is infinitely far away, so it never needs collision
// and can never be mistaken for part of the course.
//
// Heights below are in "sky units": 0 = the horizon, 1 = straight up
// (it is the sine of the angle above the horizon; 0.1 is about 6 degrees).

uniform vec3 top_color : source_color = vec3(0.30, 0.56, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.90, 1.0);
uniform vec3 ground_color : source_color = vec3(0.40, 0.60, 0.32);

uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.82);
uniform float sun_size = 0.045;          // radius of the sun disc (radians)
uniform float sun_glow = 0.35;           // brightness of the halo around it

uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.74, 0.80, 0.92);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.52;   // higher = fewer clouds
uniform float cloud_scale = 0.9;
uniform vec2 cloud_offset = vec2(3.7, 1.2);                // change to rearrange the clouds

uniform vec3 hill_color : source_color = vec3(0.62, 0.76, 0.80);
uniform vec3 tree_color : source_color = vec3(0.45, 0.62, 0.62);
uniform vec3 house_color : source_color = vec3(0.70, 0.74, 0.82);
uniform vec3 roof_color : source_color = vec3(0.58, 0.52, 0.62);
uniform vec3 window_color : source_color = vec3(0.86, 0.88, 0.80);
uniform float house_count = 30.0;        // houses (and gaps) around the full circle
uniform float house_height = 0.11;       // typical wall height in sky units
uniform float neighbourhood_seed = 4.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amplitude;
		p = p * 2.03 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return total;
}

// 1-D noise around the horizon that wraps cleanly at the back.
float ring_noise(float turns, float frequency, float seed) {
	float a = turns * 6.2831853;
	return fbm(vec2(cos(a), sin(a)) * frequency + vec2(seed, seed * 1.3));
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	float turns = atan(dir.x, -dir.z) / 6.2831853 + 0.5;   // 0..1 around the horizon

	// Sky gradient, and a hazy ground colour below the horizon.
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, up));
	if (up < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.08, up));
	}

	// Sun: a soft disc with a warm halo.
	if (LIGHT0_ENABLED) {
		float facing = dot(dir, LIGHT0_DIRECTION);
		float angle = acos(clamp(facing, -1.0, 1.0));
		col += sun_color * sun_glow * exp(-angle * 9.0);
		col = mix(col, sun_color * 1.6, 1.0 - smoothstep(sun_size * 0.85, sun_size, angle));
	}

	// Clouds: puffy noise on a flat layer high overhead, fading out toward
	// the horizon. The underside is shaded where the puff is thinner.
	if (up > 0.0) {
		vec2 uv = dir.xz / (up + 0.12) * cloud_scale + cloud_offset;
		float n = fbm(uv);
		float puff = smoothstep(cloud_cover, cloud_cover + 0.08, n);
		float shade = smoothstep(cloud_cover, cloud_cover + 0.25, fbm(uv + vec2(0.07, 0.05)));
		vec3 cloud = mix(cloud_shadow, cloud_color, shade);
		float fade = smoothstep(0.02, 0.18, up);
		col = mix(col, cloud, puff * fade * 0.95);
	}

	// The neighbourhood on the horizon, back to front.
	// 1. Rolling hills, palest (farthest).
	float hills = 0.025 + 0.05 * ring_noise(turns, 2.5, 11.0);
	if (up < hills) {
		col = mix(col, hill_color, 0.9);
	}
	// 2. Houses with pitched roofs, chimneys and windows; gaps get trees.
	float cells = turns * house_count;
	float cell = mod(floor(cells), house_count);
	float f = fract(cells);
	float r = hash(vec2(cell, neighbourhood_seed));
	float trees = 0.04 + 0.09 * ring_noise(turns, 18.0, 3.0);
	float wall = house_height * mix(0.75, 1.25, hash(vec2(cell, neighbourhood_seed + 1.0)));
	float half_width = mix(0.28, 0.4, hash(vec2(cell, neighbourhood_seed + 2.0)));
	float from_middle = abs(f - 0.5);
	bool is_house = r > 0.22 && from_middle < half_width;
	float roof_top = wall + house_height * 0.55 * (1.0 - from_middle / (half_width + 0.06));
	bool chimney = r > 0.55 && f > 0.6 && f < 0.66 && up < wall + house_height * 0.5;
	if (up < trees && (!is_house || up > roof_top)) {
		col = mix(col, tree_color, 0.92);
	}
	if (is_house && up < roof_top) {
		if (up < wall) {
			col = house_color;
			// A grid of windows on the wall.
			vec2 w = vec2((f - 0.5) / (half_width * 2.0) * 4.0, up / wall * 3.0);
			vec2 wf = fract(w);
			if (abs(w.x) < 1.6 && up > wall * 0.15 && up < wall * 0.85
					&& wf.x > 0.3 && wf.x < 0.7 && wf.y > 0.3 && wf.y < 0.75) {
				col = window_color;
			}
		} else {
			col = roof_color;
		}
	}
	if (chimney) {
		col = roof_color * 0.9;
	}

	COLOR = col;
}
