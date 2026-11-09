# scripts/autoload/scene_router.gd — Autoload (client). A1 stub + routing gelombang 3.
extends Node

## Hasil match terakhir (diisi scene race sebelum pindah ke result_screen).
var last_match_results: Array = []

## Ganti scene aktif (dengan defer — aman saat _ready pemanggil).
## Mendukung .tscn (change_scene_to_file) dan .gd (dibangun di kode, aturan 0.7).
func goto_scene(path: String) -> void:
	call_deferred("_do_goto", path)


func _do_goto(path: String) -> void:
	if path.ends_with(".gd") and FileAccess.file_exists(path):
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_error("SceneRouter: gagal memuat " + path)
			return
		var node: Node = script.new()
		node.name = "CurrentScene"
		var tree: SceneTree = get_tree()
		var old: Node = tree.current_scene
		tree.root.add_child(node)
		if old != null and old != node:
			tree.current_scene = node
			old.queue_free()
		else:
			tree.current_scene = node
		return
	get_tree().change_scene_to_file(path)
