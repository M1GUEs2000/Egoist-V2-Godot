shader_type spatial;
// Cascara del otro mundo: el cuerpo NO desaparece cuando pertenece al mundo opuesto — se vacia.
// El interior queda casi transparente y el CONTORNO se enciende (fresnel). Asi se lee presencia
// y volumen sin regalar la silueta solida: sabes que hay algo ahi y por donde, no que es.
//
// `rim_energy` es la perilla que mueve el latido desde GDScript (ver WorldMembership): el borde
// pulsa entre un valle y una cresta, y el humo del eco se engancha a ese mismo pulso.
// Las afterimages reusan este shader y apagan `rim_energy` hasta cero para desvanecerse.
//
// blend_add: la cascara SUMA luz, nunca tapa. depth_draw_never + shadows_disabled: un fantasma
// del otro mundo no ocluye ni proyecta sombra en este. cull_disabled: se ven los bordes de atras,
// que es lo que le da la lectura hueca.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 rim_color : source_color = vec3(0.9, 0.4, 0.03);
// Energia del contorno. La mueve el pulso; en 0 la cascara desaparece (lo usan las afterimages).
// Sin tope: puede superar 1.0 para dar punch HDR al glow. No maneja la opacidad (ver rim_alpha).
uniform float rim_energy = 1.5;
// Finura del borde: mas alto = anillo mas fino y ceñido al contorno.
uniform float rim_sharpness : hint_range(0.5, 8.0) = 3.0;
// Relleno tenue del interior. En 0 queda solo el borde; subirlo insinua el volumen.
uniform float fill_energy : hint_range(0.0, 1.0) = 0.03;
// Cuanto del pulso ya paso, 0..1. Maneja SOLO la opacidad: si la mezclaramos con rim_energy
// (que llega hasta ~4 para el glow), el alpha se satura a 1.0 en el primer tramo del pulso y el
// resto del ciclo se ve plano en vez de seguir subiendo (ver WorldMembership._update_shell).
uniform float rim_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_sharpness);
	float intensity = rim * rim_energy + fill_energy;
	// Sin intensidad no existe cascara visible entre pulsos.
	if (intensity <= 0.0001) {
		discard;
	}
	ALBEDO = rim_color * intensity;
	ALPHA = clamp(rim, 0.0, 1.0) * rim_alpha;
}
