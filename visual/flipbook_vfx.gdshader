shader_type spatial;
// Flipbook (spritesheet en grilla) sobre un quad que siempre mira a la camara.
// blend_add = los fondos negros de los flipbooks Brackeys se vuelven transparentes solos y el
// efecto suma luz (glow con bloom). unshaded = el color sale directo del PNG, sin iluminacion.
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

// El spritesheet. filter_nearest conserva el pixel-art sin sangrado entre cuadros.
uniform sampler2D flipbook : source_color, filter_nearest;
// Grilla del sheet: columnas x filas (ej. explosion_6x5 -> 6 x 5).
uniform int columns = 6;
uniform int rows = 5;
// Cuadro actual (lo maneja el script).
uniform int frame = 0;
// Tinte multiplicado. Blanco = color original del PNG.
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Brillo/glow. 1 = original; >1 empuja el bloom.
uniform float brightness = 1.0;

void vertex() {
	// Billboard: quita la rotacion (siempre de cara a camara) conservando la escala del nodo.
	mat4 mv = VIEW_MATRIX * MODEL_MATRIX;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = mat4(
		vec4(sx, 0.0, 0.0, 0.0),
		vec4(0.0, sy, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		mv[3]);
}

void fragment() {
	int total = columns * rows;
	int f = frame % total;
	int col = f % columns;
	int row = f / columns;
	vec2 grid = vec2(float(columns), float(rows));
	vec2 uv = (UV + vec2(float(col), float(row))) / grid;
	vec4 tex = texture(flipbook, uv);
	ALBEDO = tex.rgb * tint_color.rgb * brightness;
	ALPHA = tex.a * tint_color.a;
}
