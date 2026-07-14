---
title: Stun
tags:
  - egoist
  - enemigo
  - combate
status: active
system_status: E2
hito: H1
---

# Stun

Sistema de stun y armadura de `EnemyBase`. Vive separado de [[Estados de Combate Enemigo]] porque tiene su propio criterio de entrada, independiente del resto de `combat_state`. *(2026-07-08)*

## Poise: el gate del stun

> [!important] El stun NO se decide golpe a golpe
> El criterio es universal (igual que el player, ver [[Combate]]): cada ataque trae un `poise_damage` en su `StunSettings`, ese poise **se acumula** en el receptor y el stun entra recien cuando el acumulado **alcanza la reserva** (`poise_max`). El acumulado **decae solo**: presion sostenida quiebra, golpes espaciados no. *(2026-07-13, reemplaza el umbral instantaneo `power >= threshold`)*

El medidor vive en `combat/poise.gd` (`Poise`), compartido por `EnemyBase` y `Player`. No es un `Node`: el decaimiento y la recuperacion se calculan al vuelo contra `World.now()`, asi que no hay trabajo por frame ni nodo que agregar a las escenas.

Ciclo completo:

1. Un golpe suma su `poise_damage` al acumulado (antes drena lo que corresponda al tiempo transcurrido).
2. Si el acumulado **no** llega a la reserva → **no hay stun**, solo daño a vida. El enemigo tira un **fogonazo blanco** (ver *Lenguaje de color*).
3. Si **llega** → entra el stun con la duracion que define la fuente (`grounded`/`airborne`), el acumulado vuelve a 0 y la reserva **baja un escalon**.
4. Ya `STUNNED` **no hay poise que romper** (esta quebrado): los golpes entran directo y extienden el stun. Eso es lo que sostiene el juggle y los combos.
5. Sin recibir golpes por `poise_recovery_time` (20 s), la reserva vuelve al **100%**. Es silencioso: el jugador no lo ve.

### Degradacion: cada quiebre lo deja mas fragil

`poise_break_levels` es la escalera de multiplicadores de la reserva tras cada quiebre. Default: `[1.0, 0.8, 0.6, 0.4, 0.2, 0.0]` — editable **por enemigo**. En el ultimo escalon (`0.0`) la reserva es nula: **cualquier golpe lo stunea**. Castigar sin pausa es progresivamente mas facil; soltarlo 20 s lo devuelve a cero.

El **player NO degrada**: su escalera es `[1.0]` (un solo escalon), asi que su reserva siempre vuelve al 100%. Mismo componente, sin ninguna rama especial en el codigo.

Un golpe con `poise_damage = 0` **nunca** staggerea, ni con la reserva en cero: hace daño y nada mas.

## Entradas

| Metodo | Que hace |
|---|---|
| `receive_stun(stun: StunSettings)` | Entrada normal: llama `try_apply_stun` con `duration_for(is_airborne())` y el `poise_damage` del `StunSettings`. |
| `try_apply_stun(duration, poise_damage)` | **El gate**: come poise y stunea solo si quiebra la reserva. Si ya esta stuneado, entra directo. |
| `apply_stun(duration, color)` | Aplicacion directa que **ignora el poise** — para casos que ya decidieron que el stun aplica. Lo usa el estado vulnerable del parry (`_enter_parry_vulnerable`), una vez que su poise ya quebro la reserva, para pintar el stun cian. |
| `resolve_parry(player, dir)` | Outcome de un parry en ventana (ver seccion Parry): mete el poise del arma/ataque del player (**solo poise, sin HP**) y, si quiebra, entra al estado vulnerable cian. |

`MeleeAttack` llama `receive_stun` en su target cuando el `StunSettings` del ataque no es null (`_deal_damage`); si el target no tiene `receive_stun` pero es otro `EnemyBase`, usa `take_hit_from_enemy` que aplica stun via `_apply_stun_from_settings`.

## Armadura

La armadura **SUMA reserva de poise**, no es un umbral aparte:

- `armored` (export) define si el enemigo inicia armado (`combat_state = ARMORED` en `_ready` si `armored` esta activo).
- Mientras esta `ARMORED`, su reserva es `poise_max + armor_poise_bonus` (6 + 6 = 12 por default). Es **resistencia, nunca inmunidad**: un golpe con suficiente poise (el sweet spot del [[Mazo]], 12) lo quiebra igual de un solo impacto.
- `armor_hits_to_break` define cuantos **golpes** aguanta la armadura antes de romperse (`_damage_armor` cuenta hits, no daño bruto ni poise). Corre **en paralelo** al poise: son dos medidores independientes sobre el mismo golpe.
- Al romperse: `combat_state` vuelve a `NORMAL`, se resetea `_armor_hits_taken` y **pierde el `armor_poise_bonus`** — la reserva cae al base sola, sin avisarle nada al `Poise`.
- `apply_armor(duration)` reactiva la armadura por tiempo limitado (usado por ataques que la re-arman) y la revierte a `NORMAL` sola si nadie la cambio antes.

## Tuning del poise

Exports por escena en `EnemyBase` (excepcion de enemigos); en `PlayerTuning` grupo Stun > Poise para el player.

| Knob | Default | Que hace |
|---|---|---|
| `poise_max` | 6.0 | Reserva a romper. `WorldSwitchEnemy` e `HybridEnemy` usan 12 (cuesta mas), el ultra agresivo 9. |
| `armor_poise_bonus` | 6.0 | Reserva extra mientras esta armado. Se pierde al romperse la armadura. |
| `poise_decay_per_second` | 1.5 | Drenaje lineal del acumulado. Alto = hay que encadenar rapido. |
| `poise_break_levels` | `[1.0, 0.8, 0.6, 0.4, 0.2, 0.0]` | Escalera de degradacion. El player usa `[1.0]`. |
| `poise_recovery_time` | 20.0 | Segundos sin golpes tras los que la reserva vuelve al 100%. |

Poise por fuente (primer pase, **pendiente de tunear jugando**):

| Fuente | `poise_damage` | Lectura |
|---|---|---|
| [[Espada]] base | 2.0 | 3 golpes seguidos quiebran a un enemigo comun. No rompe a un armado sola. |
| [[Espada]] dash cargado | 4.0 | — |
| [[Mazo]] base | 6.0 | **Quiebra de un golpe**, siempre. |
| [[Mazo]] freeze (sweet spot cargado) | 12.0 | Quiebra de un golpe **incluso armado**. |
| Dash del player | 2.0 | Suma al stagger como un golpe de espada. |
| Melee / ranged enemigo | 2.0 | Tienen que insistir para quebrar al player (reserva 6, drenaje 1.5/s). |
| `SpikeWall` | 6.0 | Un hazard quiebra rapido: `stun_poise_damage`. |

## El poise es el gate de TODO desplazamiento

> [!important] Con poise de sobra, al enemigo no se lo mueve de ninguna forma
> `launch`, `push`, `slam`, `slam_bounce` y `slam_arc` comparten un unico gate en `EnemyBase`
> (`_breaks_poise`): el desplazamiento entra **solo** si la reserva ya esta quebrada (`STUNNED`)
> o si el golpe que lo trae la quiebra ahora mismo. Un enemigo que aguanta come el daño, tira el
> fogonazo blanco y **no se mueve**. *(2026-07-13, reemplaza el viejo guard `is_armored()`)*

Antes cada verbo se gateaba con `is_armored()` — el vestigio del modelo de umbral instantaneo.
Eso producia la incoherencia: un enemigo **sin** armadura salia lanzado aunque tuviera la reserva
intacta, y uno **con** armadura era inmune aunque el golpe se la quebrara. Ahora manda el poise y
la armadura deja de ser un caso aparte: es reserva extra (`armor_poise_bonus`), o sea
**resistencia, nunca inmunidad** — el sweet spot del [[Mazo]] (12) mueve a un armado igual.

### El launcher consulta el poise, no lo consume

El launcher corre en `about_to_hit`, **antes** de que el golpe cobre el poise (asi el stun
posterior ve al enemigo ya `AIRBORNE` y le da la duracion aerea). Por eso `launch()` recibe el
`StunSettings` del golpe y usa `Poise.would_break()`: **consulta** si esa reserva se va a quebrar,
sin consumirla. El golpe la consume despues, en `on_hurtbox_hit`. Consumirla en el launch la
cobraria dos veces.

Los demas verbos corren **despues** del golpe (en `landed`, o tras el `try_apply_stun` de
`apply_spike_hit`), asi que les alcanza con `is_stunned()`.

### El rebote del jugador no mueve al enemigo

`PlayerEnemyBounce` no trae `poise_damage` propio (no figura en la tabla de fuentes de arriba):
rebotar sobre un enemigo **no lo desplaza** salvo que ya este stuneado. El jugador rebota igual
—su impulso es suyo—, pero el enemigo aguanta plantado. *(2026-07-13)*

## Interaccion con el aire (juggle)

> [!important]
> Un golpe que aplica stun mientras el enemigo esta `AIRBORNE` (por `launch` o `push`) cancela el impulso previo, aplica un retroceso corto propio del stun y extiende `_airborne_until` hasta que termine el stun (`maxf(_airborne_until, _stunned_until)`) — queda suspendido en el aire, no cae hasta que el stun expira. `airborne_max_time` sigue siendo solo el tope de seguridad de caida, no compite con esta extension.

## Acostado y ragdoll de aterrizaje

> [!important]
> Un enemigo **empujado** (`push`) o **stuneado en el aire** cae **acostado** (pose horizontal). Es solo la pose: la trayectoria previa no cambia — el hang del stun aereo y el arco del push siguen intactos. El rigid body NO existe en el aire. *(2026-07-10)*

- La pose acostada reusa el mismo eje que la inclinacion del stun (se aleja del atacante), pero al angulo pleno `lie_angle` (90 por default) y **girando sobre la MITAD del modelo** (centro de la capsula), no desde los pies — el cuerpo se tumba sobre su centro. La inclinacion corta del stun en tierra sigue pivotando desde los pies. En el piso (ragdoll) el pivote ya no importa: manda la fisica.
- **Esfera de proximidad (`GroundSense`)**: un `Area3D` esferico (mask `LAYER_WORLD`) siente el suelo un pelo antes que los pies. Cuando un cuerpo acostado la toca (tras haber salido del rango una vez), arranca el ragdoll **justo antes** del contacto real, para que se vea natural. Los pushes bajos que nunca salen del rango caen por `is_on_floor()`.
- **Ragdoll de cuerpo unico**: al aterrizar acostado, el `CharacterBody3D` apaga su colision y su `Visual`, y un `RigidBody3D` (`Ragdoll`, `top_level`, mask `LAYER_WORLD`) toma la posta con la velocidad heredada + un giro (`ragdoll_spin`) para rodar. El cuerpo (Hurtbox/luz) sigue al ragdoll en el plano. El ragdoll es una representacion fisica, no reemplaza `combat_state`: si el enemigo ya estaba stuneado, conserva el brillo y la luz amarillos en el mesh activo.
- **Se para**: tras `ragdoll_getup_delay` (0.5 s, el "se para en X") y solo cuando ya vencio cualquier stun vigente, el ragdoll se congela, el cuerpo se reubica donde rodo y se endereza con un tween de `ragdoll_stand_time`.
- Durante el ragdoll puede recibir stun: el golpe extiende el timer, congela el `RigidBody3D` y mantiene el feedback amarillo. Sigue sin recibir `launch`/`push` (la fisica manda), pero el **daño igual entra** por `Hurtbox.receive_hit → Health`.
- Tuning (exports por escena, excepcion de enemigos): `lie_angle`, `ragdoll_getup_delay`, `ragdoll_stand_time`, `ragdoll_gravity_scale`, `ragdoll_spin`, mas el radio/altura de la esfera `GroundSense` en la escena. *(2026-07-10, pendiente de tunear jugando)*

> [!note] Diferidos a H3
> El ragdoll es de **cuerpo unico** (la capsula rueda), no por huesos — el ragdoll por `PhysicalBone` espera al rig de H3 ("cero arte final antes de H3"). La reubicacion al pararse usa la **altura de despegue** (greybox plano); en H3, raycast al piso real para terreno con desnivel.

## Direccion del golpe

`_last_hit_direction` es la direccion que **aleja al enemigo de su atacante**, no la de la hitbox que lo toco. La calcula `_remember_hit_direction()` desde la posicion de quien golpea; la direccion de la hitbox (`hitbox → hurtbox`) solo entra como fallback cuando no hay atacante posicionable.

> [!important]
> La hoja de un arma orbita alrededor del jugador (ver [[Combate]]): a mitad de un swing esta a un costado del enemigo, o mas alla. Su posicion no sirve como origen del golpe.

Tanto el retroceso como la inclinacion del stun leen esta direccion. *(2026-07-09)*

## Parry

> [!important] El parry hace daño de poise, no de HP
> Un parry correcto (el player contragolpea a un enemigo a mitad de su swing, dentro de la ventana
> de `MeleeAttack`) ya no aplica un stun plano: **mete poise** al enemigo, cuyo monto sale del arma
> y del tipo de ataque con que el player parrió. Si ese poise **quiebra la reserva**, el enemigo
> entra al estado **vulnerable cian**; si no alcanza (armado / reserva alta), tira el fogonazo
> blanco y sigue peleando. *(2026-07-14, reemplaza el `apply_parry_stun(1.2)` fijo)*

**Poise que inflige (por arma, en `WeaponTuning`):** tres valores, aéreo y suelo comparten cada uno.

| Knob | Espada | Mazo | Lectura |
|---|---|---|---|
| `parry_poise_normal` | 6.0 | 8.0 | Golpe normal. Quiebra a un enemigo común (reserva 6) de un parry. |
| `parry_poise_charged_x` | 9.0 | 12.0 | Cargado X (dash / vueltas). |
| `parry_poise_charged_y` | 12.0 | 16.0 | Cargado Y (launcher / cargada aérea). Quiebra incluso a un armado (reserva 12). |

El valor lo resuelve `PlayerCombat.current_parry_poise()` según el `AttackKind` del último ataque
iniciado (tap = NORMAL, hold X/Y = cargado). Lo lee el enemigo parriado por duck typing.

**Qué ataques pueden parriar:** el combo normal y la Y cargada aérea siempre pudieron; ahora
además el **X cargado (dash)** y el **Y cargado terrestre (launcher)** son `can_be_parried = true`
(Espada y Mazo). El AOE aéreo del Y del Mazo queda sin parriar a propósito (es multi-target).

**Outcome de un parry correcto (`ParryTuning`, `data/parry_tuning.tres`, compartido):**

- Rompe la reserva (queda `STUNNED`, así el juggle entra directo) y **stun `stun_duration = 1.5s`**.
- Estado **vulnerable**: durante `vulnerable_duration` (1.5s) recibe daño `× damage_multiplier` (2.0).
  El multiplicador lo aplica `Hurtbox.receive_hit` vía `EnemyBase.incoming_damage_multiplier()`.
- Pinta **cian** en vez de amarillo (`cyan_color`) con emisión más alta (`cyan_emission_energy`).

Un enemigo puede sobreescribir el `.tres` compartido con su propio `@export var parry_tuning`.

## Golpes al player

Los ataques melee y proyectiles enemigos llevan su propio `StunSettings`. Si su poise **quiebra
la reserva** del player, este entra en `PUSH`: se aleja del atacante, pierde el control y emite
amarillo. Si no la quiebra, come el daño, tira el fogonazo blanco y sigue jugando. El impulso se
configura por ataque con `player_stun_push_speed` y `player_stun_push_vertical_speed`. *(2026-07-13)*

## I-frames del dodge

> [!important] El gate vive en `try_apply_stun`, no en el Hurtbox
> El daño (HP) del player pasa por `Hurtbox.can_receive_hit()` — ahí `Player.can_receive_hit()`
> bloquea via duck-typing. Pero el stun de melee/ranged enemigo **no pasa por el Hurtbox**:
> `MeleeAttack._on_blade_landed` y `Projectile._on_body_entered` llaman directo a
> `player.receive_stun()` / `try_apply_stun()`. Por eso los i-frames se cortan ahí, el embudo
> real de TODO stun del player (tambien lo usa `SpikeWall`). Cortar solo en `can_receive_hit`
> hubiera bloqueado el daño pero dejado pasar el stun. *(2026-07-13)*

Durante el dodge (`PlayerDash.dodge()`, nunca en `force_dash`), `PlayerDash._iframe_timer` corre
en paralelo al timer del dash y expone `is_invulnerable()`. Clampeado a la duracion del dash
(el timer solo tickea mientras `is_dashing`). `Player.try_apply_stun` devuelve `false` de entrada
si `dash.is_invulnerable()`, sin tocar poise. Tuning: `PlayerTuning.dodge_iframe_duration`
(grupo Dodge, default 0.1s) — **pendiente de tunear jugando**.

## Lenguaje de color del impacto

Tres colores, tres cosas distintas. Se leen sin HUD:

| Color | Que significa | Donde vive |
|---|---|---|
| **Blanco** | El golpe **comio poise pero no quebro**: "te di, aguanto". Solo emision, un destello — el albedo no se toca, asi que no cambia el color del cuerpo. | `poise_chip_color` / `poise_chip_energy` / `poise_chip_time` (`EnemyBase`); mismos knobs en `PlayerTuning`. *(2026-07-13)* |
| **Amarillo** | **Stuneado**: la reserva se quebro. Pinta albedo + emision + `StunLight`. | `_stun_feedback_color` (`EnemyBase`), `stun_color` (`PlayerTuning`). |
| **Rojo** | **Hazard** (`SpikeWall`): stun + daño + push. El rojo distingue el peligro del entorno del impacto de combate. | `hazard_stun_color` (`SpikeWall`). *(2026-07-12)* |
| **Celeste** | **Vulnerable por parry**: la reserva se quebró con un parry. Pinta cian + emisión alta + daño multiplicado mientras dura la ventana. | `ParryTuning.cyan_color` / `cyan_emission_energy`. *(2026-07-14)* |

Manda siempre el estado mas fuerte: si el golpe quiebra, el fogonazo blanco no se dispara, y si un
stun entra a mitad de un destello, este se cancela para no pelearle la emision al amarillo.

## Chispas de impacto

`HitSparks` (`GPUParticles3D` one-shot) escupe chispas rojas incandescentes en **todo golpe recibido**, stunee o no. Nacen en la superficie que mira al atacante — `hit_sparks_height` sobre los pies y `hit_sparks_offset` adelantadas hacia el — no en el centro del cuerpo. *(2026-07-09)*

El emisor es `top_level`: las particulas viven en el mundo, asi que el squash, la inclinacion y el giro del enemigo no las deforman ni se las llevan. El halo ya funciona: `test_scene` tiene un `WorldEnvironment` con glow (ver [[Combate]]); la emision alta de las chispas lo aprovecha. Falta tunear el bloom jugando.

## Reaccion visual

Mientras `combat_state == STUNNED`, `EnemyBase` activa cuatro capas de feedback:

- Color amarillo + emision en los meshes bajo el pivote `Visual`.
- `StunLight` (`OmniLight3D`) amarilla, apagada por default y encendida solo durante el stun.
- Inclinacion del pivote `Visual` hacia atras, pivoteando desde los pies: el origen del enemigo esta a ras del piso, asi que `Visual` rota sobre el eje horizontal perpendicular al golpe. Tween de ida y vuelta.
- Squash: el enemigo se encoge a `stun_squash_scale` y rebota hasta su escala normal. Escala el pivote `Visual`, asi que se hunde contra el piso. Cada golpe reinicia el rebote, y un combo se lee como una sucesion de impactos.

El rebote ocupa solo el arranque del stun, no toda su duracion: termina de encogerse a los `stun_squash_in_time` segundos del golpe y ya recupero su tamaño a los `stun_squash_out_time`. El resto del stun el enemigo se queda grande. Los tiempos son **absolutos**, no fracciones: retunear la duracion del stun no deforma el gesto del impacto. Un stun mas corto que el gesto lo recorta. Corre en su propio tween, en paralelo con la inclinacion.

El retroceso desplaza al enemigo alejandolo del atacante, reemplaza cualquier push previo y decae durante el stun.

El squash y la inclinacion solo afectan al pivote `Visual`: la capsula de colision y la `Hurtbox` no cambian de tamaño.

El mesh del arma (`MeleeAttack/Weapon`) no se pinta con el estado del enemigo: queda fuera del pivote `Visual` a proposito para no mezclar el feedback de stun con posibles telegraphs/colores propios del ataque.

Los valores son exports por escena en `EnemyBase`, siguiendo la excepcion actual de enemigos: `stun_knockback_speed`, `stun_knockback_decay`, `stun_tilt_angle`, `stun_tilt_time`, `stun_squash_scale`, `stun_squash_in_time`, `stun_squash_out_time`, `stun_emission_energy`, `stun_light_energy` y `stun_light_range`. *(2026-07-09, pendiente de tunear jugando)*

## Duraciones actuales de fuentes del jugador

La duracion la define la fuente via `StunSettings`; el enemigo solo decide si entra por threshold. En tierra el stun es corto — el enemigo se recupera rapido; en el aire dura mas para sostener el juggle.

- Espada normal y dash cargado: `grounded = 0.35`, `airborne = 1.0`.
- Dash del player: `grounded = 0.35`, `airborne = 1.0`.
- Mazo base: `grounded = 0.35`, `airborne = 0.9`.
- Freezes del sweet spot del Mazo: largos a proposito (`Resource_macefreeze = 1.4`, `Resource_maceairfreeze = 1.2`) para mantener enemigos congelados hasta la ultima vuelta.
- Parry correcto: `ParryTuning.stun_duration = 1.5` (compartido, `data/parry_tuning.tres`). No pasa por `StunSettings`; el parry mete poise por arma/ataque (`WeaponTuning.parry_poise_*`) y, si quiebra, entra por `apply_stun()` pintado cian. Ver sección Parry.

## Relacionado

- [[Estados de Combate Enemigo]]
- [[Combate]]
- [[Armored Enemy]]
