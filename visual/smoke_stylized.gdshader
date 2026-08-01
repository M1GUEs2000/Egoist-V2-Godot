shader_type spatial;
// Humo estilizado: la nube se disuelve por ruido y se sombrea en bandas duras (cell shading).
//
// Dos modos en un solo shader, porque son el mismo humo con distinto nivel de render:
//   flat_shaded = true  -> color plano, sin volumen. Silueta pura, estilo recorte.
//   flat_shaded = false -> bandas duras contra un sol propio del shader. Es el que da volumen.
// Vive en un uniform y no en dos shaders para que cambiar de modo no obligue a re-tunear el
// emisor, que es lo unico que define el movimiento.
//
// Los dos modos salen por EMISSION con ALBEDO en negro: el humo se ilumina solo. Por eso no hay
// funcion light() ni hace falta diffuse_toon/specular_toon en el render_mode.
//
// cull_disabled: la nube es hueca y translucida de lectura, hay que ver la cara de atras.
// El dissolve es ruido procedural en espacio de objeto, no una textura: el mesh no trae UV
// (ver tools/gen_cloud_mesh.gd) y asi el patron acompana al bulto en vez de nadar sobre el.
render_mode cull_disabled, shadows_disabled;

group_uniforms Dissolve;
// Tamano de las manchas del disuelto. Alto = se deshilacha en grumos chicos.
uniform float dissolve_scale : hint_range(0.5, 20.0) = 6.0;
// Cuanto muerde el disuelto antes de tiempo. 0 = la nube se mantiene entera hasta el final.
uniform float dissolve_bias : hint_range(-0.5, 0.5) = 0.0;

group_uniforms Look;
// true = color plano sin luz (H1). false = bandas de luz duras (anime).
// No se llama `flat` porque esa es palabra reservada del lenguaje de shaders (calificador de
// interpolacion): usarla como nombre de uniform hace que el shader no compile en silencio.
uniform bool flat_shaded = true;
// Tinte multiplicado sobre el gradiente del emisor. Blanco = el gradiente tal cual.
uniform vec3 tint : source_color = vec3(1.0);
// Multiplica el color de la particula. >1 empuja el glow del WorldEnvironment.
uniform float brightness : hint_range(0.0, 8.0) = 1.0;

group_uniforms CellShading;
// Rampa de luz->sombra. Con interpolacion CONSTANT da los escalones duros; con lineal, degrade.
uniform sampler2D shadow_bands : source_color;
// Curva del terminador. >1 corre la sombra hacia el borde y deja la nube mas iluminada.
uniform float shadow_roundness : hint_range(0.1, 4.0) = 1.0;
// Cuanta luz entra antes de saturar la rampa. Sube para achicar la parte en sombra.
uniform float light_attenuation : hint_range(0.1, 4.0) = 1.6;
// De donde viene la luz, en espacio de mundo. El default apunta al Sun que comparten las escenas
// (world/*.tscn: basis -Z, o sea luz desde arriba-derecha-frente).
//
// El humo se sombrea con esta direccion y no con las luces reales de la escena a proposito: es un
// VFX de lectura, no un objeto del mundo. Con luz real, el mismo push se leeria distinto segun
// donde este parado el enemigo (o plano si el nivel no tiene sol), y el volumen es justo lo que
// tiene que ser constante. Ademas asi funciona igual en los dos mundos.
uniform vec3 sun_direction = vec3(0.5, 0.707, 0.5);
// Piso de luz: sin esto la cara en sombra se va a negro y la nube se come el fondo.
uniform float ambient_floor : hint_range(0.0, 1.0) = 0.25;

varying vec3 object_position;

void vertex() {
	object_position = VERTEX;
}

// Value noise 3D. Hecho a mano y no con una textura para no arrastrar un asset por un patron
// que igual se genera: sin UV en el mesh, una textura habria necesitado proyeccion aparte.
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep: sin esto el disuelto se ve en cuadricula
	float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

void fragment() {
	vec3 shade = COLOR.rgb * tint * brightness;
	// El albedo queda negro en los dos modos: el humo se pinta entero por emission y ninguna luz
	// de la escena lo toca. Lo que cambia entre modos es si esa emision lleva volumen o no.
	ALBEDO = vec3(0.0);
	if (flat_shaded) {
		EMISSION = shade;
	} else {
		// Cell shading: comparar hacia donde mira la cara contra de donde viene la luz. El dot da
		// -1..1, se remapea a 0..1 y ese valor indexa la rampa; con la rampa en CONSTANT, valores
		// contiguos caen en el mismo escalon y de ahi salen los bordes duros.
		//
		// NORMAL llega en espacio de vista y sun_direction esta en mundo, asi que hay que llevar
		// una de las dos al espacio de la otra. Si no, la sombra quedaria pegada a la camara y
		// giraria con ella en vez de quedarse del lado del sol.
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float ndotl = dot(n, normalize(sun_direction));
		float wrapped = ndotl * 0.5 + 0.5;
		float shaped = pow(clamp(wrapped, 0.0, 1.0), shadow_roundness) * light_attenuation;
		vec3 band = texture(shadow_bands, vec2(clamp(shaped, 0.0, 1.0), 0.5)).rgb;
		EMISSION = shade * max(band, vec3(ambient_floor));
	}

	// El disuelto: el ruido es la mascara y la vida de la particula el umbral que la come.
	// COLOR.a viene de la curva de alpha del emisor (1 = entera, 0 = disuelta del todo), asi que
	// se invierte para leerla como "cuanto ya se comio". La curva se lee normal en el inspector.
	ALPHA = value_noise(object_position * dissolve_scale);
	ALPHA_SCISSOR_THRESHOLD = clamp(1.0 - COLOR.a + dissolve_bias, 0.0, 1.0);
}
