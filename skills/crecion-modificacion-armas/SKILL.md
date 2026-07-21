---
name: crecion-modificacion-armas
description: Crea, modifica, depura o migra armas de combate de Egoist V2 Godot. Usar al agregar un arma, cambiar combos, cargados, hitboxes, tuning, perfiles Mover/Floater, WeaponBase, interacción con Player/EnemyBase, o documentar el comportamiento de un arma.
---

# Creacion Y Modificacion De Armas

Implementar armas como dueñas de sus decisiones de combate. Leer `references/contrato-armas.md` antes de diseñar una ruta vertical o cambiar contratos compartidos.

## Preparacion

1. Leer `CLAUDE.md`, `METODOLOGIA.md`, `obsidian/README.md`, `obsidian/Arquitectura Godot.md` y los nodos de la bóveda sobre Combate, Armas y la arma afectada.
2. Mapear consumidores con `rg`: script, escena, tuning `.gd`/`.tres`, `WeaponBase`, `Player`, `EnemyBase`, `Hurtbox` y documentación.
3. Revisar el estado del worktree. No revertir cambios ajenos.
4. Para GDScript, seguir `godot-best-practices` y `godot-gdscript-patterns`.

## Decidir La Forma

Usar esta tabla antes de escribir código:

| Necesidad | Ubicación |
|---|---|
| Identidad, inputs, clips, orden de ataques | Script concreto del arma |
| Ventanas, hitboxes, combo, meter, impacto común | `WeaponBase` |
| Números de una arma | `WeaponTuning` extendido + `.tres` |
| Trayectoria vertical decidida por el ataque | `MoverSettings` en el tuning del arma |
| Hold o caída temporal | `float_duration`/`float_fall_scale` del Mover o `Player.request_float` |
| Ejecución física | `Player` o `EnemyBase`, nunca el arma moviendo velocity directo |
| Trayectoria balística con rebote | Diseñar un bouncer; no fingirla con un Mover lineal |

No crear una abstracción nueva si `WeaponBase`, `Mover`, `Floater`, `Hitbox`, `Hurtbox` o un Resource existente ya cubre el caso.

## Crear Un Arma

1. Crear `combat/weapons/<arma>/` con script, escena y `data/<arma>_tuning.gd`/`.tres`.
2. Extender `WeaponBase` y declarar hitboxes con `@onready` tipado. Configurarlos en `setup(player)`.
3. Definir la identidad en métodos pequeños: `tap`, holds, `play_air_step`, `air_steps` y, si corresponde, overrides de finalizadores.
4. Poner cada valor ajustable en el tuning. No esconder timings, daño, tamaños, perfiles o costes como constantes de gameplay.
5. Instanciar perfiles `MoverSettings` como subresources del `.tres`; nombrarlos por ataque y objetivo, por ejemplo `charged_y_player_mover` o `sweet_spot_enemy_mover`.
6. Registrar el arma en el loadout solo cuando su escena, tuning y setup estén completos.

## Modificar Un Arma

1. Identificar el ataque exacto y conservar su contrato: orden visual, ventana de daño, poise, meter, cancelaciones y feedback.
2. Cambiar primero el tuning y después el consumidor. Al renombrar un `@export`, migrar sus valores en cada `.tres`/`.tscn` afectado.
3. Mantener los cambios acotados a la arma y a las primitivas compartidas necesarias. No migrar Mace como efecto colateral de otra arma.
4. Si una ruta vieja usa `launch`, `slam`, `air_hop` o velocity directo, reemplazarla por perfiles antes de extenderla.

## Contrato Vertical Obligatorio

- El ataque decide perfiles; Player y EnemyBase solo los ejecutan o cancelan.
- Usar `Player.request_mover(settings)` y `EnemyBase.request_mover(settings, stun, starts_lying)`.
- Usar `request_float` solo para Floater; stun y hang son conceptos distintos.
- Usar Mover `TOTAL` cuando debe tomar el desplazamiento completo. Usar `PARTIAL` solo para controlar Y del Player mientras mantiene contactos y locomoción.
- Un hit posterior sobre EnemyBase debe cancelar Mover y Floater anteriores. Un Mover preparado en `about_to_hit` debe sobrevivir exactamente a su propio hit.
- Para mover antes del daño y consultar poise, pedir el Mover desde `Hitbox.about_to_hit`; pasar el `StunSettings` únicamente como gate.
- No escribir `vertical_velocity`, `velocity.y`, `launch`, `slam` o `slam_bounce` desde una arma nueva.

## Orden De Un Ataque Vertical

1. El arma selecciona el perfil desde su tuning.
2. Si el control debe existir antes del daño, pide `request_mover` en `about_to_hit`.
3. El hit cobra daño y stun.
4. El Mover termina y, si el perfil lo define, inicia Floater.
5. Otro impacto relevante cancela el control previo del Enemy.

## Calidad Y Cierre

1. Revisar con `rg` que no queden verbos legacy en la ruta migrada.
2. Ejecutar `git diff --check`.
3. Ejecutar import/headless solo si existe el ejecutable de Godot y el usuario no lo prohibió.
4. Nunca crear, modificar ni ejecutar smoke tests cuando el usuario haya dado esa instrucción.
5. Actualizar los nodos de Obsidian afectados, en especial el mapa de autoridad vertical y la nota de la arma.
6. Informar qué cambió, qué se verificó y qué rutas quedan pendientes. No afirmar que una arma está lista de feel sin prueba jugable.
