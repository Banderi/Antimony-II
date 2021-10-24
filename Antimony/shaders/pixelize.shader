shader_type canvas_item;

uniform float pixel_size = 0.25;

void fragment() {
	vec2 size = vec2(pixel_size) / SCREEN_PIXEL_SIZE;
	ivec2 coord = ivec2(floor(SCREEN_UV * size) / pixel_size);
	COLOR.rgb = texelFetch(SCREEN_TEXTURE, coord, 0).rgb;
}