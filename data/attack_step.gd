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

## Multiplicador de dano de ESTE paso sobre el dano base del arma. Existe porque partir una cadena
## en N impactos multiplica el dano por N sin tocar un solo numero: un flurry de tres suele querer
## 1.0 / 0.6 / 0.6 y no 3x plano. 1.0 = el dano de lista del arma.
@export_range(0.0, 4.0, 0.05) var damage_scale := 1.0

## Que le hace este paso a la posicion de los cuerpos. Ver data/attack_movement_profile.gd. Es lo
## que permite decir "el Mover sale en el tercer golpe" desde el inspector: antes el beat de la
## cadena en el que salia un recorrido era codigo, porque un perfil por gesto no podia expresarlo.
## null = este paso no mueve a nadie.
@export var movement: AttackMovementProfile

## El Player avanza hacia el objetivo lockeado mientras dura el paso (Player.attack_step). Es el
## paso corto que acompana a casi todos los golpes de combo; los especiales que traen su propio
## Mover lo dejan apagado para no pelear con el.
@export var advances := true

## Este paso arma el empuje del arma (WeaponTuning.push, con su push_at). Es lo que hoy hace el
## finisher de la rama de espera en los dos combos de la Espada.
@export var pushes := false

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
