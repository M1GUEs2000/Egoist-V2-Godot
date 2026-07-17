---
title: Blender Pipeline
tags:
  - egoist
  - arte
  - blender
status: planned
hito: H3
---

# Blender Pipeline

El arte final empieza en H3. Antes de eso, placeholders y greybox.

El estilo objetivo es el 3D pixel art (ver [[Direccion de Arte]]): este pipeline
produce los modelos que ese estilo renderiza — el workflow de displacement con
noise + decimate planar de esa nota entra en el paso de modelado low-poly.

## Targets

| Asset | Tris | Textura |
|---|---:|---|
| Mascara | 1k-2k | 512 |
| Jugador | 8k-15k | 2048 + mascara |
| Enemigo estandar | 3k-6k | 1024 |
| Jefe | 15k-25k | 2x2048 |
| Props | 0.5k-3k | Atlas por area |

## Workflow por asset

1. Silueta.
2. Blockout.
3. Modelado low-poly.
4. UVs y textura.
5. Rig si aplica.
6. Export GLB/FBX para Godot.

## Convenciones

- `SK_` para skeletal.
- `SM_` para static mesh.
- Modelar para camara isometrica, no para close-up.

## Relacionado

- [[Direccion de Arte]]
- [[Personaje y Mascara]]
- [[Playa Arte]]
- [[Enemigos Arte]]

