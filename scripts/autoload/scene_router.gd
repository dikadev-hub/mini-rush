# scripts/autoload/scene_router.gd
# Autoload: SceneRouter (client). Owner: A1.
# Minimal stub: routing antar scene dibangun oleh agent UI/lobi.
extends Node

## Ganti scene aktif. Implementasi penuh milik agent lain; stub ini
## hanya menyediakan kontrak API dasar agar pemanggil tidak crash.
func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
