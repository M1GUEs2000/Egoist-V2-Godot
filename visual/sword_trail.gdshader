shader_type spatial;
// Cinta procedural. La geometria la genera RibbonTrail como una tira de triangulos en espacio de
// mundo; este shader solo la pinta. Las dos UV son el contrato entre los dos:
//
//   UV.x = EDAD de la muestra, 0 = recien salida de la hoja, 1 = la mas vieja (la cola).
//   UV.y = A LO ANCHO de la hoja, 0 = base (la empunadura), 1 = punta.
//
// blend_add = el negro se vuelve transparente solo y la estela suma luz (glow con el bloom del
// proyecto), igual que visual/flipbook_vfx.gdshader. depth_draw_never evita que la tira se tape a si
// misma donde se cruza consigo misma a mitad del swing; el depth TEST sigue activo, asi que la
// estela no se ve a traves de las paredes.
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

// Color a lo largo de la vida, muestreado por UV.x. Es una GradientTexture1D que el nodo construye
// desde el `Gradient` del tuning, asi el color se tunea con el widget de gradiente de Godot.
uniform sampler2D gradient : source_color, filter_linear, repeat_disable;

// Ruido de erosion. Procedural (NoiseTexture2D + FastNoiseLite), sin PNG en disco: la regla de la
// boveda es cero arte final antes de H3.
uniform sampler2D erosion_noise : filter_linear, repeat_enable;

// Cuantas veces cabe el ruido sobre la tira. X estira el patron a lo largo de la estela, Y a lo
// ancho de la hoja.
uniform vec2 erosion_scale = vec2(2.0, 1.0);

// Paneo del ruido en UV/segundo. Que el patron se mueva evita que la erosion se lea como una
// mascara fija pegada a la hoja.
uniform vec2 erosion_scroll = vec2(-1.2, 0.0);

// Cuanto se come el ruido a la estela. 0 = no erosiona (la cola se va solo por el alpha del
// gradiente); 1 = para el final de su vida la estela esta completamente comida.
uniform float erosion_strength : hint_range(0.0, 1.0) = 0.75;

// Que tan blando es el borde de la erosion. Bajo = recorte duro y sucio; alto = disuelve suave.
uniform float erosion_softness : hint_range(0.01, 1.0) = 0.35;

// Cuanto se afina la estela hacia la base de la hoja (UV.y = 0). 0 = banda pareja de punta a
// empunadura; 1 = solo sobrevive el filo. Es lo que hace que el arco se lea como un corte y no como
// una cinta.
uniform float base_fade : hint_range(0.0, 1.0) = 0.55;

// Multiplicador de brillo. >1 empuja el bloom.
uniform float brightness : hint_range(0.0, 8.0) = 1.6;
// Color runtime del dueño de la cinta. La Espada queda blanca; el sprint escala su verde con nivel.
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float age = UV.x;
	vec4 grad = texture(gradient, vec2(age, 0.5));

	vec2 noise_uv = UV * erosion_scale + TIME * erosion_scroll;
	float noise = texture(erosion_noise, noise_uv).r;

	// El umbral sube con la edad: la cola se disuelve antes que la cabeza. smoothstep contra el
	// ruido en vez de un step da el borde comido en vez de un recorte plano.
	float threshold = age * erosion_strength;
	float erode = smoothstep(threshold, threshold + erosion_softness, noise);

	// La base de la hoja se apaga: mix(1 - base_fade, 1, UV.y) vale 1 en la punta siempre.
	float across = mix(1.0 - base_fade, 1.0, UV.y);

	ALBEDO = grad.rgb * tint.rgb * brightness;
	ALPHA = grad.a * erode * across;
}
