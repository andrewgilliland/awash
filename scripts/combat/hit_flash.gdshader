shader_type canvas_item;

// A struck enemy's flash: its sprite drawn white, keeping its shape.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
