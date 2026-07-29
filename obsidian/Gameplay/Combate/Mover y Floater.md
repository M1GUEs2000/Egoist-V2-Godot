---
title: Mover y Floater
tags:
  - egoist
  - gameplay
  - sistema
  - combate
  - movimiento
status: active
system_status: E2
hito: H1
---

# Mover y Floater

`Floater` y `Mover` son las primitivas de control dirigido del combate. Un ataque decide el perfil que necesita; el cuerpo que recibe la orden lo ejecuta. Esta separacion evita que Espada, Mazo, Brazo y enemigos inventen su propia gravedad, timers o movimiento por frame.

## Regla central

- El ataque es dueno de la intencion y del tuning: define `MoverSettings` o `FloaterSettings` en su recurso.
- `Player` y `EnemyBase` son duenos de su fisica: instancian ambos componentes, aplican el resultado en su loop y deciden sus gates de estado.
- Cada componente solo controla a su propio cuerpo. Un movimiento para Player y Enemy requiere dos solicitudes y, normalmente, dos perfiles distintos.
- No mezclar estos movimientos con `push`, `slam_arc` o rebotes balisticos: esas rutas conservan trayectoria balistica propia hasta que exista el bouncer planeado.

## Floater

`combat/floater.gd` controla una suspension temporal. No recorre una distancia ni guarda velocidad para restaurarla despues: durante su ventana aplica la gravedad multiplicada por `fall_scale` y, al vencer, el cuerpo vuelve a su gravedad normal.

| Dato | Efecto |
|---|---|
| `FloaterSettings.duration` | Segundos de suspension. `0` desactiva la solicitud. |
| `FloaterSettings.fall_scale` | `0` fija la vertical en `0`; `1` deja gravedad normal; un valor intermedio deja caer lentamente. |
| Solicitudes repetidas | Conserva el vencimiento mas lejano y el ultimo `fall_scale` pedido. |

### Pedir un Floater

El perfil vive junto al ataque. Para el Player se pide mediante su API publica:

```gdscript
var hold := tuning.tap_forward_x_air_floater
if hold != null:
    _player.request_float(hold.duration, hold.fall_scale)
```

Para un Enemy, el ataque debe hacerlo despues de que el enemigo sea un receptor valido de control vertical. `EnemyBase.request_float(...)` protege esa regla con el gate de poise/stun:

```gdscript
if target is EnemyBase:
    (target as EnemyBase).request_float(hold.duration, hold.fall_scale)
```

### Ejemplos vigentes

- `WeaponBase._register_air_hit_float()` usa `WeaponTuning.air_hit_player_floater` al conectar un golpe aereo normal.
- `Sword._run_forward_x_static_spin()` usa `tap_forward_x_air_floater`: dos vueltas y hang para Player y objetivos conectados.
- `PlayerDash._on_dash_hit()` usa `PlayerTuning.dash_air_hit_floater` cuando el dash ofensivo conecta en el aire.
- `PlayerArm` aplica `ArmTuning.air_enemy_floater` al enemigo que conecta en aire.
- Un `MoverSettings` tambien puede terminar en Floater con `float_duration` y `float_fall_scale`; es la forma correcta de encadenar viaje y hang.

### Reglas de autoridad

- En Player, `request_float` no actua en piso ni mientras un dash es dueno de la vertical. Cancela el salto en curso y fija la vertical inicial en cero para que el hang sea legible.
- Un salto, wall jump o rebote de enemigo cancela el Floater. Tambien lo cancelan stun, dash, Mover nuevo y movimiento de locomocion que toma autoridad.
- En Enemy, un Floater no puede levantar ni sostener a alguien con poise intacto: requiere stun, ragdoll o que el golpe haya quebrado la reserva.

## Mover

`combat/mover.gd` recorre una direccion con distancia, velocidad, aceleracion y condiciones de corte. El componente normaliza la direccion, recorta el ultimo frame para llegar a la distancia exacta y emite `mover_finished` o `mover_cancelled`.

| Dato de `MoverSettings` | Efecto |
|---|---|
| `direction` | Direccion del viaje, normalizada al iniciar. |
| `distance` | Metros maximos. Es el limite duro de seguridad. |
| `speed`, `acceleration` | Velocidad inicial y cambio en m/s2. |
| `stop_on` | Flags de distancia, piso, pared o enemigo. La deteccion de `ENEMY` aun no esta implementada. |
| `mode` | `TOTAL` toma el cuerpo completo; `PARTIAL` controla solo Y del Player. |
| `float_duration`, `float_fall_scale` | Floater solicitado al finalizar correctamente. |

### TOTAL y PARTIAL

- `TOTAL`: el Mover escribe `velocity`, llama `move_and_slide()` y reemplaza locomocion/gravedad durante el recorrido. Usarlo para launchers, desplazamientos verticales del enemigo y trayectorias dirigidas completas.
- `PARTIAL`: el Mover solo escribe la velocidad vertical dentro del tick normal del Player. Conserva input horizontal, contactos, wall slide, dash y rebote de enemigo. Usarlo para un plunge o hop estrictamente vertical; no para diagonales u horizontales.

### Pedir un Mover

```gdscript
var profile := tuning.air_plunge_player_mover
if profile != null:
    _player.request_mover(profile)

var enemy_profile := tuning.air_plunge_enemy_mover
if target is EnemyBase:
    (target as EnemyBase).request_mover(enemy_profile, tuning.stun)
```

`WeaponBase.run_vertical_window(...)` es la utilidad para ataques cuyo hitbox debe solicitar primero el Mover del enemigo y luego cobrar el dano. Conecta al objetivo mediante `Hitbox.about_to_hit`, de modo que el stun del mismo golpe ya lo ve en el aire.

### Ejemplos vigentes

- Espada: `ground_charged_y_player_mover` y `ground_charged_y_enemy_mover` para el Y cargado terrestre.
- Espada: `air_wait_spin_player_mover` para el hop de la rama aerea de espera y `air_plunge_player_mover` en modo `PARTIAL` para el plunge.
- Espada: `tap_back_x_air_player_mover` y `tap_back_x_air_enemy_mover` suben ambos cuerpos dos unidades y terminan en hang.
- Mazo: su launcher terrestre usa perfiles propios para Player y Enemy a traves de la misma ventana vertical.

## Cancelacion y orden

Un Mover nuevo reemplaza al anterior con `Mover.CancelReason.SUPERSEDED`; no inicia el Floater del perfil cancelado. El receptor tambien debe cancelar control previo cuando gana otra autoridad:

- Stun cancela Mover y Floater.
- Dash, bump y locomocion dirigida cancelan ambos en Player cuando corresponda.
- Un golpe nuevo cancela Mover/Floater previos del Enemy. La excepcion es el Mover que el mismo golpe armo antes del dano por `about_to_hit`.
- Al aterrizar, Player corta su Floater; los `stop_on` del Mover deciden si el recorrido tambien termina en piso o pared.

Antes de agregar una mecanica, elegir una sola fuente de autoridad por tramo: Mover para recorrido, Floater para hang, gravedad normal para caida. No escribir `vertical_velocity` directo en paralelo salvo que sea una excepcion de traversal o una trayectoria balistica documentada.

## Archivos clave

| Archivo | Responsabilidad |
|---|---|
| `combat/floater.gd` | Estado temporal y calculo de gravedad escalada. |
| `combat/mover.gd` | Recorrido, finales, cancelaciones y Float opcional de salida. |
| `data/floater_settings.gd` | Perfil de hang por ataque. |
| `data/mover_settings.gd` | Perfil de trayectoria por ataque. |
| `player/player.gd` | API y ejecucion de Player. |
| `enemies/enemy_base.gd` | API, gate de poise y ejecucion del Enemy. |
| `combat/weapons/weapon_base.gd` | Ventana vertical que coordina Player, Enemy e hitbox. |

## Relacionado

- [[Combate]]
- [[Armas]]
- [[Espada]]
- [[Mazo]]
- [[brazo-combate|Brazo Combate]]
- [[Stun]]
- [[Plan Autoridad Vertical]]
- [[Mapa Impacto Autoridad Vertical]]
