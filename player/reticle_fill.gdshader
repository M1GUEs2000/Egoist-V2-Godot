shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
// Reticle del lock-on como dona que se vacia con la vida del target. TorusMesh mapea su UV.x
// dando toda la vuelta al anillo mayor, asi que recortar por UV.x > fill es un "pie chart"
// sin tocar geometria: lock_on.gd solo actualiza el uniform `fill` cada frame.

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float emission_energy = 1.0;

void fragment() {
	if (UV.x > fill) {
		discard;
	}
	ALBEDO = color.rgb;
	EMISSION = color.rgb * emission_energy;
	ALPHA = color.a;
}
