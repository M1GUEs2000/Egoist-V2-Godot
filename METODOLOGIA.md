# Metodología de desarrollo — Egoist v2

Guía operativa para trabajar en este proyecto. Tres operaciones posibles — **crear**, **modificar**, **borrar** — cada una con su flujo, y un **ciclo de vida por sistema** (estados E0–E4) que registra qué tan maduro está cada uno. Complementa (no reemplaza) las reglas duras del `CLAUDE.md`.

## Qué skill invocar y cuándo

| Skill | Cuándo |
|---|---|
| `/godot-gdscript-patterns` | Al **diseñar** un sistema nuevo de gameplay: elegir patrón (state machine, autoload, Resource, componente, pooling) y ver implementaciones de referencia. |
| `/godot-ui` | Todo lo que toque `ui/`: HUD, menús, inventario, diálogos. Control nodes, containers, anchors, themes, focus para gamepad. |
| `/godot-best-practices` | Al **escribir o revisar** GDScript: naming, tipado, orden de secciones del script, señales tipadas, anti-patrones. Es el estándar de estilo de este repo. |

Regla práctica: patterns para decidir **qué** construir, best-practices para decidir **cómo** escribirlo, ui para todo lo visible en pantalla.

---

## Ciclo de vida de un sistema: estados E0–E4

Todo sistema sigue el ciclo **crear → probar → tunear → clasificar**. "Commiteado" no es "terminado": el código completo y el feel terminado son ejes distintos. Cada sistema tiene un estado en la tabla de abajo, definido por un criterio verificable (no por porcentajes: dan precisión falsa y se desactualizan).

| Estado | Nombre | Criterio de entrada (pregunta contestable) |
|---|---|---|
| **E0** | Inutilizable | No cumple su función o rompe otras cosas. No se juega con esto. (Los stubs planificados también son E0.) |
| **E1** | Utilizable — falta tunear mucho | Funciona mecánicamente, pero los knobs correctos **quizás ni existen** todavía; la dirección del feel es desconocida. |
| **E2** | Utilizable — falta tunear | Los knobs correctos ya existen en su `.tres` (o exports, si aplica la excepción de enemigos) y la dirección está clara; solo falta iterar valores jugando. |
| **E3** | Últimos detalles | El feel ya fue **aprobado jugando**; faltan juice, edge cases, pulido visual. |
| **E4** | Lista | Aprobada jugando; no se toca salvo bug. |

**Gates de promoción** (quién decide):
- Hasta **E2** promueve Claude: es verificable en el código (funciona + knobs en tuning).
- **E2→E3** y **E3→E4** solo las decide **Tutupa jugando**. El feel no se verifica headless.

**Regresión automática**: modificar un sistema E3/E4 lo baja a **E3 → E2** o **E4 → E3** hasta que se re-pruebe jugando. Un refactor no conserva la aprobación de feel que tenía el código anterior.

**Mantenimiento**: la tabla *Estado de los sistemas* (al final de este archivo) se actualiza **en el mismo commit** que cambia el estado.

---

## 1. CREAR un sistema nuevo

### 1a. Antes de escribir una línea

1. **¿Ya existe?** Revisar los módulos actuales — el proyecto ya tiene Health, Hurtbox/Hitbox, InputBuffer, WorldMembership, `run_combo_chain`, Perception, GroundLocomotion, ataques componibles. No duplicar lo que un módulo existente ya resuelve o casi resuelve.
2. **¿Qué tipo de pieza es?** Tabla de decisión:

| El sistema es… | Entonces es… | Ejemplo existente |
|---|---|---|
| Estado global que TODOS leen | Autoload (última opción; solo servicios finos, sin lógica de gameplay) | `WorldManager`, `ComboTracker` |
| Comportamiento adjuntable a un dueño | Nodo hijo componible con `setup(body)` | `WorldMembership`, `MeleeAttack` |
| Números tuneables | Resource `.gd` + instancia `.tres` en `data/` | `PlayerTuning`, `SwordTuning` |
| Aviso de que algo pasó | Señal (pasado, snake_case, tipada) | `Health.died`, `Hurtbox.hit` |
| Verbo opcional del dueño | Duck typing `has_method()` | `launch` / `slam` / `try_parry` |
| Algo visible en pantalla | `CanvasLayer` + Controls que SOLO escuchan señales | `HUD` |

3. **¿Dónde vive?** Estructura feature-based: escena + script juntos en la carpeta del dominio (`player/`, `combat/`, `enemies/`, `world/`, `ui/`, `visual/`). Nada de carpetas `scripts/` y `scenes/` separadas.

### 1b. Contratos del proyecto (checklist al implementar)

- [ ] `class_name` + **tipado estático total** (variables, parámetros, retornos).
- [ ] Orden de secciones: señales → enums → exports → consts → vars públicas → vars privadas (`_`) → `@onready` → lifecycle → métodos públicos → privados.
- [ ] Comunicación: **señal hacia arriba, llamada hacia abajo**. Nunca `get_parent().get_parent()`, nunca polling de estado que una señal puede avisar.
- [ ] Capas de física por código desde `World.LAYER_*` en `_ready` — nunca a mano en el editor.
- [ ] Tiempo: `World.now()`. Módulo hermano: `World.find_sibling()`. No reinventarlos.
- [ ] Todo tunable nace en un Resource `.tres` en `data/` (excepción documentada: enemigos usan `@export` por escena hasta el 2º tipo).
- [ ] Referencias a nodos: `@onready var x: Tipo = $Path` (u opcional con `get_node_or_null`). Paths cortos; `%NombreUnico` si el path se vuelve profundo.
- [ ] Si es UI: containers (`VBox`/`HBox`/`Margin`/`Grid`), no posiciones absolutas; theme como `.tres` reusable si crece; la UI no decide gameplay.

### 1c. Cerrar

1. Si toca lógica core → agregar asserts al smoke del dominio (por ejemplo,
   `world/combat_smoke_test.gd`). `world/smoke_test.gd` queda para regresiones transversales.
2. Verificación headless (obligatoria, ver CLAUDE.md): `--import` + `--quit-after 2` con stderr limpio.
3. Probar el feel en `test_scene` (Tutupa juega y tunea el `.tres`).
4. **Clasificar**: asignar estado E0–E2 en la tabla *Estado de los sistemas* (E3+ requiere aprobación jugando).
5. Commit (`feat(scope): …`) — incluye la fila nueva de la tabla. Nunca cerrar sesión con trabajo al aire.

---

## 2. MODIFICAR un sistema existente

### 2a. Mapear el impacto ANTES de tocar

Grep de consumidores del módulo:
- ¿Quién **conecta sus señales**? (`\.señal\.connect`)
- ¿Quién **llama sus métodos**? (nombre del método)
- ¿Quién lo referencia por **duck typing**? (`has_method("verbo")` — cambiar la firma de un verbo rompe a todos los que lo llaman con `call()` sin que el parser avise)
- ¿Qué **escenas `.tscn`** referencian el script? (grep del nombre de archivo en `*.tscn`)
- ¿Está en un **grupo** que otros consultan? (`"player"`, `"enemy"`, `"hurtbox"`)

### 2b. Reglas al cambiar

- **Cambiar la firma de una señal** = actualizar TODOS los `connect` y handlers en el mismo cambio.
- **Renombrar un `@export` resetea su valor en todas las escenas/`.tres`** (guardan por nombre — la lección de v1). Migración: agregar el export nuevo, copiar los valores a mano en los `.tscn`/`.tres` afectados, borrar el viejo. Nunca renombrar "al pasar".
- Un tunable nuevo nace en `.tres`, nunca como const "provisoria".
- **Regla de 2**: no extraer base class / strategy / helper hasta que exista el segundo caso real (así se hizo con `run_combo_chain`).
- Cambios de feel (tiempos, ventanas, gravedad, ángulos) se hacen en el `.tres`, no editando código — si el valor no está en tuning, primero se migra a tuning.
- Duck typing: si se agrega un verbo nuevo (estilo `launch`/`slam`), documentarlo en el docstring de `Hurtbox` (es el registro de verbos del proyecto).

### 2c. Cerrar

Igual que crear (headless + smoke + feel + commit), más:
- Revisar que los asserts del smoke test sigan describiendo el comportamiento nuevo (un smoke verde que testea lo viejo es un falso verde).
- **Aplicar la regresión de estado**: si el sistema estaba en E3/E4, baja un nivel en la tabla hasta re-probarse jugando.
- Si el cambio establece una convención nueva → agregarla al `CLAUDE.md` (una línea, no un ensayo).

---

## 3. BORRAR un sistema

Borrar es la operación con más huérfanos silenciosos en Godot. Qué implica:

### 3a. Checklist de huérfanos (buscarlos TODOS antes de borrar)

- [ ] **Consumidores**: señales conectadas, llamadas directas, `has_method("verbo")` de ese módulo.
- [ ] **Escenas**: todo `.tscn` con `ext_resource` al script o a su escena (grep del nombre de archivo). Una escena con script roto falla al cargar.
- [ ] **`project.godot`**: si era autoload → quitarlo de `[autoload]`; si usaba input actions o layer names propios → evaluarlos.
- [ ] **`data/`**: el `.gd` de tuning y el `.tres` que quedan huérfanos se borran con el sistema.
- [ ] **`.uid`**: cada `.gd` borrado se lleva su `.gd.uid` (mismo nombre).
- [ ] **Smoke test**: quitar los asserts del módulo.
- [ ] **Docs**: referencias en `CLAUDE.md` / README / este archivo.

### 3b. Orden seguro

1. Desconectar/adaptar consumidores (que el juego funcione SIN el sistema, aún presente).
2. Borrar módulo + escena + `.uid`.
3. Borrar su data (`.gd` de tuning + `.tres`).
4. Limpiar `project.godot` si aplica.
5. Verificación headless — es la red de seguridad: las referencias rotas explotan en el `--import`/arranque.
6. **Commit separado, solo del borrado** (`refactor(scope): eliminar X`) — un delete puro es trivial de revertir; mezclado con otra cosa, no.

### 3c. Cuándo NO borrar

- Stub de una línea que marca trabajo futuro planificado (`lock_on.gd`, `player_swing.gd`) → se queda: es un marcador barato.
- "Quizás lo usemos después" NO es razón para conservar código muerto real: git lo recuerda. Si no tiene consumidor ni plan, se borra.

---

## 4. Pipeline común de cierre (resumen)

Todo cambio, sin importar la operación:

```
headless --import (stderr limpio)
  → headless --quit-after 2 (stderr limpio)
  → smoke_test pasa
  → probar feel en test_scene
  → actualizar estado en la tabla (si cambió)
  → commit convencional (tipo(scope): …)
```

Si un paso falla, no se avanza al siguiente ni se declara "listo".

---

## Estado de los sistemas

Esta tabla mide la **madurez de cada sistema** (E0–E4). Las **subtareas discretas** (qué falta, en qué estado, de qué nodo) viven en el kanban de la bóveda: `obsidian/tareas.md` → `Tareas/tareaspendientes · tareasenprogreso · tareascompletadas`. Una subtarea puede tocar uno o más nodos; su estado es el archivo donde vive.

Escala E0–E4 (ver *Ciclo de vida*). Se actualiza en el mismo commit que cambia el estado. Las herramientas de test (`smoke_test`, `HitDummy`, `test_scene`) no llevan estado. Estados iniciales propuestos por Claude — **pendientes de validación jugando**.

| Sistema | Módulos | Estado | Qué falta |
|---|---|---|---|
| Mundos duales | `WorldManager` · `WorldMembership` · `WorldSwitchTrigger` | **E3** | Aprobado jugando; faltan juice y edge cases del scan/switch |
| Presencia del otro mundo | `WorldMembership` (cáscara + humo + afterimages) · `other_world_shell.gdshader` | **E2** | Verificación headless + smokes pendientes; falta iterar jugando tiempos e intensidades del contorno, el humo y la estela, y medir el costo de las afterimages con varios enemigos en pantalla |
| Player — movimiento | `Player` · `PlayerLocomotion` · `PlayerDash` · `PlayerLauncher` · `PlayerWallSlide` · `PlayerEnemyBounce` | **E1** | Validar jugando drenaje de momentum y rebote en enemigos; retunear pared/dash/gracia si hace falta |
| Player — reset aereo por kill/carga | `PlayerAirKillReset` · `PlayerCombat` · `WeaponBase` | **E1** | Correr headless/smoke; probar jugando reset de doble salto/airdash por kill aerea y reduccion de caida por cargas |
| Player — meter | `PlayerMeter` | **E2** | Iterar jugando costes y ganancias; mejoras futuras (5 barras, esquive perfecto) quedan como diseño pendiente |
| Player — vida | `Health` · `PlayerHealth` | **E2** | Definir qué pasa tras la muerte del player (hoy solo cambia un estado global) |
| Combate base | `Hitbox` · `Hurtbox` · `InputBuffer` · `StunSettings` | **E2** | Iterar jugando las ventanas de feel (`input_buffer_time` / `hold_threshold`) |
| Poise (stagger) | `Poise` · `StunSettings` · `EnemyBase` · `Player` | **E1** | Recién construido: correr headless/smoke y tunear jugando reservas, poise por arma, drenaje y escalera de degradación. Los knobs existen pero la dirección del feel es desconocida |
| Parry | `MeleeAttack` · `GroundedEnemy` · `EnemyBase` (`resolve_parry` · vulnerable cian) · `ParryTuning` · `WeaponTuning.parry_poise_*` · `PlayerCombat` (`AttackKind`) | **E1** | El parry hace daño de poise por arma/ataque; si quiebra → vulnerable cian + stun 1.5s + daño ×2. Cargado X y Y terrestre ahora parrian. Knobs existen (`parry_tuning.tres` + poise por arma) pero falta tunear jugando montos, multiplicador y duración |
| Parry de proyectil (deflect) | `Projectile` (`try_parry` · `_deflect` · hurtbox por código) · `DeflectTuning` | **E1** | Deflect puro y separado del cian: el arma da vuelta el proyectil y lo manda homing contra el tirador, que come el daño y el stun de su propio tiro. Recién construido: correr headless/smoke y tunear jugando. **Riesgo abierto**: a `projectile_speed = 100` (RangedDead) el proyectil avanza ~1.67 m/frame y puede atravesar la hoja sin registrar overlap — si el parry "no responde" es eso, no el timing (bajar la velocidad o subir `hurtbox_radius`). Falta también decidir si el rebote debe pegar más que el tiro (`damage_multiplier`, hoy 1.0). Los knobs existen en `deflect_tuning.tres` pero la dirección del feel es desconocida |
| Espada | `WeaponBase` · `Sword` · `SwordTuning` | **E3** | Aprobado jugando; clash mid-swing pendiente (ponytail) y ultimos detalles de mano orbital |
| Mazo | `WeaponBase` · `Mace` · `MaceTuning` | **E2** | Combos completos y knobs en `mace_tuning.tres`, sobre el mismo motor que la Espada; falta probarse jugando (E2→E3 lo decide Tutupa) |
| Enemigo de suelo | `EnemyBase` · `GroundedEnemy` · `Perception` · `GroundLocomotion` · ataques | **E2** | Iterar jugando rangos y cooldowns por escena (excepción tuning) y la reacción de stun (retroceso, inclinación, luz) |
| IA de combate en rango (engage + EVADE) | `GroundedEnemy` (espaciado/cadencia/giro comprometido/receptor telegraph) · `GroundLocomotion` (`backpedal` · `strafe` · `evade`) · `EnemyAIBlackboard` (intents `BACKPEDAL`/`STRAFE`/`EVADE`) | **E3** | Aprobado jugando sobre LimboAI: el melee se espacia (entra, pega, retrocede de cara, orbita), el combo compromete la dirección y el esquive salta hacia atrás con `evade_distance` tuneable. Faltan juice y edge cases |
| Ragdoll de aterrizaje | `GroundedEnemy` (pose acostada, radio `GroundSense`, `ragdoll_getup_delay`/`spin`/`gravity_scale`) | **E3** | Aprobado jugando; faltan últimos detalles de pulido |
| Enemigo ultra agresivo | `UltraAggressiveEnemy` (prefab) · target scoring por utility en `GroundedEnemy` · stuck-check en `GroundLocomotion` | **E2** | Prefab berserker con histéresis de target (proximidad + compromiso) y rodeo al trabarse; los knobs ya existen como exports. Verificación headless + smokes pendientes; falta iterar jugando el infighting (`UltraPreyA`/`B` en `test_scene`), los pesos de scoring y los stats de primer pase |
| Loadout de ataques (melee/ranged/híbrido) | `AttackLoadout` · `GroundedEnemy._collect_attacks` · `HybridEnemy` (prefab) | **E2** | Módulo inyectable que elige qué familias equipa un enemigo; reemplaza la subclase-por-enemigo (se borró `RangedDead`). Verificación headless + smokes pendientes; falta iterar jugando rangos/cadencia del híbrido y ver si la transición melee↔ranged pide histéresis |
| Bloques traversal | `TraversalBlock` · `BreakOnDeath` · `SpikeWall` | **E2** | Regresion por cambio de rumbo del dash verde (ahora fijo a -Z local del bloque + flecha, ya no depende de por donde llega el jugador); falta re-probar jugando junto con glow e impulsos |
| Pickups de mundo | `TraversalBlock` · `ActionWorldSwitchModifier` | **E2** | Validar maldicion de accion y pickups combinados jugando |
| Grieta | `WorldRift` · `WorldRiftTuning` · `RiftSpawner` · `rift_enemy.tscn` | **E0** | Recién construida: puerta temporal de un solo uso que voltea el mundo al cruzarla; la abre `WorldRift.spawn()` (hoy la deja el enemigo al huir tras el primer golpe). Falta verificación headless + smoke y tunear jugando el `delay` del enemigo contra el `lifetime` de la grieta |
| HUD | `HUD` | **E1** | Es placeholder funcional (labels/barras); rediseño visual pendiente |
| Cámara | `CameraRig` · `CameraTuning` | **E1** | Rotacion horizontal por stick recien agregada (offset clamped ±30°, recentrado tras 1-2s idle); falta headless + tunear jugando follow y rotacion; falta definir centro por area |
| Lock-on | `LockOn` | **E3** | Ultimos detalles de rango/angulo/reticle jugando |
| Columpio de cadenas | `PlayerSwing` | **E0** | Stub — batch 6 |
| Visual de mundos | `WorldVisual` | **E0** | Stub — 2 Environments + lerp |
| Indicador de aterrizaje | `LandingIndicator` | **E3** | Ultimos detalles visuales si aparecen jugando |
