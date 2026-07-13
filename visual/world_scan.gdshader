shader_type spatial;
// Cascara del scan de cambio de mundo: esfera que crece desde el trigger. Se ve como una malla de
// poligonos con el filo encendido, en luz tenue del color del mundo destino.
// unshaded: el color lo pone el shader, no las luces de la escena.
// blend_add + depth_draw_never: suma luz sobre lo que ya esta dibujado, no lo tapa ni escribe depth.
// cull_disabled: se ve tambien desde adentro (el jugador queda dentro de la burbuja al cruzarla).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 scan_color : source_color = vec3(1.0, 0.55, 0.05);
uniform float energy = 1.2;
uniform float alpha_scale = 0.45;
uniform float rim_power = 3.0;
uniform float grid_density = 14.0;
uniform float grid_width = 1.4;
uniform float grid_mix = 0.7;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

// Lineas de la malla sobre la esfera: rejilla en coordenadas esfericas del punto local.
// fwidth mantiene el grosor de linea constante en pantalla, sin importar cuanto creció la onda.
float grid_lines(vec3 dir) {
	vec3 n = normalize(dir);
	vec2 uv = vec2(atan(n.z, n.x) / (2.0 * PI), acos(clamp(n.y, -1.0, 1.0)) / PI);
	vec2 cells = uv * grid_density;
	vec2 dist_to_line = abs(fract(cells) - 0.5);
	vec2 fade = fwidth(cells) * grid_width;
	vec2 lines = smoothstep(vec2(0.0), fade, dist_to_line);
	return 1.0 - min(lines.x, lines.y);
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	float intensity = mix(rim, max(rim, grid_lines(v_local)), grid_mix);
	ALBEDO = scan_color * energy * intensity;
	ALPHA = clamp(intensity * alpha_scale, 0.0, 1.0);
}
