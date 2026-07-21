# Contrato Tecnico De Armas

## Capas

`WeaponBase` resuelve infraestructura común: hitboxes, ventanas, meter, combo, push y solicitudes verticales. El script concreto decide la personalidad del arma. `Player` y `EnemyBase` ejecutan física; no inventan perfiles de ataques.

## Movers

Un `MoverSettings` contiene dirección, distancia, velocidad, aceleración, condiciones de parada y Float final.

- `TOTAL`: el Mover hace el desplazamiento completo con su propio `move_and_slide`. Usarlo para launch, spike y trayectorias que no deben mezclarse con locomoción.
- `PARTIAL`: solo controla Y dentro del tick normal del Player. Usarlo para movimientos que deben preservar contactos y horizontal, como plunge u hop corto.

Un Mover nuevo reemplaza al anterior del mismo cuerpo. En EnemyBase, un hit posterior también cancela Mover/Floater anteriores. No hacer que un total sea inmune a interrupciones de combate.

## Floater

Floater decide la caída temporal, no el stun. Expresarlo con `float_duration` y `float_fall_scale` en el perfil cuando sea consecuencia de una trayectoria. Usar `request_float` cuando el ataque solo necesita un hold sin recorrido.

EnemyBase acepta Float solo si está en el aire y stuneado/quebrado. El ataque no debe esquivar ese gate.

## Poise Y Orden

Para un golpe que lanza antes de infligir daño:

1. En `about_to_hit`, llamar `EnemyBase.request_mover(profile, stun, starts_lying, true)`.
2. EnemyBase consulta si ese stun quebraría poise y arma el Mover solo si procede.
3. El daño aplica el stun.
4. La marca de preservación evita que ese mismo hit cancele su Mover; el siguiente hit sí lo cancela.

Para un movimiento que ocurre después de daño, pedir `request_mover(profile)` tras confirmar que el target está stuneado.

## Recursos Recomendados

Nombrar perfiles por intención y receptor:

```gdscript
@export var charged_y_player_mover: MoverSettings
@export var charged_y_enemy_mover: MoverSettings
@export var aerial_spike_enemy_mover: MoverSettings
@export var sweet_spot_enemy_mover: MoverSettings
```

No compartir un perfil entre Player y Enemy si sus velocidades, contacto o Float difieren. No usar `PlayerTuning.launcher_*` para un movimiento nuevo de arma.

## Antipatrones

- Arma escribiendo `vertical_velocity` o `velocity.y`.
- `StunSettings.airborne` usado como duración de hang.
- EnemyBase iniciando Floater automáticamente al recibir stun.
- Un hit normal que deja activo el Mover de un ataque anterior.
- Reutilizar `launch`/`slam` como API nueva.
- Simular un rebote balístico con Mover lineal.
