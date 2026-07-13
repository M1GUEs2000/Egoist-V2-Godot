class_name WorldScanTuning extends Resource
## Tuning del scan de cambio de mundo: la onda que sale del trigger al voltear el mundo y va
## revelando las cosas del mundo destino a su paso. Instancia editable: data/world_scan_tuning.tres.
##
## La onda hace DOS cosas y las dos usan estos numeros:
##  - Gameplay/visibilidad: cada WorldMembership se voltea cuando el frente lo alcanza
##    (delay = distancia / speed, ver WorldManager.scan_delay_for).
##  - Visual: la cascara luminosa que dibuja WorldScan.
## El COLOR no se tunea aca: siempre es el del mundo DESTINO (World.world_emission), como manda
## la convencion de colores de mundo.

@export_group("Onda")
## Velocidad del frente en metros por segundo. Baja = el mundo se revela lento y se lee el barrido;
## alta = casi instantaneo. 0 = sin onda (switch instantaneo en todo el mapa, como antes).
@export_range(0.0, 200.0, 0.5) var speed := 28.0
## Radio maximo en metros. Mas alla de esto la onda se apaga y lo que quede se voltea sin esperar:
## evita que una esquina lejana del mapa tarde 10 segundos en existir.
@export_range(1.0, 200.0, 1.0) var max_radius := 45.0
## Segundos que tarda la cascara en desvanecerse una vez que llego al radio maximo.
@export_range(0.0, 3.0, 0.05) var fade_out := 0.35

@export_group("Luz de la cascara")
## Brillo de la cascara. Es luz TENUE: subir con cuidado, el WorldEnvironment tiene glow y
## cualquier emision alta se convierte en halo.
@export_range(0.0, 8.0, 0.05) var energy := 1.2
## Opacidad general de la cascara (se suma en additive). Bajala si la onda tapa el escenario.
@export_range(0.0, 1.0, 0.01) var alpha := 0.45
## Grosor/dureza del borde: exponente del fresnel. Alto = solo el filo de la esfera brilla (anillo
## fino); bajo = brilla toda la cascara (burbuja llena).
@export_range(0.5, 8.0, 0.1) var rim_power := 3.0

@export_group("Trama de poligonos")
## Cuantas lineas de la malla se dibujan sobre la esfera. Alto = trama fina tipo scanner tecnico;
## bajo = pocos poligonos grandes.
@export_range(1.0, 64.0, 1.0) var grid_density := 14.0
## Ancho de cada linea de la trama, en pixeles aproximados.
@export_range(0.5, 6.0, 0.1) var grid_width := 1.4
## Cuanto pesa la trama frente al borde fresnel. 0 = solo el filo (burbuja limpia); 1 = la trama
## de poligonos es lo que se ve.
@export_range(0.0, 1.0, 0.05) var grid_mix := 0.7

@export_group("Luz real")
## Energia de la OmniLight que viaja con el frente e ilumina el entorno con el color del mundo
## destino. 0 = la onda no ilumina nada (solo se ve la cascara).
@export_range(0.0, 8.0, 0.1) var light_energy := 1.5
## Alcance de esa luz respecto del radio de la onda. 1 = ilumina justo hasta el frente;
## >1 = derrama luz un poco mas alla, adelantando lo que viene.
@export_range(0.5, 3.0, 0.05) var light_range_scale := 1.15
