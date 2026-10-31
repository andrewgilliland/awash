shader_type canvas_item;

// A Ward: a pale outline one pixel round whatever the sprite's frame shows, and nothing else.
// A neighbour in another frame of the sheet counts as clear, so frames can be drawn to their
// edges without the outline reaching into the next.

uniform vec4 colour : source_color = vec4(0.69, 0.91, 0.96, 1.0);
// The sheet's frames across and down: the sprite's hframes and vframes.
uniform vec2 frames = vec2(8.0, 1.0);

float alpha_in_frame(sampler2D sheet, vec2 uv, vec2 frame) {
	return floor(uv * frames) == frame ? texture(sheet, uv).a : 0.0;
}

void fragment() {
	vec2 frame = floor(UV * frames);
	vec2 step = TEXTURE_PIXEL_SIZE;
	float here = texture(TEXTURE, UV).a;
	float around = alpha_in_frame(TEXTURE, UV + vec2(step.x, 0.0), frame)
		+ alpha_in_frame(TEXTURE, UV - vec2(step.x, 0.0), frame)
		+ alpha_in_frame(TEXTURE, UV + vec2(0.0, step.y), frame)
		+ alpha_in_frame(TEXTURE, UV - vec2(0.0, step.y), frame);
	COLOR = here < 0.5 && around > 0.0 ? colour : vec4(0.0);
}
