shader_type spatial;
// SPORTS BALLS -- every ball style the player can pick in the customize
// menu (except the soccer ball, which has its own shader), drawn with math
// on the surface direction: no texture files. `style` picks the ball:
//   1 basketball   2 volleyball   3 beach ball   4 tennis ball
//   5 baseball     6 bowling ball 7 8-ball       8 golf ball
//   9 playground ball (red rubber with a seam)
// The pattern spins with the ball because it uses the model's own normal.

uniform int style = 1;

varying vec3 model_normal;

void vertex() {
	model_normal = NORMAL;
}

float line(float d, float width) {
	return 1.0 - smoothstep(width * 0.6, width, abs(d));
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// The curve a tennis ball or baseball seam follows: a saddle-shaped loop
// around the sphere.
float seam(vec3 n) {
	return n.y - 0.85 * (n.x * n.x - n.z * n.z);
}

// A ring on the surface around direction `center` at angular radius r.
float ring(vec3 n, vec3 center, float r, float width) {
	return line(acos(clamp(dot(n, normalize(center)), -1.0, 1.0)) - r, width);
}

void fragment() {
	vec3 n = normalize(model_normal);
	vec3 col = vec3(1.0);
	float rough = 0.6;
	float metal = 0.0;

	if (style == 1) {
		// Basketball: orange pebbled leather, black channels.
		col = vec3(0.86, 0.38, 0.12) * (0.92 + 0.08 * hash(floor(n * 90.0)));
		float lines = max(line(n.x, 0.02), line(n.y, 0.02));
		lines = max(lines, line(abs(n.z) - 0.72, 0.02));
		col = mix(col, vec3(0.06, 0.04, 0.03), lines);
		rough = 0.8;
	} else if (style == 2) {
		// Volleyball: three panel groups of three stripes, yellow/blue/white.
		vec3 a = abs(n);
		float main_axis;
		float across;
		if (a.x > a.y && a.x > a.z) { main_axis = 0.0; across = n.y; }
		else if (a.y > a.z) { main_axis = 1.0; across = n.z; }
		else { main_axis = 2.0; across = n.x; }
		float stripe = floor((across / max(max(a.x, a.y), a.z) + 1.0) * 1.5);
		vec3 colors[3] = { vec3(0.98, 0.84, 0.2), vec3(0.12, 0.32, 0.75), vec3(0.96, 0.96, 0.94) };
		col = colors[int(mod(stripe + main_axis, 3.0))];
		float edge = max(max(line(a.x - a.y, 0.015), line(a.y - a.z, 0.015)), line(a.z - a.x, 0.015));
		col = mix(col, col * 0.55, edge * 0.6);
		rough = 0.5;
	} else if (style == 3) {
		// Beach ball: six bright wedges around the middle, white caps.
		float angle = atan(n.z, n.x) / 6.2831853 + 0.5;
		int wedge = int(floor(angle * 6.0));
		vec3 colors[6] = { vec3(0.93, 0.15, 0.15), vec3(0.98, 0.85, 0.15), vec3(0.15, 0.45, 0.9),
				vec3(0.98, 0.98, 0.96), vec3(0.2, 0.7, 0.3), vec3(0.98, 0.55, 0.1) };
		col = colors[wedge];
		if (abs(n.y) > 0.93) { col = vec3(0.98); }
		rough = 0.25;
	} else if (style == 4) {
		// Tennis ball: fuzzy yellow-green, white curved seam.
		col = vec3(0.8, 0.9, 0.18) * (0.9 + 0.1 * hash(floor(n * 160.0)));
		col = mix(col, vec3(0.97, 0.97, 0.92), line(seam(n), 0.06));
		rough = 1.0;
	} else if (style == 5) {
		// Baseball: white leather, red double-stitched seam.
		col = vec3(0.95, 0.93, 0.86);
		float s = seam(n);
		col = mix(col, vec3(0.86, 0.85, 0.8), line(s, 0.03));
		// Stitches: short red dashes either side of the seam.
		float along = atan(n.z, n.x) * 22.0 + n.y * 22.0;
		float dash = step(0.5, fract(along));
		float stitch_band = max(line(s - 0.06, 0.025), line(s + 0.06, 0.025));
		col = mix(col, vec3(0.8, 0.08, 0.08), stitch_band * dash);
		rough = 0.7;
	} else if (style == 6) {
		// Bowling ball: deep swirled purple, glossy, three finger holes.
		float swirl = sin(n.x * 6.0 + sin(n.y * 5.0) * 2.0 + n.z * 3.0);
		col = mix(vec3(0.22, 0.06, 0.35), vec3(0.45, 0.15, 0.6), 0.5 + 0.5 * swirl);
		vec3 h0 = normalize(vec3(0.0, 0.25, -1.0));
		vec3 h1 = normalize(vec3(0.18, 0.5, -0.9));
		vec3 h2 = normalize(vec3(-0.18, 0.5, -0.9));
		float hole = max(step(0.9965, dot(n, h0)), max(step(0.9975, dot(n, h1)), step(0.9975, dot(n, h2))));
		col = mix(col, vec3(0.02), hole);
		rough = 0.12;
	} else if (style == 7) {
		// 8-ball: glossy black, a white circle with a black "8" in it.
		col = vec3(0.03, 0.03, 0.04);
		vec3 c = vec3(0.0, 0.0, -1.0);
		float d = acos(clamp(dot(n, c), -1.0, 1.0));
		if (d < 0.38) {
			col = vec3(0.97);
			// The 8: two small rings stacked one above the other.
			float eight = max(ring(n, vec3(0.0, 0.1, -1.0), 0.085, 0.03),
					ring(n, vec3(0.0, -0.1, -1.0), 0.1, 0.03));
			col = mix(col, vec3(0.03), eight);
		}
		rough = 0.08;
	} else if (style == 8) {
		// Golf ball: white with a dimple pattern.
		vec3 cell = floor(n * 14.0);
		vec3 local = fract(n * 14.0) - 0.5;
		float dimple = 1.0 - smoothstep(0.15, 0.42, length(local.xy + local.yz * 0.3));
		col = vec3(0.97) * (1.0 - dimple * 0.12);
		rough = 0.35;
	} else if (style == 9) {
		// Playground ball: red rubber, a raised seam ring, bumpy grip.
		col = vec3(0.82, 0.12, 0.12) * (0.94 + 0.06 * hash(floor(n * 70.0)));
		col = mix(col, vec3(0.6, 0.08, 0.08), line(n.y, 0.03));
		rough = 0.55;
	}

	ALBEDO = pow(col, vec3(2.2));   // the colors above are ordinary (sRGB) colors
	ROUGHNESS = rough;
	METALLIC = metal;
}
