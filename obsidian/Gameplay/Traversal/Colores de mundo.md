---
title: Colores de mundo
tags:
  - egoist
  - gameplay
  - traversal
  - convencion
status: active
system_status: E2
hito: H1
---

# Colores de mundo

> [!important] Convencion del proyecto
> **NARANJA = mundo vivo. MORADO = mundo muerto.**
> Vale para todo el desarrollo (greybox). Cuando entre el arte definitivo se revisa, pero
> hasta entonces cualquier pieza que exista en un solo mundo, o que cambie segun el mundo,
> se pinta con estos dos colores y con ningun otro.
>
> En bloques de world switch, el color comunica el **mundo destino**, no la pertenencia
> del bloque: morado manda al muerto; naranja manda al vivo. La convencion se mantiene,
> solo se aplica al destino.

> [!important] Colores de mundo != colores de feature
> Una feature de traversal **nunca** reusa un color de mundo. Si lo hiciera, chocaria con
> el bloque de world switch que apunta a ese mundo: parado en el muerto, un bloque de
> launch y uno de "cambiar a vivo" se verian identicos. Por eso launch tiene su propio
> `COLOR_TRAVERSAL_LAUNCH` (rojo) en vez de tomar `COLOR_LIVING`.

## Donde vive

Fuente unica de verdad: `core/world.gd`. Nadie hardcodea el color en un `.tscn` ni en su
propio script. Cada color tiene su par `_EMISSION` (mas apagado) para el glow.

## Piezas de Structures: pintado por afiliacion

Las piezas greybox del pack modular de Structures se tiñen con las **texturas prototipo**
(pack CC0 de Kenney, `assets/textures/kenney_prototype-textures/`), no con color plano. Cada
afiliacion mapea a un color del pack, y `World` las expone como constantes + helpers:

```gdscript
World.PROTOTYPE_TEXTURE_LIVING  # naranja  -> mundo vivo
World.PROTOTYPE_TEXTURE_DEAD    # morado   -> mundo muerto
World.PROTOTYPE_TEXTURE_BOTH    # gris claro -> pieza en ambos mundos (Mode.BOTH)
World.PROTOTYPE_TEXTURE_NONE    # verde    -> pieza SIN afiliacion de mundo

World.prototype_material(texture)        # StandardMaterial3D triplanar (las piezas del
                                         # pack no traen UVs pensadas para esta grilla)
World.paint_all_surfaces(root, material) # pinta cada superficie de cada MeshInstance3D
```

Quien pinta segun quien tenga el modulo:

- Pieza **con `WorldMembership`**: el modulo pinta solo si su export `paint_prototype_material`
  esta en `true` (apagado por default: `WorldMembership` tambien vive en enemigos, que pintan
  su propio color en `EnemyBase` y no deben ser pisados). El color sale de `mode`/`affiliation`:
  naranja si `LIVING`, morado si `DEAD`, gris claro si `Mode.BOTH` (ignora `affiliation`). Se
  repinta cuando cambia el mundo, junto al resto de `_apply_world`.
- Pieza **sin `WorldMembership`**: lleva el modulo hijo `PrototypeDefaultPaint`, que la pinta de
  **verde** en `_ready`. Verde = "esta pieza no participa del sistema de mundos".

> [!note] Triplanar y superficies
> El material es triplanar a proposito (las UVs del pack modular no calzan con la grilla). El
> pintado recorre **todas** las superficies de cada mesh, no solo la 0 — `surface_override_material`
> es indexada, se escribe con `set_surface_override_material(idx, mat)`.

```gdscript
# Mundo
const COLOR_LIVING            := Color(1.0, 0.55, 0.05)  # naranja
const COLOR_DEAD              := Color(0.55, 0.15, 0.9)  # morado

# Feature de traversal (independientes del mundo)
const COLOR_TRAVERSAL_LAUNCH  := Color(0.9, 0.1, 0.08)   # rojo
const COLOR_TRAVERSAL_DASH    := Color(0.1, 0.85, 0.25)  # verde
const COLOR_TRAVERSAL_METER   := Color(0.15, 0.85, 1.0)  # celeste
const COLOR_TRAVERSAL_CURSE   := Color(1.0, 0.85, 0.1)   # amarillo

World.world_color(kind)    -> Color   # albedo
World.world_emission(kind) -> Color   # glow
```

## Como aplicarla

- Pieza de **un solo mundo**: se pinta con el color de ese mundo. El nombre del nodo y de
  la configuracion deberian decir cual mundo representa.
- Pieza que **existe en los dos** (misma escena, distinto `WorldMembership.affiliation`):
  un export raiz `world: World.Kind` y el material se genera por codigo desde
  `World.world_color(world)`. Ver `SpikeWall._paint_world_colors()` como referencia.
  Los materiales que queden en el `.tscn` son preview de editor, no la fuente.
- Pieza **neutra** (existe siempre, `Mode.BOTH`): no usa ninguno de los dos. Que no
  compita con la lectura de mundo.
- Pieza de **world switch**: usa el color del mundo destino (`World.opposite_world` del
  mundo actual). Un bloque morado te manda al muerto; el mismo bloque, visto desde el
  muerto, se repinta naranja para indicar que manda al vivo.

> [!warning] Tonos que compiten
> Naranja "de vivo" y amarillo "de maldicion" son vecinos. Si un bloque con maldicion deja
> de leerse contra una pieza del mundo vivo, separar los tonos. Para gritar "peligro" sin
> decir "vivo", usar forma o emision, no el color del mundo.

## Estado

| Pieza | Mundo | Pinta desde |
|---|---|---|
| `TraversalBlock` | Neutro / destino | `World` + `TraversalBlockTuning` |
| `SpikeWall` | Ambos (`world`) | `World.world_color()` |
| `WorldScan` (onda del switch) | Destino | `World.world_emission()` (ver [[World Switch]]) |
| Piezas de Structures (con `WorldMembership`) | Segun `mode`/`affiliation` | `WorldMembership.paint_prototype_material` + texturas prototipo |
| Piezas de Structures (sin `WorldMembership`) | Ninguno (verde) | `PrototypeDefaultPaint` |

## WorldEnvironment con glow

`test_scene` ya tiene un `WorldEnvironment` (Environment inline, glow HDR threshold 1.0, tonemap
Filmic, fondo oscuro). Es el bloom que hace que TODA la emision alta se lea como halo: glow de
carga de la espada, `HitSparks`, glow verde del wall slide, emision de los bloques y las
particulas brillantes del dash. Es distinto de `WorldVisual` (E0), que sera el sistema de DOS
Environments por mundo con lerp — sigue pendiente. Las particulas del dash pintan su color desde
`World.COLOR_TRAVERSAL_DASH` en codigo, nunca hardcodean el verde en el `.tscn`.

## Pendiente

- Definir el color neutro de las piezas `Mode.BOTH`.
- `WorldVisual` (E0) deberia derivar los dos Environments de estos mismos colores, partiendo del
  `WorldEnvironment` unico que ya existe.

## Relacionado

- [[Bloques]]
- [[Traversal]]
- [[Afiliacion de Mundo]]
