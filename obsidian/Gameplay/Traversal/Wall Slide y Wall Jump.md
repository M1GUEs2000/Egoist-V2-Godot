---
title: Wall Slide y Wall Jump
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E3
hito: H1
---

# Wall Slide y Wall Jump

Movimiento de pared implementado como modulo componible `PlayerWallSlide` (nodo hijo `WallSlide` del player). `Player` orquesta; la decision fina vive en el modulo. Tuning en `PlayerTuning` grupo `Wall slide`.

> [!important] Reescrito el 2026-07-27
> El modelo viejo (momentum de entrada que decae linealmente + multiplicadores de rebote) se
> reemplazo por una **rampa de aceleracion con rangos absolutos**. El motivo esta en
> [[#Por que se reescribio]]. Los knobs viejos ya no existen.

## El modelo: rampa en dos fases

El slide es **un solo tramo de aceleracion**. Al enganchar se arranca en una velocidad inicial y se acelera hacia una velocidad final; al tocar la final empieza la caida.

Los dos extremos salen de **rangos**, y el punto dentro del rango lo elige un solo numero: que tan rasante se llego, medido contra `move_speed` (tangente 0 → min, tangente >= `move_speed` → max). Llegar lanzado da un tramo mas rapido **y** un techo mas alto.

| Fase | Que pasa | Knobs |
|---|---|---|
| **1 — Rampa** | Acelera de la velocidad inicial a la final. La pared **sostiene**: no se cae nada. | `wall_slide_initial_speed_min/max`, `wall_slide_final_speed_min/max`, `wall_slide_acceleration` |
| **2 — Caida** | Arranca la gravedad. El slide aguanta al 100% y despues se drena. | `wall_slide_fall_hold_time`, `wall_slide_fall_lateral_halflife`, `wall_slide_gravity_scale`, `wall_slide_max_fall_speed` |

- **La duracion del slide la decide `wall_slide_acceleration`**: el tramo tarda `(final − inicial) / aceleracion` segundos. Es el knob para alargar o acortar el deslice.
- El drenaje de la fase 2 es **exponencial por vida media**: cada `wall_slide_fall_lateral_halflife` segundos queda la mitad. Nunca corta seco y es independiente del framerate.
- `wall_slide_fall_hold_time` es la ventana en que el rebote todavia sale **pleno** tras terminar la rampa. Subirlo perdona la ejecucion, bajarlo la exige.
- La caida por gravedad se acumula en una variable **aparte** de la velocidad del slide. Van separadas para que la gravedad no contamine lo que mide la potencia del rebote ni el brillo.

## Rumbo: lateral, trepada y todo lo intermedio

El rumbo del slide es un vector **sobre el plano de la pared**, no solo horizontal. Deslizar de lado y trepar son el mismo rumbo apuntando distinto — no hay modo trepada ni caso especial.

Lo gobierna una sola regla (`_wall_plane_vector`):

> lo que va **de costado** se conserva de costado; lo que empuja **contra el muro** se dobla hacia **arriba**, recortado por `wall_slide_climb_ratio`.

Se aplica en los dos lugares donde entra direccion:

- **Al enganchar**, sobre la velocidad de llegada: llegar rasante desliza de lado, llegar de frente sube, llegar en diagonal sube en diagonal.
- **Mientras se desliza**, sobre el input: empujar contra la pared dirige hacia arriba, con la autoridad de `wall_slide_steer_control`. Se puede arrancar de lado y curvar a trepada, o al reves.

**El input solo redirige, nunca acelera.** La rapidez la manda la rampa entera; el stick solo decide hacia donde. Esa separacion es lo que mantiene la salida del slide anclada a un techo conocido.

`wall_slide_max_climb_angle` (45°) es un **tope duro**: por mas de frente que se entre, la trepada nunca sube mas empinado. Sin el, entrar perpendicular daba un rumbo casi vertical y se trepaba la pared como una escalera. Entrar perpendicular puro no deja lateral contra el cual medir el angulo, asi que se presta el lateral justo para quedar exacto en el tope: sale una diagonal, con el lado tomado del rumbo previo (determinista).

Trepar esta acotado **por construccion**: se sube acelerando hasta `final_speed` y ahi el mismo drenaje de la fase 2 apaga la subida. No hizo falta un tope de altura aparte.

## Enganche y despegue

- Engancharse requiere estar en el aire + empuje real contra la pared (`wall_slide_min_push_speed`). No exige apretar hacia el muro. La pared se detecta con las colisiones de `CharacterBody3D` tras `move_and_slide`, filtrando `World.LAYER_WORLD`.
- **Assist:** una vez enganchado, el slide se mantiene con input neutro; solo se corta si el stick apunta claramente **hacia afuera** (`wall_slide_input_dot`). Hay ventana de gracia coyote (`wall_slide_release_grace`) al perder contacto, asi el estado no titila en esquinas.
- **Cooldown de re-enganche** (`wall_slide_reattach_cooldown`, 0.35 s): tras despegarse **a proposito**, no se puede volver a engancharse durante esa ventana. Sin el, soltar y re-pegar es un **reset gratis**: reinicia la rampa, cancela el drenaje y devuelve potencia plena, asi que aleteando el stick uno se queda en la pared para siempre. Solo aplica al despegue voluntario — perder contacto por geometria sigue pudiendo reenganchar en el acto, que es lo que hace fluido el encadenado en esquinas. Reusa el mismo `_ignore_until` que el wall jump y toma el maximo, asi los dos bloqueos no se pisan.
- Mientras se desliza se aplica presion constante contra la pared (`wall_slide_press_speed`) que sostiene el contacto fisico.
- Se cancela al tocar suelo, dashear, ser lanzado, recibir bump o entrar en stun.
- API: `apply_slide_velocity`, `update_after_move`, `try_wall_jump`, `cancel`, `blocks_move_input`.

## Wall jump

- Contra una pared, el boton de salto SIEMPRE produce el rebote, nunca un salto vertical ni el doble salto: si el slide no esta activo ese frame pero hay contacto real, se re-detecta la normal y rebota igual.
- Es un **impulso de la pared**, no un salto del jugador: no consume el doble salto, y la pared tampoco recarga uno gastado (eso solo lo hacen el suelo o `restore_double_jump`).
- **Todo sale de una sola fraccion 0-1** (`_wall_jump_power_frac`): rapidez horizontal, subida y angulo se interpolan con ella entre su minimo y su maximo. Sin multiplicadores ni pisos por separado.

| Pieza | Como sale |
|---|---|
| Horizontal | `lerp(wall_jump_h_min, wall_jump_h_max, frac)` |
| Vertical | `lerp(wall_jump_v_min, wall_jump_v_max, frac)` |
| Angulo | `lerp(90°, wall_slide_wall_jump_min_angle, frac)` |

- La fraccion mide **la velocidad del sistema que este mandando**, no la del cuerpo: `_slide_speed` (la rampa) en una pared normal, la del riel en un Wall Impulse, y la velocidad real sobre el plano solo en el re-agarre, cuando el slide ya se corto y no hay rampa que leer. Cuenta igual deslizar de costado que trepar, y **deja afuera la caida por gravedad**: si la caida contara, colgarse de la pared valdria mas que deslizarla bien — el incentivo al reves.
- **Satura en `wall_slide_wall_jump_full_power_percent`** (80%) del techo del slide. Eso crea una **meseta** arriba en vez de un pico exacto: todo el tramo final de la rampa, mas la ventana de hold, entrega el 100%. No hay que clavar un frame.
- El **angulo** se mide desde la cara de la pared: a rebote pleno se sale al `min_angle` (rasante, nunca menos, para no rozar el muro); sin velocidad lateral se sale perpendicular (90°, recto para atras). Tener H y V por separado ya define la inclinacion vertical; el `min_angle` solo reparte la salida **horizontal** entre alejarse del muro y seguir de largo.
- El calculo vive en `_wall_jump_velocity`, que comparten el salto real y la flecha de debug, asi nunca difieren.
- Durante `wall_slide_wall_jump_lock_time` el rebote manda: input de movimiento y re-agarre quedan bloqueados; el lock se corta al tocar suelo.
- **Flecha de debug** (`wall_slide_show_jump_arrow`): mientras se desliza, una flecha de ~2 m apunta al angulo real de lanzamiento segun la velocidad del momento.

## Feedback visual

- El personaje brilla verde mientras esta pegado. La intensidad usa **exactamente la misma fraccion que la potencia del rebote**, no una escala aparte: brillo pleno significa literalmente "el wall jump sale al 100%", meseta incluida. Dejo de ser decorado y es el indicador de cuando saltar. Knobs `glow_color`, `glow_energy_min`, `glow_energy_max` en el nodo `WallSlide`.
- El brillo va sobre las mallas del **modelo** (`Visual/...`), recolectadas recursivamente, no sobre el nodo `Mesh` — ese es la capsula placeholder y quedo con `visible = false`. Se aplica con `material_overlay` aditivo y no con `set_surface_override_material`: el override reemplazaria el material del modelo y dejaria una silueta verde plana. La intensidad se empuja por el **color** (rgb multiplicado, HDR pasado 1.0), no por `emission_energy`, porque el overlay es unshaded. El bloom lo levanta el `WorldEnvironment` (ver [[Colores de mundo]]).
- Polvo mientras se desliza: emisor `WallSlideDust` (`GPUParticles3D`) hijo del player, que `PlayerWallSlide` prende/apaga en sync con el glow.
- Mientras se desliza, la camara se planta sola frente a la pared en vez de responder al stick, y se abre a vista 2D cuando la bajada es vertical seca (ver [[Camara]]).

## Wall Impulse

Un `StaticBody3D` con hijo `WallImpulseSurface` y su `WallImpulseTuning` convierte el wall slide en un carril. Captura el primer input horizontal tangencial para escoger el **sentido**, ignora el stick posterior, anula la caida y arranca con `initial_speed`; despues acelera con `acceleration` hasta `max_speed`. En una curva, el vector se recalcula como la tangente de la normal actual conservando el sentido inicial, asi no pierde velocidad al pasar de tramo curvo a recto dentro del mismo mesh. `angle_degrees` inclina el carril respecto a esa tangente: `0` horizontal, negativo baja y positivo sube.

**El carril es exclusivo**: mientras esta activo manda entero y la rampa del slide no interviene. Antes se mezclaban por suma y el carril competia contra el drenaje del slide en vez de reemplazarlo. Su velocidad puede superar el techo normal del wall slide; al perder contacto se entrega como momentum aereo y vuelve a respetar `momentum_max_speed`.

### Wall jump desde el carril

El rebote tiene la **misma forma** que el normal (rangos min/max interpolados por la velocidad del momento), pero los rangos son **por pared**: `wall_jump_h_min/max` y `wall_jump_v_min/max` viven en el `WallImpulseTuning`, no en el `PlayerTuning`. Asi un carril rapido puede tirar mucho mas lejos que un muro comun sin tocar el tuning del player.

- La fraccion se mide contra el techo **del carril** (`max_speed`), no contra el del slide. "Rebote pleno" significa "vas a tope EN ESTE riel"; con el techo del slide, un carril lento nunca habria llegado al rebote pleno.
- El **angulo** lo sigue mandando el player (`wall_slide_wall_jump_min_angle`): es forma de movimiento del personaje, no propiedad de la superficie.
- El sprint escala estos rangos por los mismos canales `WALL_JUMP_H` / `WALL_JUMP_V` que el rebote normal.

*(2026-07-27)*

**Particulas:** `WallImpulseSurface` inyecta una senal verde aditiva permanente: crea un emisor por cada `MeshInstance3D` de la pared y lo dimensiona con el AABB real, asi las motas caen de toda la geometria desde el inicio. Una segunda rafaga movil y una `OmniLight3D` verde siguen el punto de contacto. Sus knobs viven en el mismo `.tres` de la pared. *(2026-07-19)*

## Por que se reescribio

El modelo viejo sembraba el momentum de entrada y lo decaia linealmente, y el rebote se calculaba con multiplicadores (`h_boost`, `v_boost`) sobre pisos y topes. Eso hacia que **la salida del slide dependiera de con cuanta velocidad se habia entrado**, asi que cada rebote se alimentaba del anterior y la cadena entre paredes espiralaba: con `h_boost` en 1.1 y el techo de momentum ampliado por el sprint, encadenar aceleraba sin converger.

Los rangos absolutos matan el bucle **por construccion**: se entre con 5 o con 40, la rampa termina en el mismo techo y el rebote sale del mismo rango fijo. La cadena converge a un punto fijo en vez de escalar.

Efecto lateral: el sistema paso de ~14 knobs a ~20, pero todos en **m/s, m/s² o grados** — magnitudes con significado directo — en vez de multiplicadores abstractos cuya banda util habia que deducir.

## Verificacion

Chequeos de regresion headless: `world/wall_slide_probe.tscn` (cae pegado a una pared con input sostenido y cuenta transiciones del estado de slide) y `world/wall_impulse_probe.tscn` (captura el primer input tangencial y verifica que no cambie al alterar el stick).

Estado **E3**: la reescritura fue **aprobada jugando** — rampa, trepada con tope de angulo, rebote por rangos y cooldown de re-enganche. Lo que queda es iterar valores como ajuste fino, no buscar la direccion del feel. El sistema paso por la regresion E3 → E2 al reescribirse y volvio a E3 en la misma sesion. *(2026-07-27)*

Wall Impulse esta integrado y jugable: sus paredes (`assets/models/walls/wall_curve.tscn` y `wall_spiral.tscn`) estan colocadas 8 veces en `world/lvl_1_v_0_1.tscn`, que es la **escena principal** del proyecto. Sus rangos de wall jump por pared (2026-07-27) tambien se probaron jugando.

## Relacionado

- [[Sprint]]
- [[Movimiento Base]]
- [[Launcher y Aire]]
- [[Momentum y Bump]]
- [[Camara]]
- [[Traversal]]
