class_name AttackStep extends Resource
## UN golpe dentro de una secuencia: que animacion lo dibuja, cuanto pega, y que le hace a la
## posicion de los cuerpos. Es la unidad que reemplaza a la coreografia hardcodeada de cada arma
## (Sword._play_combo_step, Sword.play_air_step) y a las "vueltas" contadas con un int.
##
## Cada paso abre y cierra SU PROPIA ventana de dano. Ese es el cambio de fondo: hasta ahora una
## cadena de N golpes abria UNA sola ventana estirada sobre todos, asi que el enemigo cobraba una
## vez aunque vieras cuatro impactos (el tap adelante + X ya salia con dos vueltas y un solo golpe).
## Con un paso por golpe, N pasos son N impactos, N register_hit y N aplicaciones de stun.
##
## Ver data/attack_sequence.gd para como se encadenan y como ramifican por espera.

## El tramo de animacion que dibuja este golpe y define cuando abre el hitbox. Ver
## data/attack_clip.gd (contrato compartido con el modulo de animacion). null = el paso no dibuja
## nada y dura lo que diga la secuencia; sirve para pasos puramente mecanicos.
@export var clip: AttackClip

## Abre el hitbox vertical propio del arma en vez de hoja/disco. El arma resuelve cual es ese
## hitbox; el runner conserva el mismo AttackClip y AttackMovementProfile, de modo que un launcher
## sigue siendo un paso declarativo de AttackSequence.
@export var uses_vertical_hitbox := false

## Multiplicador de dano de ESTE paso sobre el dano base del arma. Existe porque partir una cadena
## en N impactos multiplica el dano por N sin tocar un solo numero: un flurry de tres suele querer
## 1.0 / 0.6 / 0.6 y no 3x plano. 1.0 = el dano de lista del arma.
@export_range(0.0, 4.0, 0.05) var damage_scale := 1.0

## El stun de ESTE golpe: cuanto poise come y cuanto congela si quiebra. null = usa el del arma
## (WeaponTuning.stun), que es lo que hacian todos los golpes hasta ahora.
##
## Existe porque "un paso = un golpe" tambien multiplico el stun: los cuatro golpes del combo
## terrestre de la Espada comen 6 de poise CADA UNO, asi que la cadena mete 24 y no hay progresion
## posible — el primer swing quiebra igual que el finisher.
##
## NO va en `movement`: ese Resource es lo que el golpe le hace a la POSICION, y un stun no mueve a
## nadie. Mismo criterio por el que el bono de dano de RT vive en el tuning del arma.
##
## Es un StunSettings entero y no un multiplicador porque el control que hace falta no es solo
## "cuanto": un golpe aereo suele querer `airborne` en 0 para que al enemigo lo sostenga el Floater
## en vez de congelarlo, y eso no se expresa escalando un numero.
##
## OJO CON APAGARLO EN GOLPES AEREOS: el Floater del Enemy tiene un gate de poise QUEBRADO (ver
## EnemyBase.request_float). `airborne` en 0 esta bien —el golpe sigue quebrando y el hang entra
## igual, solo que sin congelar—, pero `poise_damage` en 0 deja al enemigo sin quiebre, y entonces
## el Floater no lo sostiene y el juggle aereo se cae. Si un golpe aereo no tiene que stunear, se
## baja `airborne`, nunca `poise_damage`.
@export var stun: StunSettings

## Que le hace este paso a la posicion de los cuerpos. Ver data/attack_movement_profile.gd. Es lo
## que permite decir "el Mover sale en el tercer golpe" desde el inspector: antes el beat de la
## cadena en el que salia un recorrido era codigo, porque un perfil por gesto no podia expresarlo.
## null = este paso no mueve a nadie.
@export var movement: AttackMovementProfile

## Cuantas veces sale este paso, una detras de otra. Es una COPIA LITERAL: cada repeticion vuelve a
## reproducir el clip, abre su propia ventana de dano, cuenta su register_hit y vuelve a pedir su
## `movement` entero. No hay reglas especiales para la primera ni para la ultima.
##
## Existe para las vueltas de los taps direccionales, que hasta ahora eran un `int` del tuning
## (`tap_forward_x_spins`) traducido a UN clip estirado con UNA sola ventana de dano: tres vueltas se
## veian, pero el enemigo cobraba una vez y el combo sumaba uno.
##
## Que se repita todo, mover incluido, es a proposito: si la vuelta 1 tiene que desplazarte y las
## otras no, eso son DOS pasos —uno con `movement` y otro con la misma animacion sin el— y no un
## campo que diga "el mover solo la primera vez". Lo que se ve en el inspector es lo que pasa.
##
## 0 = este paso no sale. Combinado con `repeat_with_meter` es como se declara un golpe que SOLO
## existe pagando barra, sin necesidad de un flag aparte.
@export_range(0, 8, 1) var repeat := 1

## `repeat` cuando el gesto pago meter (RT). -1 = usa el mismo `repeat`, o sea que el RT no cambia
## cuantas veces sale.
##
## Es un numero absoluto y no un bono en % como los del AttackMovementProfile: las vueltas son una
## cuenta discreta, y "2" se lee sin hacer la cuenta que hay que hacer con "+100%". Son ademas los
## dos knobs que ya existian (`tap_forward_x_spins` / `tap_forward_x_meter_spins`).
@export_range(-1, 8, 1) var repeat_with_meter := -1

## El Player avanza hacia el objetivo lockeado mientras dura el paso (Player.attack_step). Es el
## paso corto que acompana a casi todos los golpes de combo; los especiales que traen su propio
## Mover lo dejan apagado para no pelear con el.
@export var advances := true

## El empujon se declara en `movement.enemy_push` desde el 2026-07-30. Antes era un bool aca que
## apuntaba al PushSettings unico del arma, asi que todos los golpes que empujaban empujaban igual y
## no se veia el arco sin abrir el tuning. Ver AttackMovementProfile.enemy_push.

## Este paso dispara el proyectil del arma. Se mudo aca desde AttackMovementProfile.rt_fires_
## projectile: el disparo dejo de estar atado a que cierre un recorrido y pasa a ser un beat de la
## secuencia, que es lo que permite decir "sale en el segundo golpe de los tres que agrega RT".
@export var fires_projectile := false

## FAMILIA del golpe: la etiqueta con la que el arma reconoce mecanicas suyas que no tienen sentido
## como campo generico. No dibuja nada — el dibujo es `clip`. Hoy la Espada la usa para dos cosas:
## los pasos terrestres sostienen al Player en el aire mientras dura el combo, y el finisher aereo
## estira sus hitboxes en V (ver Sword.on_sequence_step).
##
## Nacio como nombre de un tween de mano en el swing procedural; al morir ese swing quedo solo la
## parte mecanica. Es un escape hatch: si algo se puede expresar como campo del paso, va como campo.
@export var choreography: StringName = &""

@export_group("Rama por espera")
## Segundos que hay que tardar en encadenar DESPUES de este golpe para desviar la cadena. Se mide
## entre el fin de este paso y el tap que pide el siguiente, siempre dentro de `chain_window`:
## pasarse de la ventana no ramifica, corta la cadena. 0 = este golpe no ramifica.
@export var wait_threshold := 0.0

## Los pasos que reemplazan a TODO lo que venia despues de este golpe si se cumplio la espera. No se
## agregan: sustituyen, asi que una rama puede alargar o acortar la cadena.
##
## La rama cuelga del PASO y no de la secuencia, y por eso cada uno de estos pasos puede a su vez
## declarar la suya: `X X espera X espera X X X` es un paso con rama cuyo primer paso tiene otra
## rama. Antes las ramas vivian en la secuencia con un `after_step` absoluto, y eso obligaba a
## ramificar UNA sola vez por corrida — con dos puntos de espera los numeros colisionaban y la rama
## tardia secuestraba a la temprana. Colgando del paso no hay numeracion que colisione.
##
## Es autorreferencia (un AttackStep que contiene AttackSteps), no un ciclo entre dos clases: el
## grafo es un arbol y Godot lo serializa anidando sub-recursos.
@export var wait_steps: Array[AttackStep] = []
