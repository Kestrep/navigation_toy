shader_type spatial;
render_mode world_vertex_coords;

uniform vec3 base_color : source_color = vec3(0.716, 0.863, 0.511);
uniform vec3 line_color : source_color = vec3(0.42, 0.55, 0.30);
uniform float cell_size = 1.0;
uniform float line_thickness : hint_range(0.001, 0.1) = 0.02;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = VERTEX;
}

void fragment() {
	vec2 world_xz = v_world_pos.xz;
	vec2 cell = world_xz / cell_size;
	vec2 grid = abs(fract(cell - 0.5) - 0.5);
	float line = step(grid.x, line_thickness) + step(grid.y, line_thickness);
	line = clamp(line, 0.0, 1.0);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.95;
}
