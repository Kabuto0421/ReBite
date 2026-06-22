shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.05, 0.09, 0.16, 1.0);
uniform vec4 tint_color : source_color = vec4(0.82, 0.76, 0.94, 1.0);
uniform float outline_size = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_size;
	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y)).a);

	if (base.a < 0.1 && nearby_alpha > 0.1) {
		COLOR = outline_color;
	} else {
		COLOR = vec4(base.rgb * tint_color.rgb, base.a * tint_color.a);
	}
}
