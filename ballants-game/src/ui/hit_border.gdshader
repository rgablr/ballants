shader_type canvas_item;
// HIT BORDER -- a red glow around the screen edges that fades out; shown
// when an enemy knocks the ant off. strength 1 = full, 0 = gone.

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.85, 0.05, 0.03, 1.0);
uniform float width = 0.22;   // how far in from the edges the glow reaches

void fragment() {
	vec2 from_edge = min(UV, 1.0 - UV);
	// Aspect-correct so the border is the same thickness on all sides.
	vec2 px = from_edge / SCREEN_PIXEL_SIZE;
	float d = min(px.x, px.y) * SCREEN_PIXEL_SIZE.y;
	float glow = 1.0 - smoothstep(0.0, width, d);
	COLOR = vec4(tint.rgb, glow * glow * 0.85 * strength);
}
