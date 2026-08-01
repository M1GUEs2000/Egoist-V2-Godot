---
title: Trail
tags:
  - egoist
  - gameplay
  - vfx
  - combate
status: active
system_status: E2
hito: H1
---

# Trail

Estela de la hoja: el arco que deja el arma al golpear. Subnota de [[VFX]].

| Pieza | Archivo |
|---|---|
| Nucleo | `visual/ribbon_trail.gd` (`RibbonTrail`) |
| Nodo | `visual/sword_trail.gd` (`SwordTrail`) |
| Shader | `visual/sword_trail.gdshader` |
| Tuning | `SwordTrailTuning` → `data/sword_trail_tuning.tres` |
| Check | `tools/check_sword_trail.gd` |

## Es procedural, no una card

No hay mesh ni textura de arco en disco. Cada frame se muestrea el par (base, punta) de la hoja en
coordenadas de **mundo**, las muestras mueren a los `lifetime` segundos y las vivas se emiten como
una tira de triangulos (`ImmediateMesh`, `PRIMITIVE_TRIANGLE_STRIP`).

La forma sale del **movimiento real** del hueso `hand_r`, que es donde `PlayerAnimationController`
cuelga la hoja (ver [[Animacion Espada]]). Es lo que hace que el arco no pueda desincronizarse del
golpe: no hay una segunda fuente de verdad que alinear.

El nodo es `top_level` a proposito. Sus vertices ya estan en mundo, asi que si heredara el transform
del arma o del Player la estela viajaria con el jugador en vez de quedarse donde se dibujo — que es
exactamente lo que la haria dejar de ser una estela.

> [!important] Cuando se dibuja NO se tunea
> La prende y apaga `WeaponBase.begin_damage_window` junto al hitbox de la hoja, o sea que sale de
> los mismos `hitbox_open`/`hitbox_close` del [[Contrato AttackClip|AttackClip]] del paso. Por eso
> cubre de una los dos combos, los cuatro taps direccionales, el X cargado y la Y cargada **sin
> tocar `sword.gd`**: se engancho donde ya se abria la hoja, no gesto por gesto.

El cierre usa `stop()` y no un corte seco: la cola que ya se dibujo se desvanece sola por su
`lifetime`, asi un golpe interrumpido no hace desaparecer el arco de golpe.

## Contrato nodo ↔ shader

Las dos UV de la tira son toda la superficie compartida:

| UV | Significado |
|---|---|
| `UV.x` | **Edad** de la muestra. 0 = recien salida de la hoja, 1 = la cola a punto de morir. |
| `UV.y` | **A lo ancho** de la hoja. 0 = base (empunadura), 1 = punta. |

El shader es `blend_add`, `unshaded` y `depth_draw_never` (para que la tira no se tape a si misma
donde se cruza a mitad del swing), pero conserva el depth **test**: la estela no se ve a traves de
las paredes.

## Cableado en la escena

En `sword.tscn`: `TrailBase` y `TrailTip` son `Marker3D` hijos del `BladeMesh`, asi que viajan solos
al hueso con el reparent del payload (`hand_attachment_payload`). El nodo `Trail` cuelga de la raiz
del arma y **no** lleva ese grupo.

Los markers se declaran como `NodePath` pero se resuelven UNA vez en `_ready` y lo que se guarda es
la referencia al nodo: despues del reparent el path relativo ya no resuelve, pero el nodo es el mismo
objeto y sigue devolviendo la posicion correcta.

El Mazo no tiene estela: `WeaponBase` busca el nodo `Trail` por nombre y es opcional. El segundo uso
real de `RibbonTrail` es `SprintTrail`: usa dos markers laterales del Player para dibujar una cinta
plana en su recorrido (ver [[Sprint]]), no el ancho de una hoja.

## Tuning

`SwordTrailTuning` esta agrupado por decision, no por tipo de dato.

| Grupo | Knobs | Que decide |
|---|---|---|
| Color | `gradient`, `brightness` | El gradiente se recorre por edad: su extremo izquierdo es lo que acaba de salir de la hoja. **Su alpha es lo que apaga la cola** — un gradiente que termina opaco deja la estela cortada en seco. |
| Forma | `lifetime`, `base_fade`, `min_sample_distance`, `max_segment_length` | `lifetime` ES el largo del arco. `base_fade` afina la estela hacia la empunadura, que es lo que la hace leer como un corte y no como una cinta. |
| Erosion | `erosion_noise`, `erosion_scale`, `erosion_scroll`, `erosion_strength`, `erosion_softness` | Rompe el borde de la cola. El ruido es procedural (`NoiseTexture2D` + `FastNoiseLite`), sin PNG en disco. |

Dos que se calibran contra otra cosa y no a ojo:

- **`lifetime`** contra el largo del golpe (los pasos de la cadena rondan 0.4 s). Por encima de eso
  la estela sobrevive al propio golpe y se empieza a ver desprendida de la hoja.
- **`max_segment_length`** contra la velocidad real del swing. Si la hoja salta mas que esto entre
  dos frames la estela se **corta** en vez de tender una banda recta gigante: es la proteccion
  contra los teleports que el juego ya tiene (el X cargado que atraviesa al enemigo, el world
  switch). Tiene que ser mayor que lo que la punta recorre en un frame a pleno swing — si no, se
  corta sola a mitad de golpe — y menor que el salto del dash.

## Pendiente H1

- **Tunear jugando.** Los valores de hoy son un punto de partida, no una decision de feel.
- El gradiente por defecto va blanco a azul y convive con un glow de carga naranja
  (`WeaponBase.charge_glow_color`): son dos vocabularios distintos, decidir cual manda.
- Falta la capa de **highlight** (ver [[Animacion Espada]] > H3): sobre lo que ya existe es una
  segunda tira mas delgada con su propio gradiente. `base_fade` es hoy un sustituto pobre.

## H3

Cambiar la estela procedural por una **slash card** — mesh de arco autorado, capas base / highlight
/ support. El intercambio completo y por que espera a H3 estan en [[Animacion Espada]] > H3.

## Relacionado

- [[VFX]]
- [[Animacion Espada]]
- [[Espada]]
- [[Contrato AttackClip]]
- [[Combate]]
