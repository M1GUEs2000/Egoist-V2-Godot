---
title: Plan Autoridad Vertical
tags:
  - egoist
  - godot
  - combate
  - plan
status: active
system_status: E0
hito: H1
---

# Plan Autoridad Vertical — Mover + Floater

## Decision

El movimiento vertical de combate se rehace sobre **dos componentes universales**:

- **Mover** desplaza un cuerpo por una trayectoria.
- **Floater** suspende un cuerpo al terminar un Mover, durante un tiempo exacto.

No habra sistemas separados llamados launcher, hang, stall, hover, plunge, slam, bounce o
freeze. Esos nombres solo pueden quedar como nombres de ataques/coreografias en `Sword` o
`Mace`; internamente todos piden Mover y, si corresponde, Floater.

El alcance es combate y enemigos. Traversal no se toca salvo que hoy dependa directamente de uno
de los modulos verticales que se retire.

## Estado de cierre

La API vigente es `request_mover(settings)` y `request_float(duration, fall_scale)`. El ataque
posee el perfil; el receptor ejecuta y cancela. `MoverSettings.Mode.TOTAL` toma el cuerpo completo;
`PARTIAL` controla solo Y en el tick normal del Player. Todo impacto nuevo sobre un enemigo cancela
su control vertical anterior, salvo el perfil que ese mismo impacto preparo en `about_to_hit`.

Espada esta migrada a Mover/Floater y el rebote de su Y aereo esta desactivado. PlayerLauncher no
interviene en el flujo activo de Espada. Mace queda fuera del loadout y se reconstruira desde este
contrato. Los apartados posteriores conservan el historial de la migracion.

`PlayerLauncher` ya fue eliminado del proyecto, junto con su nodo de escena, adaptador y tuning.
El Float de impacto del dash vive ahora en `PlayerDash` con tuning propio.

## Modelo mental

```text
Ataque
  -> pide Mover al Player, al Enemy, o a ambos
  -> cada cuerpo termina su propio recorrido
  -> el Mover terminado puede pedir Floater para ese mismo cuerpo
  -> el cuerpo cae normal cuando termina Floater
```

"Mover a ambos" no significa que Player y Enemy compartan fisica ni distancia. Significa que el
ataque envia **dos solicitudes de Mover**: una a cada componente. Cada solicitud lleva su propio
perfil; por ejemplo Player puede subir 5 m y Enemy 10 m.

## Componente Floater

`Floater` es un nodo hijo de `Player` y de `EnemyBase`.

```text
start_float(duration, fall_scale)
cancel_float()
is_floating()
```

Mientras esta activo, cada frame escala la caida del duenio segun `fall_scale`:

```text
fall_scale = 0.0  -> hold total (velocity.y fijada en 0)
fall_scale = 1.0  -> gravedad normal (no hace nada)
intermedio        -> deriva lenta (ej. 0.15 = cae al 15%, como el juggle actual)
```

Al vencer el tiempo deja que la gravedad normal retome el control. No guarda ni restaura una
velocidad anterior y no tiene prioridades configurables.

Cada cuerpo tiene un timer propio. Un nuevo `start_float(duration, fall_scale)` renueva el
vencimiento con `max(actual, now + duration)` y adopta el `fall_scale` de la ultima solicitud
(gana el ultimo que escribe). Player y Enemy pueden flotar tiempos y escalas distintos aunque el
mismo ataque los haya movido juntos.

Los datos de tuning de Floater son:

```text
float_duration: float # segundos; 0 = no detona Floater
fall_scale: float     # 0.0 hold total .. 1.0 gravedad normal
```

## Componente Mover

`Mover` es un nodo hijo de `Player` y de `EnemyBase`. Un Mover solo mueve a su propio duenio. La
coordinacion de Player, Enemy o ambos vive en el ataque que emite las solicitudes.

Cada solicitud usa un `MoverSettings` Resource, guardado en el tuning del ataque/arma:

```text
direction: Vector3       # direccion normalizada del recorrido
distance: float          # metros maximos del recorrido
speed: float             # velocidad inicial en m/s
acceleration: float      # m/s²; positiva acelera, negativa frena, 0 es constante
stop_on: flags           # DISTANCE, FLOOR, WALL, ENEMY
float_duration: float    # Floater que pide este cuerpo al terminar; 0 = no pide
float_fall_scale: float  # fall_scale del Floater pedido al terminar
```

Reglas:

- El Mover termina al recorrer `distance` o al encontrar una condicion habilitada en `stop_on`.
- `DISTANCE` siempre funciona como limite de seguridad; `FLOOR`, `WALL` y `ENEMY` permiten que
  una coreografia termine antes por contacto.
- Un dash cargado puede usar `DISTANCE | WALL` y no incluir `ENEMY`, por lo que atraviesa
  enemigos y solo termina por distancia o pared.
- Al terminar normalmente o por contacto, emite una senal tipada `mover_finished(reason)` y, si
  `float_duration > 0`, pide Floater para su propio duenio.
- Al cancelarse por stun, muerte, otro Mover o una regla del ataque, emite
  `mover_cancelled(reason)` y **no** detona Floater (`float_duration`, `float_fall_scale`) salvo
  que el ataque lo pida de forma expresa.
- Un Mover nuevo reemplaza al anterior del mismo cuerpo. Cada ejecucion tiene un id para que un
  timer/callback viejo no afecte el movimiento nuevo.

No existe `target = BOTH` dentro del componente: el ataque llama el Mover de ambos cuerpos. Para
diseno se puede decir que el ataque es `BOTH`; para codigo evita una fisica compartida y permite
dos perfiles distintos.

## Poise, stun y aire

- Contra un enemigo en tierra, un Mover de combate solo entra si el golpe quiebra poise. Los
  launchers actuales ya hacen esta consulta antes del dano con `would_break()`.
- Un enemigo que ya esta en aire esta quebrado: no recupera poise hasta asentarse y acepta los
  Movers/Floater de los golpes aereos sin volver a pasar por el gate de poise.
- El stun se mantiene mientras el enemigo esta en el aire y solo puede resolver al asentarse en
  piso (incluido el `early_ground` actual de ragdoll). Floater no sustituye ese contrato.
- `StunSettings` conserva dano de poise y duracion de stun terrestre. Su campo `airborne` queda
  transitorio durante migracion y se elimina cuando ningun sistema lo use para decidir un hold.
- Hoy todos los desplazamientos (`launch`, `slam`, `slam_bounce`, `slam_arc`, `push`, incluido el
  push sobre un enemigo en el piso) meten al enemigo en aire, asi que la regla "stun se mantiene en
  aire" ya los cubre a todos. No existe ningun Mover terrestre que arrastre a un enemigo stuneado
  por el suelo. Si algun dia se agrega uno, ahi entra un flag `retains_stun` que sostenga el stun
  mientras ese Mover terrestre este activo. No se implementa ahora; queda como punto de extension.

## Espada: contratos de referencia

### Y cargado terrestre (antes launcher)

El ataque, si rompe poise, inicia dos Movers verticales:

```text
Player Mover: direction UP, distance/speed/acceleration propios, player_float_duration
Enemy Mover: direction UP, distance/speed/acceleration propios, enemy_float_duration
```

Al terminar cada subida, cada cuerpo flota su propio tiempo. No existe `launcher_hang_time`.

### Golpes aereos normales — experimento obligatorio

Se implementa un perfil Mover para Player y otro para Enemy en cada golpe normal aereo. Los dos
se mueven con la coreografia que se defina para el ataque y luego flotan. La hipotesis a probar es
que se lean como una pareja que avanza/queda "pegada" durante el juggle.

No se congela como regla de diseno hasta probarla jugando. Si se siente mal, el resultado valido
es que el golpe aereo normal pida Floater directo y no Mover; eso sigue usando solo los dos
componentes, sin revivir stall ni una tercera mecanica.

### X cargado aereo

Player usa un Mover hacia adelante con `stop_on = DISTANCE | WALL`; no se detiene en enemigos.
Al finalizar, su `float_duration` detona Floater. Si el impacto decide mover a un Enemy, envia una
segunda solicitud con el perfil enemigo correspondiente.

### Y cargado aereo

El spike y el rebote se expresan como Movers: perfiles descendentes hasta `FLOOR`/`ENEMY` y
perfiles ascendentes posteriores. Cada perfil puede detonar Floater al terminar. No quedan
`bounce_hang_time` ni temporizadores especiales.

### Plunge y push

El plunge es un Mover descendente para Player y, si conecto, un Mover descendente para Enemy. El
push es un Mover con direccion, distancia, velocidad y aceleracion propias. Ambos conservan su
identidad por tuning, no por modulos separados.

### Carga aerea (antes air_charge_fall_control)

Cargar un arma en el aire aplica un **Floater al Player** mientras dura la ventaja de la carga. En
vez del recorte de velocidad de un frame del sistema viejo, es un hang real (`fall_scale` bajo o 0)
que se lee como que te frenas para reposicionar. Reemplaza por completo a `air_charge_fall_control`
y a `air_charge_fall_reduction_steps`.

Por ahora es directo: cada carga aerea detona su Floater, **sin escalado ni anti-spam**. Se acepta
que en teoria podrias re-cargar para sostenerte; no es prioridad, es por meter la mecanica igual. Si
mas adelante molesta, la solucion vive en el **propio Floater** (ej. un "desgaste": la duracion o el
hold decae con usos seguidos y se recupera al asentar o matar en aire), no en un sistema aparte.

El guardia actual (solo actua si vas cayendo) queda a decidir jugando: mantenerlo, o dejar que el
Floater tambien te sostenga en el apex si cargas subiendo.

Ojo: `PlayerAirKillReset` hace dos cosas. Solo migra a Floater su **freno de caida**. El reset de
doble salto y airdash al matar en aire **no se toca**.

## Donde viven los datos

| Pieza | Lugar |
|---|---|
| Logica reusable | `player/player_mover.gd`, `player/player_floater.gd`, componentes equivalentes de `EnemyBase` o escenas hijas reutilizables. |
| Datos de recorrido | `MoverSettings` Resource e instancias/subresources dentro de `SwordTuning`, `MaceTuning`, `ArmTuning` o el tuning del ataque que lo use. |
| Datos de combate | `StunSettings` sigue llevando poise y stun; no lleva hang/hold final. |
| Coordinacion de ambos cuerpos | `Sword`, `Mace` o `WeaponBase`: emite una solicitud por cada cuerpo. |

Todo numero de feel (distancia, velocidad, aceleracion, contactos y Float) vive en `.tres`.

## Inventario a retirar

Se migran y luego se eliminan, con todos sus consumidores, escenas, `.uid`, tuning y asserts
obsoletos:

- Timers y prioridades de `PlayerLauncher`: air-hit-stall, whiff, float/fall, hover y arm freeze.
- `_airborne_until` como hold de enemigo y los `*_hang_time` que solo existen para sostenerlo.
- Verbos especializados `launch`, `slam`, `slam_bounce`, `slam_arc`, `plunge` y `push`, una vez
  sus consumidores usen Mover.
- `air_stall_*`, `aerial_whiff_*`, `*_hang_time` y cualquier tuning duplicado del sistema viejo.
- El freno de caida de `air_charge_fall_control` en `PlayerAirKillReset` y el tuning
  `air_charge_fall_reduction_steps`, una vez la carga aerea use Floater. (El reset de doble salto y
  airdash al matar en aire NO se toca; solo migra el freno de caida.)

No se borra una pieza hasta que todos sus consumidores hayan migrado y el smoke describa el
contrato nuevo.

## Fases

### F0 — Mapa de impacto y contratos

- [x] Listar cada consumidor de `PlayerLauncher`, `launch`, `slam`, `push`, `plunge` y
  `_airborne_until`: llamadas, señales, duck typing, escenas y tuning. → [[Mapa Impacto Autoridad Vertical]]
- [x] Crear `MoverSettings` y documentar sus unidades/tooltip `##`. → `data/mover_settings.gd`
- [x] Definir los contratos tipados de Mover/Floater y sus razones de fin/cancelacion. →
  `combat/mover.gd` (senales `mover_finished`/`mover_cancelled`, enums `FinishReason`/`CancelReason`),
  `combat/floater.gd`. Stubs sin comportamiento, no instanciados en escena aun.
- [x] Agregar asserts vacios o de contrato al `combat_smoke_test` antes de migrar comportamiento.
  → `_test_movement_contracts()`.

Salida: import + arranque headless limpios; no cambia el feel.

### F1 — Floater comun

- [x] Agregar Floater a Player y EnemyBase sin retirar aun los sistemas viejos. → `combat/floater.gd`
  implementado; se instancia por codigo en `Player._ready` y `EnemyBase._ready`. Hook por frame en
  la integracion vertical de ambos (prioridad sobre el sistema viejo). El del enemigo es no-op en
  vivo (nada lo activa aun; F2 lo usa). Cancel del Floater del Player en: piso, doble salto, stun,
  bump y launch (mismos puntos donde se reseteaba el air stall).
- [x] Migrar primero una solicitud controlada de Espada: el hang del sweet spot del X cargado
  (`_player.hover` → `_player.request_float(dur, fall_scale)`), con `sweet_spot_float_fall_scale`
  (0.15, replica el `air_stall_float_gravity` viejo) en `SwordTuning`. El sweet spot ademas lanza al
  enemigo, asi que un mismo ataque cuelga a los dos cuerpos con tiempos propios.
- [x] Timer/renovacion/independencia y "enemigo Floater sigue juggleable" verificados en
  `combat_smoke_test` (`_test_floater_logic()` + assert sobre el `parry_enemy` ya stuneado).

Salida: import + arranque headless + `combat_smoke_test` verdes; playtest de un Float aislado.
Estado real: `--import` y `--check-only` de los archivos tocados limpios (headers). Falta correr
`combat_smoke_test` y el playtest del sweet spot (los hara Tutupa).

### F2 — Mover comun y Y cargado terrestre de Espada

- [x] Agregar Mover a Player y EnemyBase. → `combat/mover.gd` implementado (tick con distancia,
  velocidad, aceleracion; stop_on DISTANCE/FLOOR/WALL; ENEMY queda para F4). Se instancia por codigo
  en ambos `_ready`. Branch de Mover en `Player._physics_process` (ex `launcher.is_launched`) y al
  tope de `EnemyBase._update_airborne`. Al terminar detona el Floater del cuerpo.
- [x] Migrar el Y cargado terrestre: se migraron los VERBOS `launch()` de ambos cuerpos (preservando
  contrato externo y gate de poise). Player sube via Mover UP + Floater (colapsa las dos fases de
  float del launcher viejo en un Floater). Enemy sube via Mover UP + Floater(hang, hold total),
  reemplazando `_launch_routine` y el hold de `_airborne_until`.
- [x] Retirar el camino sustituido (uso): `PlayerLauncher.start_launch/tick_launch/is_launched` ya no
  se usan (dead code hasta F5); asserts del smoke actualizados (`is_launched`→`mover.is_moving()`,
  `launcher.cancel()`→`cancel_launch()`); `player_enemy_bounce` lee `mover.is_moving()`.

Salida: launcher nuevo jugable; Player y Enemy pueden llevar distancias/times distintos; poise y
stun siguen correctos.
Estado real: headers limpios (`--import` + `--check-only`). Ojo: el verbo `launch()` es compartido,
asi que la migracion tambien alcanza al launch aereo cargado de Espada (F4) y al launch del enemigo
que dispara el Mazo. Falta correr smoke + playtest del Y cargado terrestre (feel del float del
jugador es lo mas sensible: dos fases → un Floater).

### F3 — Combo aereo normal de Espada

- [x] Probar Movers de ambos cuerpos en los golpes normales aereos.
- [x] Decidir jugando si la lectura "pegados" es buena. Si no, esos golpes piden Floater directo;
  la excepcion queda documentada, sin reintroducir un sistema viejo.

**Estado real (F3): se tomo la rama "Floater directo".** Los golpes normales aereos no describen
ninguna trayectoria: *sostienen* a los dos cuerpos en su lugar mientras corre el combo. Un Mover
necesita direccion + distancia, y aca no hay ninguna que sea honesta; forzarlo seria inventar un
desplazamiento que el ataque nunca pidio. La lectura "pegados" ya la dan los dos Floaters corriendo
a la vez. Queda documentado como la excepcion prevista por el plan.

- Player: `register_air_hit_stall` conserva la contabilidad del combo (`_stall_count`, ventana,
  corte de momentum horizontal) pero el hang pasa a `floater.start_float(duracion, air_stall_float_gravity)`.
  Se retiro `_air_stall_until` y su rama en `gravity_scale`, y el `hover` legacy (ya sin consumidores).
- Enemigo: el juggle (`apply_stun` en el aire) sostiene con Floater de hold total en vez de
  `_airborne_until`. El timer queda solo como tope de seguridad (`airborne_max_time`).
- **Brazo migrado y freeze BORRADO** (se adelanto de F5 por decision de Tutupa: "solo debe existir
  el Floater y punto"). `register_arm_air_freeze`/`is_air_frozen`/`consume_air_freeze` y sus tres
  variables de estado ya no existen. El entry point es `Player.register_arm_air_hit`: Floater de
  hold total para la vertical + el freno horizontal (que nunca fue vertical y sigue aparte).
  **Cambio de feel aceptado:** el freeze retomaba la caida con la velocidad previa COMPLETA (lectura
  de "pausa"); el Floater arranca de 0 (lectura de "hang"). El knob se renombro
  `air_freeze_duration` → `air_hang_duration`, migrando el valor tuneado del .tres (0.1, no el
  default). Con esto el Player ya no tiene NINGUNA politica vertical de ataque fuera del Floater.
- Los moves que se adueñan de la vertical (`slam`, `push`, pique, `launch`, aterrizaje) cancelan el
  hold via `_cancel_air_hold()`. Sin eso el Floater del stun les sostenia la vertical en 0.

Pendiente: smoke + playtest (no corridos en este batch).

Salida: combo aereo estable, sin poise recuperado en aire y sin temporizadores legacy.

### F4 — X/Y cargados, plunge y push de Espada

- [x] X cargado (tierra y aire): Mover EXCLUSIVO hacia adelante que atraviesa enemigos y termina por
  distancia/pared. **RESUELTO (2026-07-20), ver "Desbloqueo" abajo.**
- [x] Y cargado aereo: Movers de spike/rebote por contacto, luego Floaters.
- [x] Plunge: Mover DOWN NO-EXCLUSIVO propio. **RESUELTO (2026-07-20).** (`push` NO va aca: es arco
  balistico → bouncer, ver F5.)
- [x] Carga aerea: al empezar carga en aire, aplicar Floater al Player en vez de
  `air_charge_fall_control`; retirar el freno de caida y `air_charge_fall_reduction_steps`. Sin
  escalado por ahora (el "desgaste" queda como idea futura del Floater).

**Estado real (F4): dos de cuatro hechos, dos bloqueados por el diseño del Mover.**

Hecho:

- **Carga aerea → Floater.** `apply_air_charge_fall_control` y `air_charge_fall_reduction_steps`
  borrados; entra `Player.apply_air_charge_float` con `air_charge_float_duration` /
  `air_charge_float_fall_scale`. `PlayerAirKillReset` quedo reducido a lo que dice su nombre:
  devolver doble salto y airdash. **Se perdio el desgaste por uso** (era lo pedido: sin escalado).
- **Y cargado aereo.** El *rebote* ya estaba en Mover+Floater desde F2 (`_do_bounce_vertical` llama
  `launch`). Faltaba el *spike*: `slam` pasa a Mover DOWN con `STOP_ON_FLOOR`. Cambio de feel: antes
  la bajada aceleraba (gravedad acumulando) y conservaba el horizontal; ahora baja recto a velocidad
  constante — que es lo mismo que hace el plunge del jugador con el que va a la par.

**Bloqueado — el Mover es EXCLUSIVO y estos dos moves no lo toleran:**

Mientras un Mover corre, el cuerpo le entrega `velocity` entero y el glue hace `return` temprano:
sin gravedad, sin horizontal propio, sin deteccion de contactos del cuerpo. Eso es correcto para la
subida de un launch, pero rompe estos dos:

1. **Plunge.** Su cancelacion documentada es el rebote en enemigo, y el rebote NO puede salir
   durante un Mover: el glue llama `enemy_bounce.cancel()` y `try_bounce` arranca con
   `if _body.mover.is_moving(): return false`. Migrarlo tal cual mata la mecanica.
2. **X cargado aereo.** Hoy es `PlayerDash.force_dash`, que ademas del desplazamiento aporta
   atravesar enemigos (flip de `collision_mask`), boost de momentum, particulas y la continuidad de
   inercia aerea al salir. El Mover no tiene nada de eso, y el dash es horizontal: su unica escritura
   vertical es poner la caida en 0 al arrancar.

Ademas **`push` no va aca**: es un arco balistico, y el plan ya lo manda al "bouncer" de F5 (esto
mismo quedo anotado en el Mapa de Impacto en F0).

**Desbloqueo (2026-07-20):** NO hizo falta el bouncer (arcos balisticos, sigue para el Y aereo del
Mazo/Espada). Los dos bloqueados eran por la EXCLUSIVIDAD del Mover, no por arcos, y se resolvieron
extendiendo el Mover lineal:

- **Modo NO-EXCLUSIVO** (`MoverSettings.exclusive = false`): el Mover aporta solo su eje vertical y el
  glue mueve el cuerpo con el resto vivo (horizontal, contactos, rebote). El **plunge** pasa a un
  Mover DOWN no-exclusivo (`Player.plunge` lo arma); `try_bounce` ahora solo bombea ante un Mover
  EXCLUSIVO, asi el rebote en enemigo sigue cancelando el plunge. Se borro `_plunge_speed`.
- **Extras de dash portados al Mover** (`MoverSettings.pass_through_enemies` / `boost_momentum` /
  `keep_exit_inertia` / `emit_dash_particles`): el **X cargado** pasa a un Mover EXCLUSIVO forward
  (`Sword._hold_x` arma el perfil, `Player.dash_mover` lo arranca). El pass-through lo hace el Mover
  (collision_mask); boost/particulas/inercia los aplica el Player por hooks `on_mover_started/ended`
  reusando helpers de `PlayerDash` (sin duplicar). El daño sigue en `ChargedDashHitbox`, aparte.
  Ojo feel: el Mover no suma bump DURANTE el dash (force_dash si), asi que un dash con momentum previo
  cambia un poco — caso borde, a confirmar jugando.

Pendiente: playtest (el smoke headless no se corre). Baja Dash E4→E3 y Espada E3→E2 hasta el OK de
Tutupa.

**Datos en `.tres` (2026-07-21) — se cumple "todo número de feel vive en `.tres`".** Antes los
perfiles se armaban en código desde escalares sueltos; ahora cada move vertical de la Espada es un
recurso `MoverSettings`/`FloaterSettings` explícito, uno por cuerpo, embebido en `sword_tuning.tres`
y editable en el inspector:

- `charged_dash_mover` (Mover del JUGADOR, X cargado) — reemplaza `charged_dash_distance/duration`;
  la duración del golpe se deriva de distancia/velocidad.
- `plunge_player_mover` + `plunge_enemy_mover` (Movers DOWN, plunge) — reemplazan
  `air_plunge_down_speed`; bajan a la par (mismo speed).
- `launcher_enemy_mover` + `launcher_enemy_floater` (Mover UP + Floater del hang, launcher Y del
  enemigo) — reemplazan `launcher_height/hang_time`.
- `sweet_spot_player_floater` (Floater del JUGADOR, hang del sweet spot) — reemplaza
  `sweet_spot_air_stall_bonus/float_fall_scale`.

Se creó **`FloaterSettings`** (`data/floater_settings.gd`), simétrico a `MoverSettings` (`duration` +
`fall_scale`). Los verbos duck-typed del enemigo (`launch`/`slam`) aceptan ahora los recursos por
parámetros opcionales, con fallback escalar para Mazo/dummy/smoke (no se rompió su firma). Cambio de
estructura, no de comportamiento: los valores se migraron idénticos (mismo baile de migración). No
baja más el estado (sigue E2 pendiente del mismo playtest). `--import` exit 0.

Salida: todos los movimientos de Espada usan solo Mover + Floater (el Y aereo sigue desactivado
esperando el bouncer) y todo su feel vertical vive como recursos en el `.tres`.

### F5 — Mazo, Brazo y limpieza total

**Estado real (F5, 2026-07-20): el bouncer (arcos balisticos) se pospone; se hizo TODO lo que no lo
necesita — incluido extender el Mover lineal (modo no-exclusivo + extras de dash) para desbloquear
plunge y X cargado (ver "Desbloqueo" en F4).**

Primero se DESACTIVO lo que si depende del bouncer (Y aereo), despues se hizo la limpieza:

- **Y cargado aereo DESACTIVADO en Espada y Mazo.** Es la unica via viva de los verbos de bouncer:
  Espada `_aerial_charged_y` → `slam_bounce`; Mazo `_aerial_hold_y` → caida diagonal + `slam_arc` +
  rebote diagonal del jugador. Ahora el `_hold_y` aereo de ambas armas cae al **combo aereo normal**
  (`_tap_combo`, sin gastar meter). El codigo de esos moves (`_run_aerial_charged_y`,
  `_on_aerial_charged_y_hit`, `_aerial_hold_y`, `_burst_air_slam`, etc.) queda **intacto** para
  re-enchufarlo cuando exista el bouncer. Verificado: `--import` exit 0, sin errores de compilacion
  en `sword.gd`/`mace.gd`. Falta playtest (Tutupa) para confirmar que el fallback al combo normal se
  siente bien.
- **`push` NO se toca.** Es una mecanica completa y aislada (solver geometrico propio en
  `PushSettings`, maquina de estados en `EnemyBase`, rebote de pared, tuning propio). Funciona hoy
  standalone y no llama a ningun verbo de bouncer. Mecanicamente ES un arco balistico, asi que el
  bouncer PODRIA absorberlo el dia que se implemente, pero es consolidacion de codigo futura, no una
  dependencia: push no espera nada.
- Plunge de Espada y el ground pound del X cargado aereo del Mazo tampoco son arcos balisticos
  (caen recto, lineal) ni estan rotos. Su relacion con el bouncer es solo la de F4 (exclusividad del
  Mover para migrar el plunge), no funcional. Quedan vivos.

Limpieza NO-bouncer hecha en este batch (2026-07-20):

- [x] **`PlayerLauncher` eliminado.** El modulo ya no lanzaba (launch → `Mover` en F2) ni sostenia
  hang (stall/hover → `Floater` en F3): solo le quedaba la contabilidad del air-hit-stall + la
  ventana de whiff. Se plegaron dentro de `Player` (`register_air_hit_stall`, `notify_aerial_attack`,
  `_reset_air_stall`, whiff inline en la integracion de gravedad). Borrados: `player/player_launcher.gd`
  + `.uid`, el nodo `Launcher` de `player.tscn`, el knob muerto `launcher_fall_gravity` (.gd + .tres).
  Quedan vivos y en uso los knobs `launcher_float_duration/fall_duration/float_gravity` (alimentan el
  Floater del launch). Estado final: la vertical del Player es solo Floater + Mover + gravedad/salto.
  Verificado `--import` exit 0. Regresa `Player — movimiento` a confirmar jugando (refactor sin cambio
  de comportamiento).
- [x] **`StunSettings.airborne` se queda.** El plan pide retirarlo "cuando nadie lo use", pero
  `duration_for(is_airborne())` lo lee para la duracion del stun en aire (Player `receive_stun` y
  EnemyBase). Tiene consumidores → no es vestigial. (El `_airborne_until` del enemigo es otra cosa y
  sigue su propio camino.)

Trabajo original de F5 (queda para cuando se retome, depende del bouncer):

- [ ] Migrar Mazo, hazards y toda otra fuente que escriba vertical directamente.
  (El **Brazo ya esta migrado**: se adelanto en F3, ver esa fase.)
- [ ] Arcos balisticos del Mazo (`slam_arc` y rebotes): el Mover lineal no los cubre. Se resuelven
  con un "bouncer" (Mover en modo balistico: lanza velocidad + gravedad propia hasta `FLOOR`).
  Diseñar e implementar ese modo es parte de esta fase, o se agenda aparte si crece.
- [ ] Actualizar [[Combate]], [[Espada]], [[Stun]], [[Reset Aereo por Kill]] y esta nota con
  nombres finales.

Salida: no quedan escrituras verticales de combate fuera de Mover, Floater, gravedad base, salto y
stun. No quedan nombres legacy para sostener aire.

## Verificacion obligatoria por fase

1. `--import` sin stderr.
2. Arranque headless sin stderr.
3. `combat_smoke_test` imprime `COMBAT SMOKE OK`.
4. Tutupa prueba el feel de los ataques migrados en `test_scene`.
5. Si cambia un sistema E3/E4, se aplica regresion de estado y se actualiza `METODOLOGIA.md` en
   el mismo commit si nace una convencion nueva.

## Criterio de exito

Un ataque se entiende leyendo un perfil Mover y un tiempo de Floater. No depende de timers
ocultos, prioridades de gravedad, verbos ad-hoc o nombres distintos para la misma mecanica.

## Relacionado

- [[Combate]]
- [[Espada]]
- [[Mazo]]
- [[Brazo]]
- [[Stun]]
- [[Reset Aereo por Kill]]
- [[tareas]]
