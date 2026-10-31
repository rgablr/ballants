shader_type spatial;
// PLACEHOLDER SOCCER BALL PATTERN
// Draws the classic 12 dark pentagons + 20 light hexagons using math on the
// surface direction, so no texture file is needed. It is replaced wholesale
// when a real ball model is dropped into the asset manifest.

uniform vec3 light_color : source_color = vec3(0.93, 0.93, 0.90);
uniform vec3 dark_color : source_color = vec3(0.08, 0.08, 0.10);
uniform vec3 seam_color : source_color = vec3(0.55, 0.55, 0.55);
uniform float seam_width : hint_range(0.0, 0.05) = 0.012;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.6;

varying vec3 model_normal;

const float PHI = 1.6180339887;

void vertex() {
	// NORMAL here is in the model's own space, so the pattern spins with the ball.
	model_normal = NORMAL;
}

void fragment() {
	vec3 a = abs(normalize(model_normal));
	// How close this point is to the nearest pentagon center
	// (the 12 corners of an icosahedron).
	float pent = max(max(a.y + PHI * a.z, a.z + PHI * a.x), a.x + PHI * a.y) / sqrt(1.0 + PHI * PHI);
	// How close it is to the nearest hexagon center
	// (the 20 corners of a dodecahedron).
	float hex_a = (a.x + a.y + a.z) / sqrt(3.0);
	float hex_b = max(max(a.y / PHI + PHI * a.z, a.z / PHI + PHI * a.x), a.x / PHI + PHI * a.y) / sqrt(3.0);
	float hex = max(hex_a, hex_b);
	float d = pent - hex;
	vec3 color = d > 0.0 ? dark_color : light_color;
	if (abs(d) < seam_width) {
		color = seam_color;
	}
	ALBEDO = color;
	ROUGHNESS = roughness_value;
}
