class_name SwordTrailTuning extends RibbonTrailTuning
## Tuning de la estela de la Espada (ver visual/sword_trail.gd y visual/sword_trail.gdshader).
## Instancia editable: data/sword_trail_tuning.tres.
##
## Es un Resource propio y no campos sueltos en SwordTuning porque la estela es una capa VISUAL:
## no toca posicion, dano ni timing de nadie. Tocar estos numeros no puede cambiar el feel del
## combate, y esa separacion es justamente lo que se quiere poder afirmar sin releer el codigo.
##
## Que NO vive aca: CUANDO se dibuja la estela. Eso lo decide la ventana de dano del golpe
## (WeaponBase.begin_damage_window), que a su vez sale del AttackClip del paso. La estela empieza y
## termina con el hitbox de la hoja, asi que un golpe que abre tarde su ventana tambien deja la
## estela tarde, sin que haya un segundo lugar donde eso se tunee.
##
## Organizacion del inspector igual que el resto del tuning del arma: un grupo por decision, no por
## tipo de dato.
