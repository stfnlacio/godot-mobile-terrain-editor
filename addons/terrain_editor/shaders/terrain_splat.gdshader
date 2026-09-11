shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D splatmap : source_color, filter_linear;
uniform sampler2D tex0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex3 : source_color, filter_linear_mipmap, repeat_enable;

uniform vec2 uv_scale = vec2(8.0, 8.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec4 layer_tint0 = vec4(1.0);
uniform vec4 layer_tint1 = vec4(1.0);
uniform vec4 layer_tint2 = vec4(1.0);
uniform vec4 layer_tint3 = vec4(1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;

varying vec2 splat_uv;
varying vec2 detail_uv;

void vertex() {
	splat_uv = UV;
	detail_uv = UV * uv_scale + uv_offset;
}

void fragment() {
	vec4 w = texture(splatmap, splat_uv);
	// Normalize weights so they sum to 1
	float sum = max(w.r + w.g + w.b + w.a, 0.0001);
	w /= sum;

	vec3 c0 = texture(tex0, detail_uv).rgb * layer_tint0.rgb;
	vec3 c1 = texture(tex1, detail_uv).rgb * layer_tint1.rgb;
	vec3 c2 = texture(tex2, detail_uv).rgb * layer_tint2.rgb;
	vec3 c3 = texture(tex3, detail_uv).rgb * layer_tint3.rgb;

	ALBEDO = c0 * w.r + c1 * w.g + c2 * w.b + c3 * w.a;
	ROUGHNESS = roughness_value;
}
