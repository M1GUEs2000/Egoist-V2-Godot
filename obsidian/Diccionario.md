# Diccionario — Egoist V2

Glosario del juego, organizado por **mecánicas madre** (`##`) y sus **sub-mecánicas** (`###`).
Cada entrada resume el término tal como está implementado hoy; la fuente de verdad sigue siendo la
bóveda (`obsidian/`), enlazada entre `[[corchetes]]`.

Las dos mecánicas madre son **Combate** y **Traversal**. Todo lo demás cuelga de una de ellas.

---

# Combate

Cómo el jugador pelea: golpear, romper el aguante del enemigo, castigarlo y sostener el flujo.
Todo el combate gira alrededor del **poise** (el gate) y el **meter** (el recurso).

## Poise

Reserva de aguante que hay que quebrar para stunear. El stun **no** se decide golpe
a golpe: cada ataque suma su `poise_damage` al acumulado del receptor y el stun entra
recién cuando el acumulado alcanza la reserva (`poise_max`). El acumulado decae solo,
así que la presión sostenida quiebra y los golpes espaciados no. Es el **gate de todo
desplazamiento** (`launch`, `push`, `slam`, `slam_bounce`, `slam_arc`): con la reserva
intacta al enemigo no se lo mueve de ninguna forma. Fuente: [[Stun]], [[Combate]].

## Stun

Estado en el que el enemigo queda quebrado. Se gana por poise, no por golpe.
Consecuencia importante: **estar stuneado significa tener el poise ya quebrado** — ya
`STUNNED` no hay reserva que romper, los golpes entran directo y extienden el stun (eso
sostiene el juggle y los combos). El reloj de poise se **congela** durante el stun y en
el aire, así que un enemigo stuneado o lanzado no recupera reserva. Fuente: [[Stun]].

## Armadura

Estado de enemigo (`ARMORED`) que **suma reserva de poise** (`armor_poise_bonus`, +6 por default):
es **resistencia, nunca inmunidad** — un golpe con suficiente poise (el sweet spot del [[Mazo]], 12)
lo quiebra igual de un impacto. **Se rompe por cantidad de golpes** (`armor_hits_to_break`, cuenta
**hits**, no daño ni vida), corriendo en paralelo al medidor de poise. Al romperse vuelve a `NORMAL`
y **pierde el bonus** de poise. Fuente: [[Stun]] › Armadura, [[Armored Enemy]].

> [!warning] La armadura NO se rompe por vida
> `armor_hits_to_break` cuenta **golpes**, no HP ni daño bruto. Son dos medidores independientes
> sobre el mismo golpe: la vida (HP) y la armadura (conteo de hits) van por separado.

## Meter

Recurso de combate medido en **barras** (`PlayerMeter`). **Se gana golpeando** (y más al matar) y
se gasta en acciones especiales:

- **Ataques cargados:** gastan **una barra completa** (el Mazo gasta 1 por nivel de vuelta).
- **Dash:** gasta una **fracción** de barra. **Sin meter el dodge queda degradado**; con barra el
  dodge puede hacer daño.
- **X cargado de la Espada:** recupera una barra si **mata** dentro de una ventana.

Futuro (no implementado): capacidad hasta 5 barras, perfect dodge genera meter, habilidad suprema
con barras llenas. Fuente: [[Meter]], [[Combate]].

> [!note] Precisión sobre el dash y el aire
> La bóveda documenta el gasto del dash como "fracción de barra" y el dodge sin meter como
> "degradado" — **no** como "más i-frames" ni como que el **airdash** cueste meter aparte (la
> disponibilidad del airdash la gobierna el suelo / la kill aérea, ver Reset aéreo por kill).

## Combos

Los ataques se encadenan por **ventanas** definidas (buffer 0.15s, hold threshold 0.18s; tap al
presionar). Hay cuatro cadenas de tap según terreno y rama, más los ataques cargados que bifurcan
aparte. El **tap X/Y usa la misma cadena**; solo el **cargado bifurca por slot**. Fuente:
[[Input Feel]], [[Combate]], [[Espada]], [[Mazo]].

- **Combo normal (terrestre):** cadena de taps seguidos. Espada: `X X X X` (swing, swing, estocada,
  estocada). Mazo: `X X X` (swing, swing, smash AOE).
- **Combo con espera (terrestre):** meter una **pausa** en medio abre una rama distinta. Espada:
  `X X espera X X` (el último golpe empuja). Mazo: `X X espera X X` (la rama espera **agrega 2 smashes
  más**, 5 golpes con AOE). La espera no es solo coreografía: cambia el final del combo.
- **Combo aéreo:** cadena en el aire. Espada: `X X X` (diagonal, diagonal, hacia abajo). Mazo: `X`
  (combo de 2: jab con el mango + cabezazo con knockback). El golpe aéreo **flota solo si conecta**;
  si falla, cae más fuerte.
- **Combo aéreo con espera:** rama con pausa en el aire. Espada: `X espera X X` (la primera vuelta te
  eleva un poco; el empuje final es un arco tuneable). Mazo: no tiene rama espera aérea propia.

## Ataques cargados

Cruzar el hold threshold (0.18s) es carga nivel 1. **Bifurcan por dos ejes: el slot (X o Y) y si
estás aéreo o grounded** — las cuatro combinaciones dan ataques distintos. Los cargados usan
`press_then_charge`: el tap sale en el press y el cargado al soltar. Fuente: [[Input Feel]],
[[Espada]], [[Mazo]].

| | **X cargado** | **Y cargado** |
|---|---|---|
| **Terrestre** | Dash ofensivo que atraviesa y golpea todo (Espada rompe armadura; Mazo da vueltas). | Launcher: eleva enemigos (Espada AOE chico/medio; Mazo paso corto con launcher armado). |
| **Aéreo** | Caída/dash con AOE (ground pound). | Golpe hacia abajo: Espada spikea/rebota al enemigo hasta tu altura; Mazo cae diagonal + AOE cilíndrico (ver rebote vertical). |

- **Niveles de carga:** cada arma decide. La **Espada** ignora niveles (solo tap vs cargado); el
  **Mazo** suma un nivel por cada `charge_level_step` extra hasta `max_charge_level` (1/2/3 vueltas),
  gastando 1 barra de meter por nivel.
- **Sweet spot:** un **efecto extra que se dispara al soltar el cargado en el momento justo** (una
  ventana de timing, **no** el nivel máximo de carga). Ej. Espada X cargado → todo lo tocado explota
  después; Mazo X cargado → congela hasta la última vuelta.
- El nivel se resuelve **al disparar el hold**, no al presionar (para no regalar niveles por buffer).

## Launch

Impulso vertical que sube al enemigo al aire. Corre en `about_to_hit`, **antes** de que
el golpe cobre el poise: por eso **consulta** con `Poise.would_break()` si esa reserva se
va a quebrar, sin consumirla. El launch en sí **no aplica el stun** — lo aplica el golpe
después (en `on_hurtbox_hit`), y como el enemigo ya quedó `AIRBORNE`, ese stun usa la
duración **aérea** (más larga, para el juggle). Resultado neto: launch + golpe deja al
enemigo stuneado flotando, pero el launch no es quien stunea. Solo entra si la reserva ya
está quebrada o el golpe la quiebra ahora. Fuente: [[Launcher y Aire]], [[Stun]].

## Push

Verbo genérico de knockback (`WeaponBase.arm_push`) que empuja lo golpeado, en tierra o
aire, **sin daño propio**. Corre *después* del golpe, así que le alcanza con `is_stunned()`.
Como todo desplazamiento, pasa por el gate de poise: solo mueve si la reserva ya está
quebrada. Un enemigo empujado cae **acostado** y, al tocar el piso, entra en ragdoll físico.
Fuente: [[Combate]], [[Momentum y Bump]], [[Stun]].

## Parry

Contragolpe en la ventana del ataque enemigo. **Hace daño de poise, no de HP**: mete un
monto alto de poise según arma y tipo de ataque (`parry_poise_normal` 6–8, `charged_x` 9–12,
`charged_y` 12–16 — el cargado Y quiebra incluso a un armado de un solo parry). Si quiebra la
reserva → estado **vulnerable cian** + stun 1.5s + daño ×2; si no alcanza, fogonazo blanco.
El parry de **proyectil** es cosa aparte: es un *deflect* (da vuelta el tiro contra quien lo
disparó), no abre el estado cian. Fuente: [[Combate]], [[Stun]] › Parry.

## Verbos de combate

Piezas finas que los ataques arman por duck typing. Se dividen en dos grupos: los que **recibe el
enemigo** (desplazamientos, gateados por poise: solo entran si ya está quebrado) y los que **usa el
jugador** (control aéreo propio). Fuente: `enemies/enemy_base.gd`, `player/`.

**Que recibe el enemigo (`EnemyBase`):**

- **`slam`** — baja al enemigo en seco (`velocity.y = -down_speed`), cancelando el hang del aire.
  Solo si está stuneado y aéreo. Es la base de los dos rebotes de abajo.
- **`slam_bounce`** — **rebote vertical**: el enemigo baja y, al tocar el piso, **sube a una altura
  objetivo** (típicamente *tu* altura) con hang. Lo usa el **Y cargado aéreo de la [[Espada]]**
  (spike + rebote hasta tu altura para seguir el combo).
- **`slam_arc`** — **pique balístico**: baja y, al tocar el piso, **pica en un arco propio** (up +
  forward + su gravedad) en una dirección, **sin atarse a una altura** (no vuelve a tu nivel). Lo usa
  el **Y cargado aéreo del [[Mazo]]** (ver rebote vertical).

**Que usa el jugador (`Player`):**

- **`hover`** — **hang propio de un move**: frena la caída en seco y sostiene al jugador una duración
  **exacta**, independiente del contador de combo. **No gasta el doble salto** (la ventana existe
  justo para que lo uses). Lo arma el Y cargado aéreo del Mazo al conectar.
- **`attack_step`** — **lunge**: cada golpe encara la dirección de ataque (target lockeado si hay, si
  no el forward) y **avanza un poco** durante el golpe (`attack_step_distance`). Es lo que "pega" al
  jugador al enemigo mientras combea, en tierra o aire.
- **`air stall`** (air-hit-stall) — cuando un golpe aéreo **conecta**, congela la caída y sostiene al
  jugador un tiempo que **crece con la cadena** de golpes (más golpes seguidos = más flote, hasta un
  tope). Distinto del `hover`: el hover es un tiempo fijo por move; el air stall escala con el combo.
  Preserva una subida chica (ej. el hop de la rama espera) para no matar el impulso vertical.

## Rebote vertical (Y cargado aéreo del Mazo)

Rebote del **jugador** que dispara el **Y cargado aéreo del [[Mazo]]**. El ataque es una caída
diagonal (`air_y_fall_angle` / `air_y_fall_speed`) que al impactar estalla un AOE cilíndrico
(`AirSlamHitbox`) una sola vez. El resultado depende de contra qué impacta:

- **Contra el suelo** (sin enemigo en el aire): estalla el AOE, los enemigos de adentro salen por
  launcher vertical, y el jugador **no rebota** — se planta donde cae.
- **Contra un enemigo en el aire:** el jugador **rebota** arriba-y-adelante en su dirección, a un
  ángulo fijo (`air_y_bounce_angle`, 45° = diagonal) y velocidad propia (`air_y_bounce_speed`),
  **sin gastar el doble salto** — esa es la ventana para perseguir. Los enemigos clavados hacen un
  pique balístico (`slam_arc`): se clavan al suelo y rebotan en arco en tu dirección, stuneados
  todo el arco, con ragdoll al aterrizar (no vuelven a tu altura). Fuente: [[Mazo]], [[Combate]].

## Ragdoll

Representación física (RigidBody cápsula) en la que cae un enemigo empujado (`push`) o
stuneado en el aire al tocar el piso: rueda y se para en ~0.5s. **Siempre sale de un stun o un
push**, y ambos ya quebraron la reserva — por eso el ragdoll es, por definición, un **estado sin
poise** (quebrado). Cuenta como quebrado en todos los gates: `_breaks_poise`, `try_apply_stun` y la
pausa del poise tratan `_ragdolling` igual que `is_stunned()`. Consecuencia: **se lo puede juggle** —
un `launch` sobre un ragdoll lo **interrumpe** (`_interrupt_ragdoll`), el cuerpo vuelve a `STUNNED` y
sale volando de nuevo; el stun del mismo golpe entra directo y sostiene el juggle. Un golpe sin
launcher solo extiende el timer y lo mantiene caído (el daño siempre entra). Fuente: [[Stun]].

## Lock-on

Fijado de objetivo tipo Dark Souls. **No es automático: hay que presionar el botón dedicado
(tecla `C`, `toggle_lock`) para que funcione** — ancla al enemigo más centrado en cámara (dentro del
cono horizontal/vertical y el rango) y lo mantiene como target persistente, sin recalcularlo cada
frame. Se suelta con el mismo botón, o si el target muere o sale de rango. Con lock activo, `Q`/`E`
dejan de rotar la cámara y **ciclan entre targets** en rango; la cámara pasa a encuadrar a jugador +
target. El retículo muestra una **dona que se vacía con la vida del target** en tiempo real. El
filtro es 3D (rango real + cono vertical), pensado también para enemigos aéreos. Fuente: [[Lock On]].

---

# Traversal

Cómo el jugador se mueve por el mundo: dash, paredes, suelos resbaladizos, rebotes y momentum.
El eje compartido es el **momentum** (`bump_velocity`): casi todo suma o reemplaza ese exceso.

## Momentum / bump

`bump_velocity` es el **exceso horizontal** del jugador: velocidad extra que se **suma encima** de la
locomoción normal (`move_speed`), no otro motor. El exceso se **drena linealmente** y la velocidad de
drenaje depende del apoyo: **suelo** ×1.0, **pared** ×0.5, **aire** ×0.1 (en el aire casi no frena, por
eso el momentum aéreo se conserva). Llevarlo a cero deja al jugador exactamente en `move_speed`, nunca
por debajo. `add_momentum()` compone impulsos, `set_momentum()` reemplaza el exceso; ambos clampeados a
`momentum_max_speed`. Fuentes que lo alimentan: bloques Launch, wall jump, rebote en enemigo, dash con
boost y spike wall. El stun `PUSH` está **aislado** (drena con `stun_bump_decay`) para que recibir un
golpe no sea una fuente de traversal. Fuente: [[Momentum y Bump]].

## Dash

Impulso rápido en una **dirección específica** (`PlayerDash`), en suelo o aire (airdash).
Tiene dos sabores según el flag `pass_through_enemies`:

- **Dodge (defensivo):** choca con enemigos y objetos, no los traspasa. Tiene **i-frames**
  (`dodge_iframe_duration`): mientras dura no puede ser stuneado. Con barra puede hacer daño,
  pero **no aplica stun** (el stun del dash normal es 0 en suelo y aire).
- **Ofensivo (`force_dash`, ej. el X cargado de la espada):** **atraviesa** enemigos (quita la
  capa `enemy` del `collision_mask`) y choca con objetos. **No** tiene i-frames.

Por defecto el dash **no cambia de mundo**; solo dispara world switch si una maldición/bonus lo
modificó. Consume/restaura airdash según la acción, y su boost pasa por `set_momentum()` (respeta
`momentum_max_speed`). Fuente: [[Dash y Airdash]], [[Stun]] › I-frames del dodge.

## Wall slide

Estado **sostenido** contra una pared: te enganchás con momentum suficiente y caés controlado,
trazando un arco por gravedad reducida. El módulo (`PlayerWallSlide`) es **dueño del horizontal**
mientras estás pegado. Requiere una superficie lo bastante grande para deslizar. Fuente:
[[Wall Slide y Wall Jump]].

## Wall jump

Impulso **instantáneo** reflejado en la pared (componente hacia el muro invertida + lateral
conservada + empuje hacia arriba). **No consume el doble salto** y la pared no lo recarga.
Es pariente cercano del rebote en enemigo (misma familia de impulso reflejado), pero **no** es
lo mismo que el wall slide: el slide es un estado continuo, el wall jump es un solo impulso.
Fuente: [[Wall Slide y Wall Jump]].

## Rebote en enemigo (enemy jump)

Rebote **manual**: el jugador pide salto en una ventana breve tras tocar físicamente al enemigo.
La superficie del enemigo *"es demasiado chica para slidear, se lee como impulso instantáneo"* —
por eso el enemigo tiene rebote pero **no** wall slide. Mecánicamente es casi el mismo impulso que
el wall jump (away + along + up, no consume doble salto). La reacción del enemigo es un `push`
**sin poise propio**, así que rebotar sobre él no lo desplaza salvo que ya esté stuneado. Fuente:
[[Rebote en Enemigos]].

> Nota: wall jump y rebote en enemigo son la **misma familia** (impulso reflejado desde una
> superficie), pero viven en módulos distintos (`PlayerWallSlide` vs `PlayerEnemyBounce`) y el
> wall **slide** es otra cosa (estado sostenido, no impulso).

## Floor slide

Deslizamiento de suelo **por plataforma** (`PlayerFloorSlide`): una plataforma marcada con
`FloorSlideSurface` + su `.tres` permite deslizar. Es el **hermano del wall slide** — usa los
mismos principios: es dueño del horizontal mientras desliza, engancha por umbral de velocidad,
tiene `steer_control` recortado y al salir vuelca el exceso a `bump_velocity`. Estado **E0**:
recién construido, **aún no probado** (headless/probe pendientes, feel desconocido). Fuente:
[[Floor Slide]].

## Reset aéreo por kill

Puente combate↔traversal (`AirKillReset`): si el jugador **mata estando en el aire**, resetea sus
recursos aéreos — **doble salto** (`restore_double_jump`), **airdash** (`restore_airdash`) y la
secuencia de reducción de caída por cargas. Es lo que sostiene perseguir enemigos por el aire.
El **doble salto es un solo salto extra** — matar no lo apila, solo lo devuelve. Aparte, empezar a
cargar un ataque en el aire reduce solo la caída vertical negativa (100% → 80% → 50% → 10% por uso
en la misma vida aérea), sin tocar el momentum horizontal. Fuente: [[Reset Aereo por Kill]].

## Bloques de traversal

Objetos golpeables de traversal. El principal es el **`TraversalBlock`** componible: una sola escena
que activa una o varias características por exports, y **cada característica se identifica por color**.
El cuerpo se divide en partes iguales según cuántas features tenga (mitades, tercios, cuartos). Los
colores viven en `World` (no en la escena) y nunca reusan un color de mundo. Fuente: [[Bloques]],
[[Colores de mundo]].

### Bloques por color

| Color | Efecto | Estado |
|---|---|---|
| **Verde** | **Dash** en una dirección específica, fija por la cara **-Z local del bloque** (rotar el bloque cambia el rumbo), marcada por una **flecha verde** semitransparente. Al terminar da un bop corto adelante+arriba; daña al atravesar enemigos. | Implementado (E3) |
| **Rojo** | **Launch / bump**: suma momentum horizontal + bump vertical + restaura doble salto y airdash. | Implementado |
| **Celeste** | **Meter**: suma barras de meter al jugador. | Implementado |
| **Amarillo** | **Maldición**: al romperse, la **próxima acción** cambia de mundo (no cambia al instante). | Implementado |
| **Color del mundo destino** | **World switch**: cambia de mundo al golpearlo. **No tiene color fijo** — se ve morado desde el mundo vivo (manda al muerto) y naranja desde el muerto (manda al vivo). | Implementado |
| **Blanco** | **Curación**: te cura. | ❌ **No existe** hoy en la bóveda. |
| **Negro** | Uno de los efectos anteriores, **aleatorio**. | ❌ **No existe**: pendiente en [[ideas]]. |

> [!warning] Diferencias con la descripción de diseño
> - El **rumbo direccional** (flecha) es del **verde (dash)**, no del rojo. El rojo (launch) empuja
>   por momentum, no por dirección fija.
> - **Morado/rosado no es un color propio del world switch**: el switch se pinta con el color del
>   mundo destino (morado solo cuando se lo mira desde el mundo vivo).
> - **Blanco (cura)** y **negro (aleatorio)** todavía **no están implementados** — negro figura como
>   idea, el bloque de cura ni siquiera está listado.

Otros bloques: **Breakable wall** (`BreakOnDeath` + `Health`, desaparece al romperse) y **Spike wall**
(`SpikeWall`: stun PUSH rojo + rebote, restaura doble salto y airdash, existe en los dos mundos).

---

# Mundos duales

La mecánica central de Egoist: dos mundos superpuestos (**vivo** y **muerto**) que se intercambian.
Casi todo objeto del juego declara en cuál existe, y cambiar de mundo altera qué es sólido, qué te
puede pegar y qué se ve.

## World switch

Cambiar entre el mundo vivo y el muerto. **Decisión de diseño V2: no es dodge gratis** — se gana por
**triggers**:

- **Bloque** con world switch (OnHit): al golpearlo, brilla con el color del mundo destino.
- **Enemigo** OnDeath (`world_switch_enemy.tscn`): matarlo voltea el mundo — el switch que se gana
  **peleando**. Aguanta más y cuesta más stunearlo (`poise_max = 12`): el cambio se paga.
- **Proyectil** enemigo con flag (`world_switch_on_player_hit`): si te pega, cambia el mundo además
  del daño.
- **[[Grieta]]**: puerta temporal de un solo uso; cruzarla voltea el mundo — el switch que se gana
  **llegando**, no peleando. El enemigo la abre pero no cambia el mundo de nadie: **el jugador decide**.
- **Maldición amarilla** (próxima acción) y **botón/HUD** o especiales futuros.

El switch **no es instantáneo en el espacio**: sale una **onda** (`WorldScan`) desde el origen que lo
disparó y el mundo destino aparece **barrido por el frente** (retardo = distancia / velocidad). Fuente:
[[World Switch]], [[Colores de mundo]].

## World membership

`WorldMembership` es el módulo que decide **si un objeto está activo en el mundo actual**. Todo enemigo,
plataforma, bloque o estructura lo compone. Cuatro modos de **afiliación**:

| Modo | Qué hace |
|---|---|
| `FIXED` | Existe solo en un mundo (vivo o muerto). |
| `BOTH` | Activo en ambos — no se le escapa cambiando. |
| `TIMED` | Alterna su afiliación cada `shift_interval`. |
| `FOLLOWS` | Sigue el mundo actual del jugador (con posible delay). |

Lo que está **en el mundo opuesto ya no desaparece**: deja de ser sólido (apaga colisión, no
visibilidad) y se lee en dos capas — una **cáscara** con el contorno encendido que **late**, más
**humo** y **afterimages** (estela) con el color de su afiliación (**naranja** vivo, **morado** muerto),
cuyo brillo crece con la velocidad. `BOTH` y `FOLLOWS` nunca muestran esto (nunca están fuera de mundo).
Al reactivarse, `EnemyBase` sincroniza `collision_layer`, visual y `hurtbox.monitorable`. Fuente:
[[Afiliacion de Mundo]], [[World Switch]].

## Grieta

Una **puerta temporal** al otro mundo (`WorldRift`): se abre donde algo cruzó, queda un rato abierta
y **cruzarla voltea el mundo de todos**. Es una fuente de world switch más, pero con personalidad
propia: **no se gana golpeando ni matando, se gana llegando a tiempo** — pone un reloj en pantalla.
Es de **un solo uso**: se cierra apenas alguien la atraviesa (aunque le sobrara ventana), y solo la
cruza el **jugador** (los enemigos la ignoran). Si nadie llega, se cierra sola al vencer `lifetime`
**sin cambiar nada**, avisando con un parpadeo en los últimos segundos. Lleva el color del **mundo
destino**. Cualquier sistema puede abrirla vía `WorldRift.spawn()`; **hoy la deja un enemigo** —
el **enemigo de la grieta** (`rift_enemy.tscn`), que al recibir el **primer golpe** arranca su reloj
y, al cumplirse, se va al otro mundo dejando la grieta donde estaba (irse **no** cambia el mundo de
nadie: solo lo hace el jugador cruzando). Fuente: [[Grieta]], [[World Switch]].

---

# Enemigos

Qué **son** los enemigos (identidad, cómo están armados y cómo se los golpea). Cómo **piensan y se
mueven** es la IA, que va aparte. La regla de oro: variedad por **composición y datos**, no por una
subclase nueva por cada enemigo.

## Modelo componible

No hay una subclase por comportamiento: hay piezas que se enchufan. `EnemyBase` (salud, estados,
armadura, mundo, verbos aéreos, muerte) + `GroundedEnemy` (glue: decisión, target, locomoción,
ataques) + `Health` + `Hurtbox` + `WorldMembership` + `Perception` + `GroundLocomotion` + ataques
componibles. **Con qué pega** lo elige `AttackLoadout` (solo melee, solo ranged o híbrido), sin script
propio. Los verbos aéreos (`launch`, `slam`, `push`, `slam_bounce`, `slam_arc`, `try_parry`,
`receive_stun`) se llaman por **duck typing**. Un enemigo también es **terreno de traversal** (se puede
rebotar desde su colisión). Fuente: [[Modelo de Enemigo]], [[Enemigos]].

## Hostilidad

Define **la intención** del enemigo: quién inicia combate y cuándo huye. Cuatro niveles:

- **`PASSIVE`** — no inicia por ver al jugador; si lo atacan puede reaccionar. Su SEARCH es curiosidad.
- **`REACTIVE`** — defiende territorio: ataca si invadís su zona.
- **`AGGRESSIVE`** — inicia contra el jugador, pasivos, reactivos y ultras; **nunca daña a otro
  agresivo**.
- **`ULTRA_AGGRESSIVE`** — berserker: ataca cualquier objetivo válido (incluidos otros enemigos) y
  cambia a uno mejor si aparece. No huye ni se esconde.

La **memoria del target** crece con la hostilidad (pasivo 10s → ultra 60s). La **huida** (`FLEE`) es una
tirada única al cruzar el 30% de vida, con chance decreciente (pasivo 0.50 → ultra 0.0). Hay una tabla
de **quién puede dañar a quién** (los agresivos inician los conflictos; el ultra no tiene aliados).
Fuente: [[Hostilidad]].

## Estados de combate

Estados mecánicos compartidos por cualquier enemigo (`combat_state`):

- **`NORMAL`** — actúa y recibe daño normal.
- **`ARMORED`** — no se parrea; suma reserva de poise (resistencia, no inmunidad).
- **`STUNNED`** — IA congelada; entra al **quebrarse la reserva de poise**.
- **`AIRBORNE`** — en el aire por launcher/push/slam/bounce; **solo se llega con la reserva quebrada**.
- **Parry vulnerable** — no es un estado aparte: un temporizador celeste que se solapa al stun (daño ×2).
- **Dead** — muere, puede disparar `WorldSwitchTrigger.ON_DEATH`.

Fuente: [[Estados de Combate Enemigo]], [[Stun]].

## IA (percepción y decisión)

Cómo piensan y se mueven, sobre **LimboAI** (BT + HSM). **Nadie es omnisciente**: toda detección pasa
por `Perception` (rango de visión + ángulo + raycast contra el mundo) y guarda la última posición
conocida. La decisión **emite un intent** y la locomoción (`GroundLocomotion`) lo ejecuta: chase, roam,
search, huida, espaciado de combate (backpedal + strafe) y salto de esquive (evade). Un enemigo **fuera
del mundo del jugador no se congela** — sigue simulando y moviéndose (es lo que se ve tras la cáscara),
pero **no pelea** (su target es `null`, su hurtbox no es monitorable). Fuente: [[IA]], [[Hostilidad]].

### Estados de la IA (`AIState`)

Catálogo de 15 estados; cada enemigo habilita los suyos con `allowed_state_flags`. **12 tienen
comportamiento real**; 3 son solo enum sin hoja que los produzca. Cada estado vive en una capa:
**decide** (qué hacer), **steer** (cómo moverse) o **coord** (multi-agente). Fuente: [[Comportamientos]].

**Implementados (12):**

| Estado | Capa | Qué hace |
|---|---|---|
| `IDLE` | decide | Quieto; fallback final si ningún otro estado es legal. |
| `ROAM` | steer | Patrulla alrededor del spawn (radio y tiempos aleatorios). |
| `ACTIVITY` | decide | Actividad idle propia (dormir, comer presas); cae a roam/stop. |
| `ALERT` | decide | Beat de reacción al pasar de no ver a ver al target, antes de perseguir. |
| `CHASE` | steer | Persigue al target en línea recta. |
| `GUARD` | decide | Se queda quieto en su posición (fallback del reactivo sin target). |
| `SEARCH` | steer | Va a la última posición conocida mientras dure la memoria. |
| `ATTACK_MELEE` | decide | Combo cuerpo a cuerpo con ventana de parry. |
| `ATTACK_RANGED` | decide | Windup + dispara proyectil con homing. |
| `FLEE` | steer | Se aleja del target (tirada única al cruzar 30% de vida). |
| `HIDE` | decide | Se esconde quieto; solo tras un `FLEE` exitoso y fuera de vista. |
| `EVADE` | steer | Se espacia orbitando y **esquiva reactivamente** el telegraph del player. |

**Solo catálogo, sin comportamiento (3):** `CALL_HELP` (pedir refuerzos, H2), `DEFEND` (postura
defensiva, H2), `ATTACK_GROUP` (ataque coordinado, pide un director, H3+).

## Máscaras y cordura

Los enemigos son **portadores de máscaras rotas**: el estado de la máscara **indica su cordura**, y la
cordura mapea a la hostilidad. Tres estados:

- **Sane** — máscara completa o casi: pasivo o reactivo, no ataca si no se lo provoca.
- **Not so sane** — máscara deteriorada: busca, reacciona, puede perseguir.
- **Insane** — máscara muy rota: ataca a todo, incluidos otros enemigos.

Mapeo aproximado: Sane → `PASSIVE`/`REACTIVE`, Not so sane → `REACTIVE`/`AGGRESSIVE`, Insane →
`ULTRA_AGGRESSIVE`. En **H2** puede volverse un sistema **dinámico** de locura (la máscara se rompe y
la hostilidad escala en niveles). Hoy es más lore/identidad que sistema. Fuente: [[Mascaras y Cordura]],
[[Hostilidad]].

---

# Brazo

Habilidad **permanente** del jugador (puño remoto, `PlayerArm`). **No es un arma** ni ocupa los slots
X/Y: vive encima del loadout, siempre disponible tenga el arma que tenga. Un tap (`arm_attack`) con
dos usos según el target de su **propio lock-on pasivo** (marca hacia dónde mirás, sin arrastrar al
jugador):

- **Combate**: pega al target del lock-on pasivo (lockeado si hay uno, si no el más centrado en el
  cono de mira). Daño/poise bajos, meter propio; 5 taps seguidos + cooldown de 3s.
- **Traversal**: si no hay enemigo en el cono, marca el bloque de dash **verde** más cercano en su
  propio cono/rango y, al tap, empuja al jugador hacia él con un dash forzado y lo activa al llegar
  (mismo efecto que golpearlo). Gratis, con su propio cooldown corto (1s). Solo bloques de dash por
  ahora — agarres/objetos genéricos de traversal siguen sin implementar.

Entró en H1, adelantado respecto al roadmap original (H2). Nace como sistema propio del player, no
como `WeaponBase`. Estado **E2**. Fuente: [[Brazo]], [[brazo-combate|Brazo Combate]],
[[brazo-traversal|Brazo Traversal]].

---

# Cámara

Cámara **isométrica** que sigue al jugador con damping, más **rotación horizontal libre por stick**
(`CameraRig`). El follow calcula la posición por `pitch`/`center_yaw`/`distance` sobre el target y
suaviza con `damping`. La rotación (stick derecho, o `Q`/`E`) gira el yaw **360° sin clamp** a
`yaw_speed` grados/seg y se queda donde el jugador la dejó — **no hay recentrado automático**. Sigue
al target en Y solo hasta un tope (`vertical_follow_limit`); pasado eso se congela y el jugador sale
de cuadro en vertical (pensado para subidas bruscas con launcher/Brazo). Con **lock-on** activo el
yaw se congela en el que ya tenía (no orbita a la espalda del jugador) y la distancia hace zoom
in/out según la separación jugador-target (`lock_zoom_*`) — ver [[Lock On]]. El **occlusion fade**
es sistema aparte (vive en Traversal). Pendiente: "centro por área" (que `center_yaw` cambie según
la zona). Fuente: [[Camara]], [[Occlusion Fade de Camara]], [[Lock On]].

---

# Relaciones rápidas

- **stun ⇒ poise quebrado** — estar stuneado/launcheado/pusheado *implica* reserva quebrada,
  no que "no puedan tener poise".
- **launch ≠ aplicar stun** — el launch *consulta* el poise; el stun lo aplica el golpe.
- **wall jump ≈ rebote en enemigo** — misma familia (impulso reflejado), módulos distintos.
- **floor slide ≈ wall slide** — mismos principios, superficie distinta (suelo vs pared).
- **parry ⇒ poise, no HP** — mete poise alto; si quiebra, vulnerable cian.
- **ragdoll ⇒ estado sin poise** — siempre viene de stun/push (ya quebrados); por eso se lo
  puede launchear/juggle.
- **rebote vertical = Y cargado aéreo del Mazo** — solo rebota al jugador si clava a un enemigo
  **en el aire**; contra el suelo solo estalla el AOE.
