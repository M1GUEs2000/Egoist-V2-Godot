---
title: Direccion de Arte — 3D Pixel Art
tags:
  - egoist
  - arte
  - decision
status: planned
hito: H3
---

# Direccion de Arte — 3D Pixel Art

> [!important] Decision comprometida
> El estilo visual objetivo de Egoist **siempre fue** el 3D pixel art estilo
> **t3ssel8r**: escena 3D real renderizada a baja resolucion con luz escalonada
> y contornos, que se lee como pixel art prerenderizado pero se mueve como 3D.
> No es una idea potencial — es la meta de H3. Hasta H3 sigue la regla madre:
> cero arte final, greybox y claridad mecanica.

## El stack tecnico (referencia: video breakdown del estilo t3ssel8r)

| Pieza | Como se logra | Nota para Godot 4.7 |
|---|---|---|
| Pixeles gordos | `SubViewport` a **640x360** escalado a pantalla completa | Config de escena, sin shaders |
| Sin deformacion de pixeles | Camara **ortogonal** (near y far del mismo tamano: nada cambia de tamano con la distancia) + pitch -30° | Nuestro `CameraRig` ya usa pitch 30 — el encuadre calza |
| Luz escalonada | Toon shader: clampear la iluminacion a 3-4 umbrales fijos | Shader de luz custom |
| Contornos | Post-proceso en dos partes: **depth** vs vecinos = silueta; **dot product de normales** vs vecinos = aristas internas. La atenuacion de luz aclara/oscurece el borde | Shader de pantalla sobre el SubViewport |
| Modelos estilizados | Blender: cubo → subsurf → remesh → displacement con noise → decimate planar → triangulate. Cellular noise = ladrillos | Encaja en el workflow de [[Blender Pipeline]] |
| Pasto/follaje | MultiMesh de quads billboard; cada hoja sombreada con la luz del **origen del modelo** (un solo tono por instancia) | En Godot 4 sale con `varying` vertex→fragment, **sin recompilar el engine** |

## Impacto en sistemas existentes (para cuando llegue H3)

- **[[Camara]] / [[Lock On]]**: el zoom del lock-on (`lock_zoom_*`) funciona por
  **distancia** — en proyeccion ortogonal la distancia no cambia nada. Habra que
  reimplementarlo sobre el `size` de la proyeccion. Pasar a ortogonal regresa
  Camara y Lock-on un estado (E3→E2) hasta re-probarse jugando.
- **[[Colores de mundo]] / [[Bloques]]**: la legibilidad actual vive en emision,
  OmniLights y particulas aditivas. A 640x360 con luz escalonada, el glow y el
  bloom se comportan distinto — revalidar que bloques, mundos y telegraphs se
  sigan leyendo.
- **Rendimiento**: renderizar a 640x360 es mas barato que resolucion nativa —
  el estilo juega a favor, no en contra.

## Que NO hacer antes de H3

- No cambiar la camara a ortogonal ahora: la cámara esta aprobada jugando (E3)
  en perspectiva y el feel de H1 se valida sobre eso.
- No escribir los shaders todavia: sin el greybox final, tunear umbrales de toon
  y contornos es trabajo tirado.
- Si se disenan features nuevas de camara, tener presente que el destino es
  ortogonal: evitar mecanicas que dependan de la perspectiva.

## Relacionado

- [[Blender Pipeline]]
- [[Camara]]
- [[Colores de mundo]]
- [[hitos]]
