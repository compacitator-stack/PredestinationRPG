shader_type canvas_item;

// PS1 Post-Processing: Color Quantization + Ordered Dithering
// Applied on a full-screen ColorRect via CanvasLayer

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float color_depth : hint_range(8.0, 64.0) = 31.0; // PS1 = 31 (5-bit per channel)
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;

// PS1 4x4 Bayer dithering matrix (normalized to -0.5..0.5 range)
const mat4 BAYER = mat4(
	vec4(-0.5,     0.0,    -0.375,   0.125),
	vec4( 0.25,   -0.25,    0.375,  -0.125),
	vec4(-0.3125,  0.1875, -0.4375,  0.0625),
	vec4( 0.4375, -0.0625,  0.3125, -0.1875)
);

void fragment() {
	vec4 screen_color = texture(screen_texture, SCREEN_UV);

	// Get dither offset from Bayer matrix based on pixel position
	ivec2 pixel = ivec2(FRAGCOORD.xy);
	int bx = pixel.x % 4;
	int by = pixel.y % 4;
	float dither_offset = BAYER[by][bx] / color_depth * dither_strength;

	// Quantize to PS1 color depth with dithering
	vec3 quantized = floor((screen_color.rgb + dither_offset) * color_depth + 0.5) / color_depth;
	quantized = clamp(quantized, 0.0, 1.0);

	COLOR = vec4(quantized, 1.0);
}
