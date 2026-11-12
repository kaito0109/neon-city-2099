class_name ModelBlob
extends Resource
## Raw GLB bytes stored as a text .tres resource. Godot only exports
## recognized resources into the web pck, and the GitHub snapshot push
## only carries UTF-8 text — a .tres satisfies both constraints, so the
## Blender models can ship without any CI decode step or binary push.
@export var data: PackedByteArray
