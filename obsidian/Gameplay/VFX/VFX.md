---
title: VFX
tags:
  - egoist
  - gameplay
  - vfx
  - sistema
status: active
system_status: E1
hito: H1
---

# VFX

Capa de efectos visuales del combate y las habilidades: lo que se ve cuando algo pasa. Vive en
`visual/`. Es una capa **puramente visual** — ningun VFX abre hitboxes, mueve cuerpos ni decide
impactos. Misma regla que [[Animacion]]: traduce estados ya resueltos a imagen.

> [!warning] Cero arte final antes de H3
> Lo que hay hoy es greybox y assets prestados (bundles Brackeys y Binbun en `assets/`, mas efectos
> procedurales sin textura). Ver [[Direccion de Arte]] para el estilo objetivo y [[Blender Pipeline]]
> para lo que se autora de verdad. Nada de esto es definitivo.

## El contrato: VfxInjector

`VfxInjector` (`visual/vfx_injector.gd`) es la unica superficie para meter un efecto en cualquier
sistema. Es **duck typing**, no una clase base: cualquier nodo que exponga `one_shot`, `play()` y
`finished` enchufa, y por eso los bundles externos funcionan sin envolverlos.

| Funcion | Que hace |
|---|---|
| `spawn_impact(scene, parent, at, ...)` | Instancia el efecto one-shot en un punto del mundo y lo auto-libera al terminar (o a los 2 s si el efecto no emite `finished`). |
| `play(vfx, loop)` | `loop = true` para un efecto permanente (el aura del brazo), `false` para one-shot. |
| `apply_look(vfx, tint, ...)` | Pinta el efecto con colores propios. Cubre las dos convenciones que conviven: `primary_color`/`secondary_color`/`emission` de los Binbun y `tint_color`/`brightness` de los flipbooks y particulas. |

Nacio duplicado dentro de `PlayerArm` (aura + impacto) y se extrajo cuando las armas necesitaron lo
mismo para el golpe.

## Quien pide efectos

Los efectos NO se referencian por ruta desde el codigo: cada sistema los declara como `PackedScene`
en su tuning, asi que cambiar un efecto es cambiar un campo en el inspector.

| Sistema | Campo | Cuando |
|---|---|---|
| Armas ([[Espada]], [[Mazo]]) | `WeaponTuning.hit_vfx_scene` · `hit_vfx_scale` | Al conectar un golpe (`WeaponBase`). |
| [[Brazo]] | `ArmTuning.vfx_scene` | Doble uso: aura permanente colgada de un `BoneAttachment3D`, y el impacto del puño. |
| [[Enemigos]] | nodo `PushSmoke` en la escena | Mientras dura el push (ver [[Humo del Push]]). No sale por `VfxInjector` ni se declara en un tuning: esta cableado en `grounded_enemy.tscn`. |
| Player | nodos `RunSmoke` y `WallSlideSmoke` en la escena | Mientras corre por el suelo o se desliza en pared. Tampoco salen por `VfxInjector`: son emisores continuos cableados en `player.tscn`. |

## Reproductores

Todos exponen el mismo contrato, asi que son intercambiables en cualquier `vfx_scene`.

| Nodo | Que es |
|---|---|
| `FlipbookVFX` | Spritesheet en grilla sobre un quad billboard (`flipbook_vfx.gdshader`). `blend_add`, asi que el fondo negro de los sheets se vuelve transparente solo. Tuneable: textura, grilla, fps, tinte, brillo. |
| `ParticleBurstVFX` | Burst de `GPUParticles3D` con un sprite suelto. El script solo pone sprite y tinte: amount, lifetime, spread y velocidad se tunean en el inspector nativo de Godot. |
| `SmokeStylizedVFX` | Nubes 3D con volumen y shader propio, no billboards. Lo usan la estela del push y el feedback continuo del Player (correr y wall slide; ver [[Humo del Push]]). |
| [[Trail]] | Estela de la hoja. Es el unico que **no** es one-shot ni sale por `VfxInjector`: genera su geometria en runtime y lo prende la ventana de dano del golpe. |

## Frontera: que NO es VFX

Los shaders que pintan el MUNDO tienen dueño propio y no viven en este nodo, aunque compartan
carpeta:

- `world_scan.gdshader` → [[World Switch]]
- `other_world_shell.gdshader` → [[Colores de mundo]]
- `camera_occlusion_fade.gd` → [[Occlusion Fade de Camara]]
- El glow de carga de la hoja y las motas de sweet spot viven en `WeaponBase` → [[Combate]], [[Sweet Spots]]

## Pendiente H1

- Decidir el efecto de impacto real de cada arma: hoy `hit_vfx_scene` toma lo que haya del bundle.
- Re-ubicar el feedback de stun y poise-chip: pintaba la capsula del player, que quedo invisible al
  entrar el maniqui UAL (ver [[Player]]).
- Tunear la estela jugando (ver [[Trail]]).

## Relacionado

- [[Trail]]
- [[Humo del Push]]
- [[Animacion]]
- [[Combate]]
- [[Direccion de Arte]]
- [[Brazo]]
