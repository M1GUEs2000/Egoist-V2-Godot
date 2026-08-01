---
title: Humo del Push
tags:
  - egoist
  - gameplay
  - vfx
  - enemigos
status: active
system_status: E1
hito: H1
---

# Humo del Push

Estela de humo que deja un enemigo mientras lo empuja el push. Subnota de [[VFX]].

| Pieza | Archivo |
|---|---|
| Nodo | `visual/smoke_stylized_vfx.gd` (`SmokeStylizedVFX`) |
| Shader | `visual/smoke_stylized.gdshader` |
| Material | `visual/smoke_stylized_material.tres` |
| Mesh nube | `visual/sm_cloud.res` ← generado por `tools/gen_cloud_mesh.gd` |
| Emisor | `visual/vfx_stylized_smoke.tscn` |
| Cableado | nodo `PushSmoke` en `enemies/grounded_enemy.tscn` |

## Nubes 3D, no billboards

Cada particula es una **malla con volumen**, no un sprite mirando a camara. Es la diferencia que
importa con `ParticleBurstVFX` y `FlipbookVFX`: la camara isometrica orbita ([[Camara]]), y un
billboard girando para seguirla delata que el humo es plano. La nube se lee igual desde cualquier
angulo porque efectivamente lo es.

El mesh se genera por codigo y no se autora en Blender. Es un **icosaedro subdividido** (162
vertices / 320 tris) desplazado por ruido cellular. Icosfera y no UV-sphere porque no tiene costuras
ni polos: el desplazamiento no puede abrir grietas por ningun lado. Las normales se recalculan
suaves y con peso por area, porque el sombreado en bandas depende enteramente de `NORMAL`.

Queda **sin UV** a proposito, y de ahi sale la decision del dissolve mas abajo. El seed y la
frecuencia viven en el script, asi que la nube es reproducible y re-tuneable sin abrir otro
programa — no es un asset opaco en disco.

## El shader

Dos modos en un uniform (`flat_shaded`), no dos shaders, para que cambiar de modo no obligue a
re-tunear el emisor:

| Modo | Que da |
|---|---|
| `flat_shaded = true` | Color plano. Silueta pura, sin volumen. |
| `flat_shaded = false` | Bandas duras de luz. **Es el default** y el que da el volumen. |

> [!important] El humo trae su propio sol
> El sombreado NO usa las luces de la escena: se calcula en `fragment()` contra un uniform
> `sun_direction`, y el resultado sale por `EMISSION` con el `ALBEDO` en negro. El humo se ilumina
> solo.
>
> Es deliberado: es un VFX de lectura, no un objeto del mundo. Con luz real el mismo push se leeria
> distinto segun donde este parado el enemigo, y quedaria plano en cualquier nivel sin sol — y el
> volumen es justo lo que tiene que ser constante. Como efecto lateral se ve igual en los dos
> mundos, sin importar la iluminacion de cada uno.
>
> El default de `sun_direction` apunta igual que el `Sun` que comparten las escenas de `world/`, asi
> que concuerda con el nivel **sin depender de el**. Si algun dia se rota el sol del juego, esto no
> se entera: hay que moverlo a mano.

Por eso el shader no tiene funcion `light()` ni necesita `diffuse_toon`/`specular_toon` en el
`render_mode`. Lo que si lleva es `cull_disabled`: la nube se lee hueca y hay que ver la cara de
atras.

Las bandas salen de un `GradientTexture1D` con **interpolacion CONSTANT** (`interpolation_mode = 1`)
— con interpolacion lineal el mismo shader da un degrade suave en vez de escalones.

### Dissolve

La nube no se desvanece por alpha: se **come** por ruido. `ALPHA` es un value noise 3D y
`ALPHA_SCISSOR_THRESHOLD` es la vida de la particula, asi que la curva de alpha del emisor decide
cuanto se comio.

El ruido es procedural en GLSL, no una textura. El mesh no trae UV, asi que una textura habria
necesitado proyeccion aparte; ademas al muestrearse en **espacio de objeto** el patron acompaña al
bulto en vez de nadar sobre el.

## Cableado y ciclo de vida

`PushSmoke` cuelga de `grounded_enemy.tscn`, que es la escena base que instancian los cinco prefabs
de enemigo, asi que se toca en un solo lugar. `EnemyBase` lo busca con `get_node_or_null`: un
enemigo sin el nodo simplemente no humea.

El emisor **no** usa `local_coords`. Las nubes quedan clavadas donde nacieron y el enemigo las va
dejando atras: eso es lo que dibuja el recorrido del empujon en vez de una nube pegada al cuerpo.

> [!important] `_end_push()` es el unico lugar donde se apaga
> El push muere por tres caminos: se agota el arco, lo corta un golpe, o aterriza antes de gastarlo.
> Antes cada camino limpiaba `_push_active` por su cuenta y no habia señal de cierre — solo
> `push_started`. Se centralizo en `_end_push()`, que ademas emite `push_ended`, para que ningun
> efecto enganchado al push pueda quedarse prendido por el camino que nadie penso.

El corte apaga la **emision**, no las particulas vivas: las nubes que ya salieron terminan su
lifetime y se disuelven solas. Cortarlas de golpe haria desaparecer la estela en el aire.

## Color

> [!warning] El humo del push NO usa color de mundo
> Se evaluo teñirlo con el color del mundo opuesto y se descarto. Ese color es el vocabulario de los
> bloques de world switch, que lo usan justamente para decir "te mando al otro lado" (ver
> [[Colores de mundo]]). Un push teñido igual hablaria ese idioma sin cumplirlo.

El color es **blanco** (`EnemyBase.push_smoke_color`) y el emisor no tiene `color_ramp` propio, o
sea que el export es la unica fuente. Blanco no significa plano: el gris lo pone la banda de sombra
del shader, no el color base.

`push_smoke_brightness` se queda en 1. Por encima de eso la estela entra en el bloom del glow, que
esta reservado a la emision de impactos y telegraphs.

## Tuning

El movimiento se tunea en el inspector nativo del emisor; el script solo maneja el look.

| Donde | Knobs |
|---|---|
| `EnemyBase` | `push_smoke_color`, `push_smoke_brightness` |
| Nodo `PushSmoke` | `amount`, `lifetime`, y todo el `ParticleProcessMaterial` |
| Material | `dissolve_scale`, `dissolve_bias`, `shadow_bands`, `shadow_roundness`, `light_attenuation`, `sun_direction`, `ambient_floor` |

Dos que se calibran contra otra cosa:

- **`lifetime`** contra cuanto dura el arco del push. Es lo que decide el **largo en el espacio** de
  la estela: si las nubes mueren antes de que el enemigo se aleje, la estela no llega a marcar todo
  el recorrido. Densidad y largo se compensan con `amount`.
- **`light_attenuation`** contra la rampa de bandas. Si satura, todas las bandas caen en la mas
  clara y vuelve el problema de origen: tres bandas configuradas, una sola visible.

`ambient_floor` es un piso de luz, no un knob de gusto: sin el, la cara en sombra se va a negro y la
nube se come el fondo en vez de leerse translucida.

## Trampas conocidas

- **El editor cachea shaders y scripts.** Editar el `.gdshader` o el `.gd` por fuera del editor no
  se refleja en el viewport ni en el inspector; `reimport` y `scan` no lo invalidan. La verificacion
  valida es **correr el juego**, que compila de cero.
- **El editor pisa ediciones de `.tscn` hechas como texto** si tiene la escena cargada en memoria:
  la re-guarda y revierte los valores. Con la escena abierta hay que editarla por el editor.
- `flat` es palabra **reservada** del lenguaje de shaders (calificador de interpolacion). Usarla
  como nombre de uniform rompe la compilacion; por eso el uniform se llama `flat_shaded`.
- El material es un `.tres` **compartido**. `SmokeStylizedVFX` lo duplica en `_ready` (solo en
  runtime) porque si no, dos emisores con distinto tinte se pisan el color entre ellos.

## Pendiente H1

- **Aprobar jugando.** El volumen se verifico en una escena de preview con las nubes grandes; a la
  escala del push (0.5–0.7, vida 0.6 s) puede que las bandas se lean demasiado chicas y haya que
  subir `shadow_roundness`.
- Decidir si el humo se usa en otro lado ademas del push.
- Sin colisiones de particulas todavia (`collision_mode` + `GPUParticlesCollision*`). Que el humo
  respete el piso y las paredes esta pendiente de saber donde mas se usa.

## H3

El estilo objetivo es 3D pixel art estilo t3ssel8r con su propio toon global ([[Direccion de Arte]]),
no cell shading anime. Este humo es **exploracion**: cuando exista el toon global hay que decidir si
se integra a el o queda como excepcion deliberada.

## Relacionado

- [[VFX]]
- [[Enemigos]]
- [[Combate]]
- [[Colores de mundo]]
- [[Direccion de Arte]]
