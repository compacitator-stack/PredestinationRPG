shader_type spatial;
render_mode vertex_lighting, specular_disabled;

// PS1 Per-Model Shader: Vertex Wobble + Affine Texture Mapping
// Apply via geometry_material_override on MeshInstance3D nodes

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform bool pixel_snap_enabled = true;
uniform float snap_resolution = 160.0; // Smaller = more aggressive wobble
uniform float affine_weight : hint_range(0.0, 1.0) = 1.0; // 0 = correct, 1 = full PS1 warp
uniform vec2 texture_tile = vec2(1.0);

varying float v_clip_w;
varying vec2 v_affine_uv;

void vertex() {
	// --- Vertex Snapping (PS1 integer vertex positions) ---
	if (pixel_snap_enabled) {
		// Transform to clip space
		vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

		// Snap in NDC (normalized device coordinates)
		vec2 ndc = clip_pos.xy / clip_pos.w;
		ndc = round(ndc * snap_resolution) / snap_resolution;

		// Convert back to clip space
		clip_pos.xy = ndc * clip_pos.w;
		POSITION = clip_pos;
	}

	// --- Affine texture prep ---
	// Pass clip_w so the fragment shader can undo perspective correction
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_clip_w = clip.w;
	v_affine_uv = UV * texture_tile * clip.w; // Pre-multiply by W for affine
}

void fragment() {
	// Blend between perspective-correct and affine (PS1) UVs
	vec2 perspective_uv = UV * texture_tile;
	vec2 affine_uv = v_affine_uv / v_clip_w;
	vec2 final_uv = mix(perspective_uv, affine_uv, affine_weight);

	vec4 tex_color = texture(albedo_texture, final_uv);
	ALBEDO = tex_color.rgb;
}
