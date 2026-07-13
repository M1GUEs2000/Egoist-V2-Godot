# Egoist V2 - Entrada para Claude Code

Este archivo es solo una brujula para no perderse al abrir el repo. No es la fuente de verdad del diseno, arquitectura, backlog ni gameplay.

La fuente de verdad operativa esta en la boveda V2:

`C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/obsidian/`

## 1. Entrar por la boveda

Lo primero al abrir el proyecto es entrar a la boveda y leer su README:

`C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/obsidian/README.md`

Ese README ensena como moverse dentro de la boveda. La boveda esta organizada por nodos: primero se entiende el mapa general en `Arquitectura Godot.md`, y desde ahi se baja al nodo que toque (`Gameplay`, `Arte`, `Tareas`, `Decisiones`, `Migracion`, etc.).

Orden minimo antes de disenar, modificar o borrar algo:

1. `C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/obsidian/README.md`
2. `C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/METODOLOGIA.md`
3. `C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/obsidian/Arquitectura Godot.md`
4. La nota especifica del sistema dentro de `obsidian/Gameplay/`, `obsidian/Arte/`, `obsidian/Tareas/`, `obsidian/Decisiones/` o `obsidian/Migracion/`.

No duplicar en este archivo lo que ya vive en la boveda. Si cambia una decision de diseno o arquitectura, actualizar la nota correcta en `obsidian/`.

## 2. Proyecto activo

- Proyecto Godot: `C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/`
- Archivo de proyecto: `C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/project.godot`
- Boveda V2: `C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/obsidian/`
- Boveda vieja, solo historica: `C:/Users/Tutupa/Documents/Proyectos/Egoist/Boveda/`
- Unity V1, solo referencia: `C:/Users/Tutupa/Documents/Proyectos/Egoist/Unity/Egoist V1/`

Si la boveda vieja o Unity contradicen la boveda V2, manda la boveda V2.

## 3. Godot

- Version: Godot 4.7 stable
- Ejecutable local: `C:/Users/Tutupa/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe`
- Escena de prueba principal: `res://world/test_scene.tscn`
- Smokes: `res://world/smoke_test.tscn` (regresion transversal) y
  `res://world/combat_smoke_test.tscn` (contratos aislados de combate)

## 4. Skills instaladas

Usar estas skills cuando aplique:

- Godot gameplay/GDScript: `C:/Users/Tutupa/.agents/skills/godot-gdscript-patterns/SKILL.md`
- Godot UI/HUD/menus: `C:/Users/Tutupa/.agents/skills/godot-ui/SKILL.md`
- Obsidian Markdown: `C:/Users/Tutupa/.codex/skills/obsidian-markdown/SKILL.md`
- Obsidian Bases: `C:/Users/Tutupa/.codex/skills/obsidian-bases/SKILL.md`

`METODOLOGIA.md` define cuando usar skills y como cerrar cambios. Seguirla antes de tocar codigo.

## 5. Verificacion rapida

Desde `C:/Users/Tutupa/Documents/Proyectos/Egoist/Godot/egoist-v-2/`:

```powershell
$GODOT="C:/Users/Tutupa/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
& $GODOT --headless --path . --import
& $GODOT --headless --path . --quit-after 2
```

Si tocaste logica core:

```powershell
$GODOT="C:/Users/Tutupa/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
& $GODOT --headless --path . res://world/smoke_test.tscn
& $GODOT --headless --path . res://world/combat_smoke_test.tscn
```

Los smokes corren **sin** `--quit-after`: el test tarda mas de 2 frames y ese flag los
mata a mitad de camino, con exit 0 y sin haber probado nada. Solo valen si imprimen su
mensaje `... SMOKE OK`.

Para probar jugando:

```powershell
$GODOT="C:/Users/Tutupa/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
& $GODOT --path . res://world/test_scene.tscn
```

El feel lo aprueba Tutupa jugando; headless solo verifica que no este roto.
