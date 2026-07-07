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

## 4. Pendientes conocidos

- No se pudo correr Godot headless desde esta maquina porque no existe `godot` en PATH ni `C:\Users\Tutupa\Downloads\Godot_v4.7-stable_win64.exe`.
- Al abrir en Godot, revisar que el editor genere el `.uid` del script nuevo `ui/action_loadout_menu.gd` si lo necesita.
- La UI por ahora solo lista armas que ya sean nodos hijos del `Player` y hereden de `WeaponBase`.
- Por ahora solo existe `Sword`, pero el flujo queda preparado para mas armas.
- No hay persistencia/save de loadout todavia.

## 5. Sugerencia para nodos de boveda

Actualizar o crear nodos para:

- `archivo-grounded-enemy.md`
- `archivo-perception.md`
- `flujo-ia-enemigos-hostilidad.md`
- `flujo-seleccion-acciones-xy.md`
- `archivo-player-combat.md`
- `archivo-action-loadout-menu.md`

Si ya existen nodos equivalentes, actualizar secciones en vez de duplicar.
