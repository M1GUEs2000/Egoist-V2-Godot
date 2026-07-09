# layer_mask_navigation.gd
# Toggling agent capabilities (e.g. Flying vs Walking) using bitmasks.
# In Godot 4, navigation layers are a property on NavigationAgent3D,
# not server-side RID calls. Use agent.navigation_layers directly.
extends Node

enum NavLayers {
	WALK = 1,
	JUMP = 2,
	FLY = 4,
	SWIM = 8
}

func set_agent_capability(agent: NavigationAgent3D, layers: int) -> void:
	# navigation_layers is a 32-bit bitmask on the NavigationAgent3D node.
	# This filters which NavigationRegion3D the agent can use.
	agent.navigation_layers = layers

func unlock_swimming(agent: NavigationAgent3D) -> void:
	agent.navigation_layers = agent.navigation_layers | NavLayers.SWIM
