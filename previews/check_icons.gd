extends SceneTree

func _initialize() -> void:
	var config=ConfigFile.new()
	assert(config.load("res://export_presets.cfg")==OK)
	var head=config.get_value("preset.0.options","html/head_include")
	assert(head.contains('href="favicon.ico"'))
	assert(head.contains('href="apple-touch-icon.png"'))
	assert(head.contains('href="site.webmanifest"'))
	for file in {"assets/icon.png":1024,"web/icon-512.png":512,"web/icon-192.png":192,"web/apple-touch-icon.png":180,"web/favicon-32.png":32,"web/favicon-16.png":16}:
		var image=Image.load_from_file("res://"+file)
		assert(image!=null and image.get_width()==image.get_height())
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://web/site.webmanifest"))
	for icon in manifest.icons:
		assert(FileAccess.file_exists("res://web/"+icon.src))
	assert(ProjectSettings.get_setting("application/config/icon")=="res://assets/icon.png")
	print("PASS: export links, square icon assets, manifest paths and project icon.")
	quit()
