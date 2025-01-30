extends Window


signal return_status(status)


func _ready():
	close_requested.connect(close)
	await get_tree().process_frame
	_on_MarginContainer_minimum_size_changed()


func _on_LoginButton_pressed():
	return_status.emit("ok")

func close() -> void:
	return_status.emit("cancel")
	queue_free()

func ask(user : String, password : String) -> Dictionary:
	mm_globals.main_window.add_dialog(self)
	if user != "":
		$MarginContainer/VBoxContainer/UserName.text = user
		$MarginContainer/VBoxContainer/SaveUser.button_pressed = true
	if password != "":
		$MarginContainer/VBoxContainer/Password.text = password
		$MarginContainer/VBoxContainer/SavePassword.button_pressed = true
	popup_centered()
	var result = await self.return_status
	queue_free()
	if result == "ok":
		return {
			user=$MarginContainer/VBoxContainer/UserName.text,
			save_user=$MarginContainer/VBoxContainer/SaveUser.pressed,
			password=$MarginContainer/VBoxContainer/Password.text,
			save_password=$MarginContainer/VBoxContainer/SavePassword.pressed
		}
	return {}

func _on_MarginContainer_minimum_size_changed():
	size = $MarginContainer.get_minimum_size()

func _on_RegisterButton_pressed():
	OS.shell_open(MMPaths.WEBSITE_ADDRESS+"/register")
