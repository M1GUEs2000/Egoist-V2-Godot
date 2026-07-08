---
name: IA
description: >
  Router de IA para videojuegos: dirige la petición a la skill especializada correcta
  en vez de cargar las tres a la vez. Usar cuando el usuario diga "IA", "IA de
  enemigos", "IA de combate", "arma la IA", "necesito IA para el juego", "el
  enemigo no sabe qué hacer", "pathfinding", "navegación", "que patrulle", "que
  persiga", "árbol de comportamiento", "behavior tree", "máquina de estados
  para NPC", o invoque /IA.
---

# Skill: IA

Router — no resuelve nada por sí misma. Decide cuál de las tres skills de IA de
videojuegos instaladas invocar según lo que pida el usuario, e invoca **solo esa**.

## Skills disponibles

| Si el pedido es sobre...                                                                 | Invocar                        |
|--------------------------------------------------------------------------------------------|---------------------------------|
| Combate, sigilo, diálogos, coordinación de grupo, árboles de comportamiento específicamente, refactor de una FSM "spaghetti" a un árbol limpio, o decidir BT vs FSM vs utility AI | `game-ai-behavior-trees`       |
| Navegación y movimiento **en Godot**: NavigationAgent2D/3D, NavigationServer, navmesh dinámico, avoidance, baking async, obstáculos móviles | `godot-navigation-pathfinding` |
| Todo lo demás de IA de NPCs/enemigos: decisión general (FSM/BT), steering/flocking, A* agnóstico de motor, patrullaje/persecución/huida sin mención explícita de Godot o de árboles de comportamiento | `game-ai`                      |

## Reglas

1. Lee el pedido del usuario y clasifícalo con la tabla de arriba.
2. Invoca **una sola** skill vía la tool `Skill`, la que mejor matchee.
3. Si el pedido mezcla dos categorías (ej. "quiero un behavior tree que use NavigationAgent en Godot"), invoca ambas relevantes, nunca las tres por defecto.
4. Si el pedido es ambiguo y no calza claramente en ninguna fila, pregunta al usuario en una frase antes de invocar cualquiera.