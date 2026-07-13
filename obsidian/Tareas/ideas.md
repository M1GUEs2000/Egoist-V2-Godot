---
title: Ideas
tags:
  - egoist
  - ideas
status: active
---

# Ideas

Ideas **potenciales**, no comprometidas: pueden no entrar al juego. Lo que ya esta decidido y falta hacer NO vive aca — eso es una subtarea del kanban ([[tareas]]).

## Ideas potenciales

| Idea | Nodo | Detalle |
|---|---|---|
| Bloques dañinos | [[Bloques]] | Colores de `TraversalBlock` que le hagan **daño** al jugador al tocarlos, en vez de darle un beneficio. Hoy toda caracteristica del bloque es a favor del jugador; lo unico que lo castiga es la spike wall, que no es un `TraversalBlock`. Sin color ni efecto definidos. |
| El color negro es un efecto oculto | [[Bloques]] | El efecto todavia no esta definido. No existe como caracteristica; el negro que se ve hoy es el cuerpo de la spike wall. |
| [[Brazo]] | [[Brazo]] | Habilidad permanente, no arma de slot. Puño remoto con lock-on pasivo: en combate mantiene enemigos en aire y da respiro; en traversal agarra cosas/puntos como pseudo checkpoint. Tap/carga, costo de meter y limites por definir. |
| Lock-on de marcado | [[Brazo]] | Lock-on pasivo del brazo: marca hacia donde mira/apunta el jugador, pero **no acerca** al jugador ni alimenta `attack_step`. Existe para que el brazo pegue o agarre lo marcado. |
| Combo aereo de las [[Dagas]] `X X espera X X` | [[Dagas]] | Sube al enemigo **mas alto de lo que esta el jugador**, no solo un poco. |
| Mundo Muerto como riesgo/recompensa | [[World Switch]], [[Hostilidad]], [[Afiliacion de Mundo]] | Hoy el world switch es un gate mecanico neutro. Idea: el mundo Muerto pasa a ser una zona de alto riesgo/alta recompensa — casi todo enemigo ahi es Agresivo/Ultra Agresivo (90%), terreno mas hostil, mas trampas, mejores power-ups y meter concentrados ahi. El objetivo es que el jugador quiera entrar, agarrar lo que busca y salir lo antes posible (frenetico), no quedarse a explorar tranquilo. Curva de dificultad: el Muerto del inicio del juego no es igual de duro que el Muerto avanzado. |
| Cura por golpear enemigos con mascara, escasa en el Mundo Muerto | [[World Switch]], [[Combate]], [[Mascaras y Cordura]] | La cura no es un porcentaje generico al pegar: la fuente es golpear enemigos que **tienen mascara** (ver [[Mascaras y Cordura]]). En el Mundo Muerto hay menos cura no porque se reduzca un multiplicador, sino porque hay **menos enemigos con mascara** ahi (la mascara mas rota/Insane se concentra en el Muerto, ver la tabla Sane/Not so sane/Insane -> Hostilidad). Refuerza las ganas de salir rapido sin un timer invisible: el jugador ve directamente que hay menos fuentes de cura alrededor, no un numero que baja. El meter (ataques/movimiento) nunca cura — son dos recursos separados a proposito. |
| Jefes que fuerzan el world switch como su gimmick | [[Jefes]], [[World Switch]] | Lo que vuelve "jefe" a un jefe: puede teletransportar al mundo Muerto a todo lo que esta cerca suyo (jugador y enemigos), como escalado de `WorldSwitchTrigger`/el enemigo de world switch a radio de arena en vez de un solo enemigo. Sube la apuesta justo cuando mas importa (menos cura, mas peligro en medio de la pelea del jefe); necesita telegraph claro para que el jugador lo vea venir y no se sienta un golpe injusto. |
| Enemigo con proyectil de world switch | [[World Switch]], [[Ataques Enemigos]] | Quinto trigger de cambio de mundo, a distancia: un enemigo (probable variante de `RangedAttack`/`Projectile`) que dispara un proyectil que, al impactar, cambia el mundo — a diferencia de los triggers actuales (bloque, enemigo OnDeath, maldicion), este obligaria al jugador a esquivar o interceptar el proyectil en vez de decidir cuando golpear un bloque. Sin definir: si afecta solo al jugador o area, cooldown, telegraph del disparo. |
| Bloque/enemigo negro con efecto aleatorio | [[Bloques]] | Extiende la idea vieja "el color negro es un efecto oculto" (hoy sin definir, solo bloques): que el negro no sea un efecto fijo sino **aleatorio** cada vez que se activa, y que exista tambien como variante de enemigo, no solo de bloque. Sin definir: que efectos entran en el pool aleatorio, si puede tocar world switch, y si la aleatoriedad es par el jugador (sorpresa) o tambien afecta al balance de riesgo/recompensa del Mundo Muerto. |
| Salvavidas sistemico si el RNG negro no saca al jugador del Mundo Muerto | [[Bloques]], [[Ecosistema Vivo]], [[Ultra Agresivo]] | Si el resultado aleatorio del bloque negro NO es "cambia de mundo", el castigo no deberia ser solo "mala suerte y ya" — el bloque explota y vuelve Ultra Agresivos a todos los enemigos de la sala. El jugador sigue sin poder salir, pero el caos resultante (los enemigos se atacan entre si, ver [[Ecosistema Vivo]]) le da una ventana real para escapar corriendo en vez de pelear. Convierte un fallo de RNG en una segunda oportunidad jugable, no en un muro. |
| Mejoras permanentes por matar Ultra Agresivos o enemigos sin mascara | [[Ultra Agresivo]], [[Mascaras y Cordura]] | Matar a un Ultra Agresivo o a un enemigo "sin mascara" (mascara totalmente rota/perdida, ver [[Mascaras y Cordura]]) otorga una mejora permanente de vida maxima o de daño. Le da una razon extra para arriesgarse a pelear a los enemigos mas peligrosos del Mundo Muerto, no solo por el loot que sueltan. Sin definir: tasa de drop, si es aleatorio vida/daño o elegible, y si escala con la curva de dificultad del Mundo Muerto. |
| Indicadores de proyectiles fuera de pantalla | [[Ataques Enemigos]], [[Combate]] | Si un proyectil enemigo (incluido el propuesto "enemigo con proyectil de world switch") viene desde fuera del encuadre de camara, mostrar un indicador en el borde de pantalla que avise direccion/origen. Evita que el jugador reciba un golpe (o un cambio de mundo forzado) que nunca pudo ver venir — telegraph a nivel de UI en vez de solo en el mundo 3D. |
| Mas meter por golpe en el Mundo Muerto | [[World Switch]], [[Meter]] | Companero de "cura escasa en el Mundo Muerto": ahi hay menos fuentes de cura (menos enemigos con mascara) pero pegar **da mas meter por golpe**. El meter solo paga ataques y movimiento (nunca cura, son recursos separados a proposito), asi que el trade-off es limpio: "pegar = sobrevivir" (via cura, escasa ahi) contra "pegar = poder" (via meter, mas generoso ahi). El jugador entra sabiendo que va a salir mas raspado de vida pero mas cargado de meter para ofensiva/movilidad. Sin definir: el multiplicador exacto, y si aplica a todo golpe o solo a ciertos combos/armas. |

## Tensiones a resolver si estas ideas entran

- **El brazo no es un arma de slot X/Y.** El roster de V2 esta congelado en [[Espada]], [[Mazo]], [[Dagas]] y [[Punos]], y [[Arquitectura Godot]] prohibe explicitamente Capa, Guantes, Ruedarang y Latigo. Si el brazo entra, entra como habilidad permanente del jugador, no como `WeaponBase`.
- **El lock-on del brazo debe ser separado del lock-on de combos.** El acercamiento lo hace `PlayerLocomotion.attack_step` durante golpes de arma. El brazo necesita marcar pasivamente sin disparar ese avance.
- **El combo de las Dagas contradice su propia tabla.** Su fila aerea de hoy describe la rama espera como `X espera X` → "empuja hacia abajo a los enemigos con mayor AOE, 1 vuelta, 1 corte en X". Si la idea entra, cambia la cantidad de taps y la direccion del efecto.
- **El Muerto como riesgo/recompensa choca con la regla madre del world switch por triggers ganados.** Si el jugador puede evitarlo, el loot fuerte ahi debe ser opcional, no bloquear progreso — si es obligatorio para avanzar, deja de ser "arriesgarse a entrar" y vuelve a ser el gate neutro de hoy. El jefe que teletransporta a todos los cercanos ademas arrastra enemigos junto con el jugador: interactua con [[Ecosistema Vivo]] (infighting en medio de la pelea de jefe) y falta decidir si eso ayuda o estorba al jugador.
- **Cura escasa + mas meter son recursos separados a proposito, pero comparten la misma fuente (pegar).** El meter nunca cura (solo paga ataques/movimiento), asi que no se anulan entre si. Lo que si falta definir: si "menos enemigos con mascara" en el Mundo Muerto tambien implica MENOS enemigos en total ahi (mas dificil generar meter tambien) o si los enemigos sin mascara siguen dando meter normal al golpearlos — de eso depende si el Mundo Muerto realmente es "mas meter" en la practica o solo "mas meter por enemigo golpeado".

## Relacionado

- [[tareas]]
- [[hitos]]
- [[Metodologia V2]]
