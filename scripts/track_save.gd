extends RefCounted
## Crash-resistant JSON persistence: write to a temporary file first,
## preserve the last good version, and recover from backups on load.
static func read_json(path: String) -> Variant:
    for candidate in [path, path + ".bak"]:
        if FileAccess.file_exists(candidate):
            var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
            if data is Array or data is Dictionary:
                return data
    return null

static func write_json(path: String, data: Variant) -> bool:
    var content := JSON.stringify(data)
    var temp := path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        push_warning("Unable to save track: " + path)
        return false
    file.store_string(content)
    file.flush()
    file.close()
    if FileAccess.get_file_as_string(temp) != content:
        push_warning("Track save verification failed: " + path)
        return false
    # Keep the last complete version before replacing the main file.
    if FileAccess.file_exists(path):
        var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if old is Array or old is Dictionary:
            DirAccess.copy_absolute(path, path + ".bak")
    var err := DirAccess.rename_absolute(temp, path)
    if err != OK:
        # On platforms where rename cannot replace an existing file.
        err = DirAccess.copy_absolute(temp, path)
        if err == OK:
            DirAccess.remove_absolute(temp)
    if err != OK:
        push_warning("Unable to finish track save: " + path)
    return err == OK
