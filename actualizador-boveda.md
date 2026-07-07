# Actualizador de Boveda - Egoist V2

Este archivo resume los cambios recientes que hay que pasar a la boveda de Obsidian cuando se trabaje desde la casa. Cubre dos bloques grandes: IA de enemigos y UI de seleccion de acciones X/Y.

## 1. IA de enemigos por hostilidad

Commit relacionado:

- `6fb37d1 feat(enemigos): ampliar FSM y vision por hostilidad`

### Objetivo

Se amplio la IA de enemigos para que todos compartan un catalogo comun de estados, pero cambien su intencion segun hostilidad:

- `PASSIVE`
- `REACTIVE`
- `AGGRESSIVE`
- `ULTRA_AGGRESSIVE`

La idea principal es que un enemigo ya no sea omnisciente. La deteccion ahora debe pasar por rango, angulo y raycast, y la persecucion se corta cuando pierde linea de vision y se agota la memoria.

### Estados agregados a la FSM

El enum `AIState` de `GroundedEnemy` ahora contiene:

- `IDLE`
- `ROAM`
- `ACTIVITY`
- `ALERT`
- `CHASE`
- `GUARD`
- `SEARCH`
- `ATTACK_MELEE`
- `ATTACK_RANGED`
- `ATTACK_GROUP`
- `EVADE`
- `DEFEND`
- `CALL_HELP`
- `FLEE`
- `HIDE`

Cada enemigo puede activar o desactivar estados con `allowed_state_flags`. Si un estado no esta permitido, la FSM cae al fallback mas cercano.

### Reglas principales

#### PASSIVE

- No inicia combate solo por ver al jugador.
- Si lo atacan, puede reaccionar.
- `SEARCH` funciona como investigacion/curiosidad.
- Puede huir al cruzar 30% de vida con 50% de chance.
- `HIDE` solo ocurre despues de `FLEE`.
- Tiene toggle `passive_remembers_attackers`.

#### REACTIVE

- Defiende territorio.
- Ataca si el jugador entra demasiado cerca o invade zona.
- `SEARCH` busca intruso.
- Puede huir al cruzar 30% de vida con 25% de chance.
- `HIDE` solo ocurre despues de `FLEE`.

#### AGGRESSIVE

- Busca y ataca al jugador si lo detecta.
- `SEARCH` intenta recuperar al jugador perdido.
- Puede huir al cruzar 30% de vida con 5% de chance.
- `HIDE` solo ocurre despues de `FLEE`.

#### ULTRA_AGGRESSIVE

- Berserker.
- Ataca cualquier objetivo valido.
- Puede cambiar a otro objetivo si aparece uno mejor.
- No usa `FLEE`, `HIDE`, `GUARD` ni `ATTACK_GROUP`.
- Su actividad conceptual queda limitada a dormir o comer presas.

### Percepcion y memoria

`Perception` ahora usa:

- rango de vision,
- angulo de vision,
- raycast contra mundo,
- ultima posicion conocida,
- memoria variable por hostilidad.

Memorias por defecto:

- Pasivo: `10s`
- Reactivo: `20s`
- Agresivo: `40s`
- Ultra agresivo: `60s`

### FLEE / HIDE

`FLEE` se evalua una sola vez al cruzar `current / max_health <= 0.30`.

Probabilidades:

- Pasivo: `0.50`
- Reactivo: `0.25`
- Agresivo: `0.05`
- Ultra agresivo: `0.0`

Si la tirada falla, no se vuelve a intentar para esa bajada de vida. `HIDE` no se activa solo; solo puede venir despues de `FLEE`.

### Archivos tocados para IA

- `enemies/grounded_enemy.gd`
  - Expande `AIState`.
  - Agrega `allowed_state_flags`.
  - Agrega `passive_remembers_attackers`.
  - Agrega chances de `FLEE` por hostilidad.
  - Conecta `Health.damaged`.
  - Maneja memoria pasiva, persecucion, busqueda, huida y hide.

- `enemies/perception.gd`
  - Quita deteccion omnisciente de agresivos y ultra agresivos.
  - Centraliza rango, angulo, raycast y memoria.
  - Agrega memoria por hostilidad.

- `enemies/ground_locomotion.gd`
  - Agrega movimiento de huida con `flee_from`.
  - Agrega `stop` para estados pasivos/guard/hide.

- `enemies/enemy_base.gd`
  - Ajusta la reaccion de pasivos atacados para delegar en `_on_passive_attacked`.

## 2. Escena de prueba para enemigos

Commit relacionado:

- `56352a7 feat(mundo): ampliar escena de prueba con enemigos`

### Objetivo

Ampliar la escena para poder probar grupos de hostilidad sin construir un nivel final.

### Cambios

- `world/test_scene.tscn`
  - Piso ampliado de `40x40` a `160x160`.
  - Se agregan 4 enemigos pasivos en circulo.
  - Se agregan 2 enemigos reactivos mas lejos.
  - Se agregan 2 enemigos agresivos todavia mas lejos.
  - Se agrega 1 enemigo ultra agresivo en el mundo muerto.
  - El ultra agresivo tiene desactivados `FLEE`, `HIDE`, `GUARD` y `ATTACK_GROUP` via `allowed_state_flags`.

## 3. UI de seleccion de acciones X/Y

Cambios actuales pendientes de commit al crear este documento.

### Objetivo

Crear un overlay funcional para asignar armas a los slots `X` y `Y` sin pausar el juego.

Reglas:

- Se abre/cierra con `Tab`.
- El juego sigue corriendo.
- Se muestran los dos slots: `X` y `Y`.
- Al presionar un slot, se muestran todas las armas disponibles.
- La misma arma puede estar asignada en ambos slots.
- Si un slot no tiene arma asignada, al presionarlo no ocurre nada.

### Flujo de uso esperado

1. El jugador presiona `Tab`.
2. Aparece el overlay de acciones.
3. El jugador selecciona `X` o `Y`.
4. El jugador elige un arma de la lista.
5. El slot se actualiza.
6. El jugador puede cerrar con `Tab` o con el boton `Cerrar`.

### Archivos tocados para UI

- `project.godot`
  - Agrega input action `open_loadout_menu`.
  - Tecla por defecto: `Tab`.

- `ui/action_loadout_menu.tscn`
  - Nueva escena UI.
  - Root `Control`.
  - Fondo semitransparente que no pausa el juego.
  - Panel central con botones `Slot X`, `Slot Y`, lista de armas y boton cerrar.

- `ui/action_loadout_menu.gd`
  - Nuevo controlador del overlay.
  - Recibe el `Player` por `setup(player)`.
  - Lee `player.combat`.
  - Alterna visibilidad con `toggle`.
  - Reconstruye la lista de armas desde `PlayerCombat.available_weapons`.
  - Llama `PlayerCombat.set_slot_weapon` al equipar.

- `ui/hud.tscn`
  - Instancia `ActionLoadoutMenu` dentro del HUD.

- `ui/hud.gd`
  - Conecta el menu con el player cuando el HUD hace bind.
  - Escucha `open_loadout_menu`.
  - Abre/cierra el overlay sin tocar `get_tree().paused`.

- `player/player_combat.gd`
  - Agrega signal `slots_changed`.
  - Agrega `available_weapons`.
  - Agrega `set_slot_weapon`.
  - Agrega `weapon_label`.
  - Ajusta `_on_press` para que un slot vacio no haga nada:
    - no ataca,
    - no dispara `fire_action_world_switch`,
    - no actualiza `_last_attack_time`,
    - no cuenta como arma afuera.

## 4. Segunda arma: Maso

Cambios actuales pendientes de commit al actualizar este documento.

### Objetivo

Agregar una segunda arma seleccionable para probar el selector X/Y y validar que el player puede equipar armas distintas o repetir la misma arma en ambos slots.

Por ahora el `Maso` reutiliza la logica de `Sword`; no define combos propios todavia. El cambio es visual y funcional para pruebas de equipamiento.

### Archivos creados/tocados para Maso

- `combat/weapons/mace/mace.gd`
  - Nuevo script `Mace`.
  - Hereda de `Sword`.
  - Reutiliza el comportamiento actual hasta que existan combos propios.

- `combat/weapons/mace/mace.tscn`
  - Nueva escena de arma.
  - Visual de palo con bola al final.
  - Mantiene los nombres de hitboxes esperados por `Sword`:
    - `Pivot/BladeHitbox`
    - `AirDiscHitbox`
    - `LauncherHitbox`
    - `ChargedDashHitbox`

- `player/player.tscn`
  - Instancia el `Maso` como hijo del player.

- `player/player_combat.gd`
  - Refresca visibilidad de armas equipadas.
  - Permite que solo se vea lo asignado en slots.

### Guia para Obsidian

Crear o actualizar:

- `archivo-mace.md`
- `archivo-player-combat.md`
- `flujo-seleccion-acciones-xy.md`

Punto clave para documentar: es una arma de prueba, no una familia de combos nueva.

## 5. Wall slide del jugador

Cambios actuales pendientes de commit al actualizar este documento.

### Objetivo

Agregar un modulo tuneable para que el jugador pueda deslizarse por paredes sin mezclar esa logica dentro del motor principal.

Reglas:

- El jugador debe estar en el aire.
- Debe presionar input hacia la pared.
- Debe venir con suficiente momentum horizontal.
- Se pega una fraccion breve y luego cae controlado.
- El wall jump empuja hacia arriba, hacia afuera de la pared y conserva algo de direccion lateral.
- Se cancela si el jugador toca suelo, dashea, es lanzado, recibe bump o entra en stun.

### Archivos creados/tocados para wall slide

- `player/player_wall_slide.gd`
  - Nuevo modulo `PlayerWallSlide`.
  - Detecta pared usando las colisiones de `CharacterBody3D` despues de `move_and_slide`.
  - Filtra contra `World.LAYER_WORLD`.
  - Expone:
    - `apply_slide_velocity`
    - `update_after_move`
    - `try_wall_jump`
    - `cancel`

- `data/player_tuning.gd`
  - Agrega grupo `Wall slide`.
  - Valores tuneables:
    - `wall_slide_min_push_speed`
    - `wall_slide_input_dot`
    - `wall_slide_stick_time`
    - `wall_slide_stick_fall_speed`
    - `wall_slide_max_fall_speed`
    - `wall_slide_gravity_scale`
    - `wall_slide_momentum_decay`
    - `wall_slide_wall_jump_up_speed`
    - `wall_slide_wall_jump_away_speed`
    - `wall_slide_wall_jump_along_speed`
    - `wall_slide_wall_jump_lock_time`

- `player/player.tscn`
  - Agrega nodo hijo `WallSlide`.

- `player/player.gd`
  - Orquesta el modulo.
  - Llama `wall_slide.setup(self)`.
  - Integra el deslizamiento antes/despues de `move_and_slide`.
  - Intenta `wall_slide.try_wall_jump()` en salto.
  - Cancela wall slide en dash, launch, bump, stun y aterrizaje.

### Guia para Obsidian

Crear o actualizar:

- `archivo-player-wall-slide.md`
- `archivo-player.md`
- `flujo-movimiento-jugador.md`

Punto clave para documentar: `Player` sigue siendo el orquestador, pero la decision fina del wall slide vive en un nodo hijo componible.

## 6. Stun universal y resistencia por threshold

Cambios actuales pendientes de commit al actualizar este documento.

### Objetivo

Separar dos responsabilidades:

- La fuente del stun define potencia y duracion.
- El receptor define si ese stun entra o no segun su threshold.

Esto permite que player y enemigos compartan el mismo criterio:

`stun_power >= effective_stun_threshold`

Si la potencia no supera el threshold, no hay stun. Si lo supera, se aplica la duracion y el tipo correspondiente.

### Reglas nuevas

- `StunSettings` ahora tiene `power`.
- Player y enemigos tienen:
  - `stun_threshold`
  - `armor_stun_threshold`
- La armadura ya no es inmunidad absoluta al stun.
- La armadura sube el threshold requerido.
- `apply_stun` queda como aplicacion directa.
- `try_apply_stun` y `receive_stun` son la entrada normal para fuentes que deben respetar resistencia.

### Tipos de stun del player

El player usa `PlayerStun.Mode`:

- `STILL`
  - Suspende input/control y deja al jugador quieto.

- `PUSH`
  - Suspende input/control.
  - Aplica empuje horizontal.
  - Aplica velocidad vertical.
  - Se usa para pinchos, rebotes y golpes que desplazan.

### Archivos creados/tocados para stun

- `player/player_stun.gd`
  - Nuevo modulo `PlayerStun`.
  - Mantiene duracion, modo y fin del stun.
  - Emite:
    - `stunned_started`
    - `stunned_ended`

- `player/player.gd`
  - Agrega `is_stunned`.
  - Bloquea input durante stun.
  - Agrega:
    - `receive_stun`
    - `try_apply_stun`
    - `apply_stun`
  - Procesa fisica durante stun con `_tick_stunned`.
  - Cancela locomotion, wall slide, launcher, dash y buffer de combate al entrar en stun.

- `player/player.tscn`
  - Agrega nodo hijo `Stun`.

- `player/player_combat.gd`
  - Agrega `cancel_input`.
  - Ignora inputs de ataque mientras el player esta stunned.

- `data/player_tuning.gd`
  - Agrega grupo `Stun`.
  - Valores:
    - `default_stun_duration`
    - `stun_threshold`
    - `armor_stun_threshold`
    - `stun_gravity_scale`
    - `stun_bump_decay`

- `data/stun_settings.gd`
  - Agrega `power`.
  - Agrega `beats_threshold`.

- `enemies/enemy_base.gd`
  - Agrega `stun_threshold`.
  - Agrega `armor_stun_threshold`.
  - Agrega:
    - `receive_stun`
    - `try_apply_stun`
    - `_effective_stun_threshold`
  - Cambia armadura de inmunidad absoluta a threshold elevado.

- `enemies/attacks/melee_attack.gd`
  - Si el ataque enemigo tiene `StunSettings`, llama `receive_stun` en el target.

### Guia para Obsidian

Crear o actualizar:

- `flujo-stun-universal.md`
- `archivo-player-stun.md`
- `archivo-stun-settings.md`
- `archivo-enemy-base.md`
- `archivo-player.md`

Punto clave para documentar: los objetos que stunean no deciden si el target queda stunned; solo mandan potencia/duracion/tipo. El receptor decide con su threshold efectivo.

## 7. Spike wall del mundo vivo

Cambios actuales pendientes de commit al actualizar este documento.

### Objetivo

Crear una pared de pinchos reusable que pertenezca al mundo vivo y castigue contacto directo con stun + rebote.

Reglas:

- La pared es `StaticBody3D`.
- Pertenece al mundo vivo mediante `WorldMembership`.
- Tiene colision fisica contra el jugador.
- Tiene un `Area3D` trigger para detectar contacto.
- Al tocarla:
  - calcula la normal perpendicular hacia afuera,
  - aplica `PlayerStun.Mode.PUSH`,
  - empuja horizontalmente,
  - da velocidad vertical,
  - restaura doble salto,
  - restaura airdash.
- Tiene cooldown para evitar multiples rebotes por frame.
- Si el mundo actual no es `LIVING`, apaga visuales, colisiones y trigger.

### Archivos creados/tocados para spike wall

- `world/blocks/spike_wall.gd`
  - Nuevo script `SpikeWall`.
  - Exporta:
    - `stun_duration`
    - `stun_power`
    - `push_horizontal_speed`
    - `push_vertical_speed`
    - `hit_cooldown`
  - Usa `try_apply_stun` del player para respetar threshold.
  - Restaura double jump y airdash tras el rebote.
  - Escucha `WorldMembership.changed` para apagar tambien el `Area3D` trigger.

- `world/blocks/spike_wall.tscn`
  - Nueva escena reusable.
  - Root `StaticBody3D`.
  - Incluye `CollisionShape3D`.
  - Incluye visual negro/morado para mundo vivo y pinchos rojos.
  - Incluye `Trigger` como `Area3D`.
  - Incluye `WorldMembership` con `affiliation = LIVING`.

- `world/test_scene.tscn`
  - Instancia `LivingSpikeWall` en la escena de prueba.
  - Queda disponible para probar contacto y cambio de mundo.

### Guia para Obsidian

Crear o actualizar:

- `archivo-spike-wall.md`
- `flujo-obstaculos-traversal.md`
- `flujo-stun-universal.md`
- `archivo-world-membership.md`

Punto clave para documentar: `WorldMembership` apaga colisiones directas del padre, pero la spike wall apaga manualmente su `Area3D` trigger porque el trigger vive como nodo hijo separado.

## 8. Pendientes conocidos

- No se pudo correr Godot headless desde esta maquina porque no existe `godot` en PATH ni `C:\Users\Tutupa\Downloads\Godot_v4.7-stable_win64.exe`.
- Al abrir en Godot, revisar que el editor genere el `.uid` del script nuevo `ui/action_loadout_menu.gd` si lo necesita.
- La UI por ahora solo lista armas que ya sean nodos hijos del `Player` y hereden de `WeaponBase`.
- Por ahora solo existe `Sword`, pero el flujo queda preparado para mas armas.
- No hay persistencia/save de loadout todavia.
- Revisar en engine los valores de `wall_slide_*` y `stun_*` porque son de primer pase.
- Revisar en engine que el `Trigger` de `SpikeWall` se apague correctamente al cambiar al mundo muerto.

## 9. Sugerencia para nodos de boveda

Actualizar o crear nodos para:

- `archivo-grounded-enemy.md`
- `archivo-perception.md`
- `flujo-ia-enemigos-hostilidad.md`
- `flujo-seleccion-acciones-xy.md`
- `archivo-player-combat.md`
- `archivo-action-loadout-menu.md`
- `archivo-mace.md`
- `archivo-player-wall-slide.md`
- `archivo-player-stun.md`
- `archivo-stun-settings.md`
- `archivo-spike-wall.md`
- `flujo-stun-universal.md`
- `flujo-obstaculos-traversal.md`
- `flujo-movimiento-jugador.md`

Si ya existen nodos equivalentes, actualizar secciones en vez de duplicar.
