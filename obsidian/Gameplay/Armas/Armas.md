---
title: Armas
tags:
  - egoist
  - gameplay
  - armas
  - combate
status: active
system_status: E2
hito: H1
---

# Armas

4 armas en total. Se equipan en slot X (ligero) o Y (pesado). El comportamiento cambia segun el slot. Los ataques cargados y el sweet spot son mecanicas transversales a todas las armas; ver [[Combate]].

> [!info] Scope
> Las 4 armas son el roster definitivo: [[Espada]], [[Mazo]], [[Dagas]] y [[Punos]]. H1 se concentra solo en Espada.

## Reglas base

- Dos slots: X/Y.
- Tap y hold.
- La personalidad depende del slot.
- Misma arma en ambos slots permitido; el loadout X/Y ya existe como overlay con `Tab` (ver [[Combate]]). *(2026-07-07)*
- Los cargados consumen meter.
- Sweet spot es una capa transversal de perfeccion/timing.

## Roster

| Arma | Rol | Hito |
|---|---|---|
| [[Espada]] | Base/equilibrada, mantiene flujo. | H1 |
| [[Mazo]] | Mas dano, control de masas, knockback. | H2 |
| [[Dagas]] | Movilidad, persecucion, teletransporte. | H2 |
| [[Punos]] | Agarre, mover enemigos o moverte tu, conecta con world switch. | H2 |

## Como se hace un arma

Esta seccion es el recorrido completo, en orden. Lo de abajo —"Organizacion del tuning" y lo que sigue— es el **por que** de cada decision; esto es el **como**.

> [!important] Leer antes de empezar
> - [[Mover y Floater]] — quien es dueño de la fisica de cada cuerpo. Un arma **nunca** escribe velocidad: pide perfiles.
> - [[Animacion]] — como entra un clip a la libreria del maniqui. Sin eso, el arma no se ve.
> - [[Contrato AttackClip]] — que declara un golpe animado y por que el hitbox cuelga del hueso.
> - [[Espada]] — la referencia implementada. Cuando algo de aca no alcance, mirar como lo resolvio ella.

### 1. La escena

Un arma es una `.tscn` con un `Node3D` raiz que lleva el script del arma. **El raiz se instancia en el origen del Player**, no en la mano: lo que va a la mano se marca con un grupo.

```
Espada (Node3D + sword.gd)
├── Hand (Node3D)                              ← OBLIGATORIO, aunque quede vacio
│   └── Pivot (Node3D)                         ← OBLIGATORIO
│       ├── BladeMesh                          ← grupo hand_attachment_payload
│       └── BladeHitbox (Area3D + hitbox.gd)   ← grupo hand_attachment_payload
│           └── CollisionShape3D
├── AirDiscHitbox (Area3D)                     ← opcional: disco alrededor del Player en golpes aereos
└── ...los hitboxes propios de los especiales del arma
```

Lo que hay que respetar, y por que:

- **`Hand/Pivot` y `Hand/Pivot/BladeHitbox` son rutas fijas.** `WeaponBase` las toma con `@onready`; si no existen, el arma revienta al entrar al arbol. Sobrevivieron al swing procedural aunque ya no orbiten: `Pivot` quedo como percha de lo que se crea en runtime (las motas de sweet spot).
- **Todo lo que tenga que verse en la mano va al grupo `hand_attachment_payload`** — los meshes **y** el hitbox de la hoja. `PlayerAnimationController` los reparenta al `BoneAttachment3D` del hueso `hand_r`. Si te olvidas del grupo en el hitbox, tenes de nuevo el bug de las dos espadas: una que se ve y otra que golpea.
- **El mesh de la hoja se tiene que llamar `BladeMesh`, `HeadMesh` o `HandleMesh`.** `_find_charge_glow_mesh()` los busca por nombre en ese orden para colgarles el glow de carga. Con cualquier otro nombre el arma funciona pero no brilla al cargar, y no avisa.
- **Los hitboxes que NO son la hoja se quedan afuera del payload**: el disco aereo es un area alrededor del Player, no del arma, asi que no debe seguir al hueso.

### 2. El script

```gdscript
class_name MiArma extends WeaponBase

func tap(slot: World.Slot) -> void: ...
func hold(slot: World.Slot, level: int) -> void: ...
func _default_tuning() -> WeaponTuning: return MiArmaTuning.new()
```

`WeaponBase` ya trae la ventana de daño, el runner de secuencias, el push, el parry, la progresion por kills, el glow de carga y el cobro de los `AttackMovementProfile`. El arma pone **solo su personalidad**: que hace X, que hace Y, tap contra hold, y los ganchos direccionales (`try_lock_back_y_launcher` y familia) si los usa.

Ganchos opcionales que vas a querer:

- `on_sequence_step(step, chain_step, finisher, duration)` — mecanicas del arma que no son dato, reconocidas por `AttackStep.choreography`. **No dibuja nada**: el dibujo es el clip.
- `is_charged_move_active()` — si el arma tiene cargados que mueven al Player a proposito, para que el corte de momentum aereo los deje pasar.
- `begin_sequence_step_damage_window(step, duration, runs_profile_hooks, clip)` — si un golpe cobra con un hitbox propio en vez de la hoja (el X cargado de la Espada usa su `ChargedDashHitbox`). Sobrescribirlo evita duplicar el runner entero.
- `sequence_step_movement_profile(step)` — ajustar el perfil de un paso con contexto de runtime sin mutar el `.tres` (el sweet spot aereo de la Espada reapunta el Mover en 3D al target lockeado).

### 3. El tuning

Un `.gd` que extiende `WeaponTuning` mas un `.tres` en `data/`. Como se organiza el inspector esta abajo, en "Organizacion del tuning": leerlo no es opcional, es lo que hace que el recurso siga siendo navegable a los treinta campos.

> [!warning] Renombrar un `@export` borra su valor
> Los `.tres` serializan **por nombre**. Cambiarle el nombre a un campo, o sacarlo, resetea ese valor en toda instancia que lo tuviera, en silencio. Si vas a renombrar, actualiza el `.tres` en el mismo commit.

### 4. Los combos

Un `AttackSequence` por cadena, en su propio `.tres`, apuntado desde el tuning del arma. El detalle esta en "Los combos tambien son datos", abajo. En corto: un `AttackStep` por golpe, cada uno con su clip, su duracion, su `damage_scale`, su `AttackMovementProfile` y su rama por espera.

El arma solo lo dispara:

```gdscript
func _tap_combo() -> void:
    reset_hit_profile()
    var kind: StringName = &"air" if _player.is_airborne() else &"ground"
    if try_queue_combo(kind):
        return
    run_attack_sequence(kind, _t().ground_combo)
```

`try_queue_combo` es lo que hace que un tap a mitad de cadena encole el golpe siguiente en vez de reiniciarla.

#### Un especial tambien es una secuencia

`AttackSequence` corre las dos formas de golpe, y la diferencia es un bool:

| | Combo | Gesto (`auto_chain`) |
|---|---|---|
| Como avanza | un tap por golpe, dentro de `chain_window` | los pasos salen solos, uno tras otro |
| Ramifica por espera | si | no: no hay espera que medir |
| Encola taps | si | no, el tap arranca su propio combo |
| Ejemplos | tap X terrestre, tap X aereo | cargados, taps direccionales, secuencias de RT |

O sea que **un cargado puede ser tres animaciones** con tres ventanas de dano, tres `damage_scale` y un Mover distinto en cada tramo, sin una linea de codigo nueva:

```gdscript
func _hold_x() -> void:
    cancel_routines()
    reset_hit_profile()
    if _player.meter.spend_charged(1, true, tuning.meter_cost_scale(sweet_spot)):
        run_attack_sequence(&"charged_x", _t().charged_x_sequence)
```

Lo que **no** es dato y se queda en el arma: si el gesto cuesta barra, si exige estar en el aire, hacia donde apunta, y el fallback cuando no hay barra. Eso se resuelve antes de llamar al runner.

Dos detalles del gesto que no tiene el combo:

- **No lo frena el recovery del combo.** Un move deliberado que ademas paga barra no se lo puede comer la cola de una cadena. El gesto si deja el suyo al terminar.
- **`recovery` propio.** -1 usa el `combo_recovery` del arma; un tramo de RT que encadena con otra cosa suele querer 0.

### 5. Las animaciones

Cada golpe se dibuja con un `AttackClip`: que clip, de que segundo a que segundo, cuanto mas rapido sale que sus vecinos (`speed_bonus`, en %), y **en que fraccion de ese tramo el hitbox esta abierto** (`hitbox_open` / `hitbox_close`, normalizados 0-1). Ese ultimo par es lo que hace que el golpe pegue en el impacto y no durante todo el swing.

El clip tiene que existir en la libreria del `AnimationPlayer` del maniqui. La libreria base es UAL2; lo que no esta ahi se copia en runtime:

- clips de UAL1 → constante `UAL1_ANIMATIONS` en `PlayerAnimationController`
- clips propios (`.glb` sueltos en `animaciones/`) → un `preload` mas la constante `CUSTOM_ANIMATIONS`

O sea: **un clip nuevo no alcanza con dejarlo en la carpeta**, hay que darlo de alta ahi. Un nombre que no existe no es error de compilacion — sale un `push_warning` y el golpe se queda sin dibujo. Ver [[Animacion]].

Los tiempos van en **segundos, no en frames**: es 3D con esqueleto UAL y el `AnimationPlayer` de Godot trabaja en segundos.

### 6. El movimiento

Un arma **nunca** escribe la velocidad de nadie. Declara `MoverSettings` / `FloaterSettings` dentro de un `AttackMovementProfile` y el dueño de cada cuerpo los aplica (ver [[Mover y Floater]]).

El perfil vive **dentro del `AttackStep`** que lo emite, tanto en un combo como en un especial: el beat en el que sale el Mover es tuning. Solo queda suelto en el tuning del arma el gesto que todavia no puede ser secuencia — el tap atras + Y terrestre de la Espada, que sale por una ventana vertical.

`WeaponBase` los cobra solo, en el momento que el perfil declare (`BEFORE_DAMAGE`, `ON_HIT`, `WINDOW_END`). El arma no pide nada.

### 7. Enchufarla

1. Instanciar la escena del arma como **hija directa del Player** en `player.tscn`. `PlayerCombat` y `PlayerAnimationController` recorren los hijos del Player para encontrarlas: un arma que cuelgue de otro lado no existe para el juego.
2. Asignarla a `slot_x` / `slot_y` en el `PlayerCombat` del Player, o dejarla suelta para que el overlay de loadout la ofrezca con `Tab`.

`setup(player)` corre solo y cablea los hitboxes: fuente, daño base, stun, dedup compartido y la señal `landed`.

### 8. Verificar

Los pasos de `METODOLOGIA.md`: `--import`, `--quit-after 2`, y **jugarla**. El feel no lo aprueba un check headless. Si hace falta comprobar que los `.tres` del arma quedaron sanos (un clip que apunta a una animacion inexistente, un paso sin empujon), correr `tools/check_attack_data.gd`.

---

## Organizacion del tuning

Cada arma tiene su recurso propio (`SwordTuning`, `MaceTuning`) que extiende `WeaponTuning`, con la instancia editable en `data/`. Lo que es transversal al arma —swing time, push, parry, meter, sweet spot— vive en `WeaponTuning`; lo que es personalidad de un golpe vive en el recurso del arma.

El inspector se agrupa por **tipo de ataque, nunca por tipo de dato**. No existe un grupo "Movers" ni "Floaters": cada perfil vive junto al golpe que lo emite.

| Nivel | Que separa | Ejemplo |
|---|---|---|
| `@export_category` | Familia de ataque | Ataques normales (tap) · Cargados (hold) · Taps direccionales |
| `@export_group` | Golpe concreto, con prefijo de nombre para que el inspector lo recorte | `Tap Y atras`, prefijo `tap_back_y_` |
| `@export_subgroup` | Coreografia e input del golpe | `Coreografia, input y dano RT` |

Ningun ataque llega ya a un campo por cuerpo: cada gesto es **un `AttackSequence`**, y dentro de cada paso vive el `AttackMovementProfile` con los slots de cada cuerpo. Los campos sueltos que quedan debajo del grupo son los que no son posicion (ventanas, costes, bonos de dano). Ver las secciones de abajo.

Reglas:

- **Un campo por cuerpo que el golpe realmente mueve.** Un Mover o un Floater solo controla a su dueno (ver [[Mover y Floater]]), asi que mover a los dos son dos perfiles. Para campos SUELTOS del tuning sigue valiendo que no se crean vacios por simetria; dentro de un `AttackMovementProfile` la regla se invierte (ver mas abajo).
- **Un perfil por golpe.** Dos golpes que hoy se sienten igual llevan perfiles separados igual, para poder tunearlos aparte sin que uno arrastre al otro.
- **Nombre = gesto + tramo + cuerpo + primitiva**, en ese orden: `tap_back_y_air_enemy_mover`. El prefijo del grupo hace que el inspector muestre solo la cola.
- Lo que comparten varios golpes va a un grupo `Comun a varios golpes`, no se duplica.
- Todo `@export` de tuning lleva comentario `##` encima (que hace, unidades, efecto): es el tooltip del inspector.

### Un perfil por gesto, no un campo por primitiva

Cuando un golpe acumula muchas primitivas, sus campos sueltos dejan de caber: la variante aerea RT de `tap atras + X` llego a ser **cinco campos repartidos en tres subgrupos** mas los ids de rutina que el arma guardaba para reconectarlos al vuelo. A partir de ahi la agrupacion correcta es un `AttackMovementProfile` por **gesto** (gesto x tramo), con los knobs de coreografia e input debajo. *(2026-07-29)*

```
@export_group("Tap X atras", "tap_back_x_")
  tap_back_x_ground_sequence · tap_back_x_air_sequence
  @export_subgroup("Coreografia, input y dano RT")
    tap_back_x_window · tap_back_x_ground_meter_damage_bonus · tap_back_x_air_meter_damage_bonus
```

Las vueltas no aparecen: son `repeat` / `repeat_with_meter` del paso dentro de la secuencia.

El perfil responde una sola pregunta: **que le hace este golpe a la posicion de los cuerpos.** Ventanas, vueltas y coste de meter NO entran — si entra todo, el Resource deja de tener un tema y vuelve a ser una bolsa. Los slots y su semantica estan en [[Mover y Floater]] > Perfil de movimiento por ataque.

### Todos los golpes llevan perfil, aunque tengan slots vacios

Un `AttackMovementProfile` va en **todos** los golpes, no solo en los que hoy mueven a alguien. Un slot vacio adentro no es un olvido: es la forma de decir "este golpe no hace eso", y es lo que permite **agregar o sacar movimiento sin tocar codigo**. La rutina del golpe no pide Movers por su cuenta; `WeaponBase` los cobra desde el perfil en el momento que el perfil declare.

Esto invierte a proposito la regla de arriba para el caso de los perfiles. La regla original ("no se crean campos vacios por simetria") se escribio porque un campo vacio y un campo olvidado se ven igual en el inspector. Dentro de un perfil por gesto ese costo desaparece: el hueco tiene vecinos que le dan contexto y una semantica documentada. La regla sigue viva para los campos **sueltos** del tuning.

El **X cargado** es el caso donde un slot mentiria y aun asi lleva perfil: no mueve al Player con el Mover del slot sino con `force_dash`, que trae i-frames, hitbox propio y reposicionamiento al atravesar al objetivo. Su perfil declara el resto; el recorrido sigue siendo `force_dash`.

### Los combos tambien son datos

Un `AttackSequence` por cadena, con un `AttackStep` por golpe. Cada paso trae su clip, su `damage_scale`, su `stun` propio, cuantas veces sale (`repeat` / `repeat_with_meter`), si dispara el proyectil del arma (`fires_projectile`), y **su propio `AttackMovementProfile`** — asi que "el Mover sale en el tercer golpe" se declara en el inspector. Las ramas por espera cuelgan del propio paso (`wait_threshold` / `wait_steps`): tardar mas de ese umbral en encadenar reemplaza toda la cola de la cadena. *(2026-07-30)*

El `stun` por paso existe porque "un paso = un golpe" tambien multiplico el stun: si los cuatro golpes de una cadena comen el poise entero del arma, el primer swing quiebra igual que el finisher y no hay progresion posible. Es un `StunSettings` entero y no un multiplicador porque un golpe aereo suele querer `airborne` en 0 —que el Floater lo sostenga en vez de congelarlo— y eso no se expresa escalando un numero. **Nunca bajar `poise_damage` a 0 en un golpe aereo**: el Floater del enemigo tiene un gate de poise quebrado, asi que sin quiebre no lo sostiene y el juggle se cae.

La duracion de un paso no se declara en segundos: la base la pone `step_time` de la cadena (o el `swing_time` del arma) y el clip la escala con su `speed_bonus` en porcentaje. Un numero absoluto por paso obligaba a saber de antemano cuanto dura el golpe y quedaba desincronizado al retunear la cadena.

Una cadena es un **arbol**, no una linea con una desviacion. Como la rama cuelga del paso, los pasos de una rama pueden declarar la suya, y se puede ramificar tantas veces como golpes tenga el combo: `X X espera X espera X X X` es un paso con rama cuyo primer paso tiene otra. El aereo de [[Espada]] usa dos puntos de espera distintos (tras el golpe 1 a vueltas, tras el 2 al plunge).

> [!info] Por que no vive en la secuencia
> Las ramas nacieron como un `Array[AttackBranch]` de la secuencia, identificadas por un `after_step` absoluto. Eso obligaba a ramificar **una sola vez por corrida**: al reemplazar la cola el contador de pasos seguia corriendo, asi que la rama declarada mas adelante secuestraba a la que acababa de entrar. Colgando del paso no hay numeracion que colisione y `AttackBranch` dejo de existir. *(2026-07-30)*

> [!warning] Un paso = un golpe
> Cada `AttackStep` abre y cierra **su propia ventana de daño**. Antes una cadena de N golpes abria UNA ventana estirada sobre todos, asi que el enemigo cobraba una sola vez aunque vieras cuatro impactos — el tap adelante + X ya salia con dos vueltas y un golpe. Migrar multiplica el daño de toda cadena de mas de un paso; para eso esta `damage_scale` por paso, que es mas fino que bajar el daño base del arma (ese tambien afecta a los especiales).

Lo que un paso **no** duena es el dibujo del golpe: eso es su `AttackClip` y nada mas. `AttackStep.choreography` sobrevivio al swing procedural pero cambio de significado — ya no nombra un tween, nombra una **familia** de golpe para las mecanicas que no se pueden expresar como campo generico (sostener al Player en el aire durante el combo terrestre, estirar los hitboxes en V del finisher aereo). Es un escape hatch: si algo se puede expresar como campo del paso, va como campo. *(2026-07-30)*

### La variante RT es un porcentaje, no otro perfil

El primer intento fue un perfil por **variante** (gesto x tramo x RT), o sea el doble de perfiles. No funciono: obligaba a reescribir un recorrido entero para cambiar cuanto retrocede el RT, y los gestos que no usaban la variante dejaban slots vacios indistinguibles de un olvido —llegaron a ser cinco—. *(2026-07-29)*

La forma correcta es la que ya usa [[Sprint]] con sus canales: **el valor base vive una sola vez y RT entra como bono en % aplicado en el consumidor.** "Sin RT" pasa a ser multiplicar por `1.0` en vez de una rama con datos propios, y un hueco deja de existir porque `0%` es un valor legitimo.

Regla general para cualquier arma: **si la variante es "lo mismo pero mas", va porcentaje; si es otro golpe, va estructura.** Cuando una variante agrega algo que la base no tiene, se marca con un flag (`rt_only`, o un `repeat_with_meter` sobre un paso en `repeat = 0`) en vez de duplicar el perfil — un bool es mas barato que un Resource y no se puede desincronizar del base.

Lo que NO entra al modelo porcentual: valores clampeados donde un bono no tiene a donde ir (`fall_scale`), y los perfiles que no le pertenecen al dueno del ataque (el launcher del proyectil). Esos van a mano.

Y ojo con la otra mitad de la regla: **que RT sea un porcentaje no significa que todos los porcentajes de RT vivan en el perfil.** El bono de dano de RT es porcentual igual, pero el dano no es posicion, asi que vive en el tuning del arma junto a las vueltas —el otro knob de RT que tampoco es posicion—. La prueba es `tap adelante + X` en suelo: su perfil esta en `null` porque no mueve a nadie, y meterle el dano lo obligaria a existir solo para llevar un numero. El criterio sigue siendo el tema del Resource, no el tipo de dato. *(2026-07-29)*

[[Espada]] es la referencia implementada de esta organizacion.

## Notas

- El orden de desbloqueo por area vive en [[Areas]].
- La implementacion Godot cubre [[Espada]]; [[Mazo]] esta en desarrollo activo con combos propios sobre `WeaponBase` (E2), pendiente de playtest. *(2026-07-09)*
- No agregar armas nuevas al backlog activo sin moverlas primero a [[hitos]].

## Relacionado

- [[Combate]]
- [[Mover y Floater]]
- [[Areas]]
- [[README]]

