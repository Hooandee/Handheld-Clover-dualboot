def build_boot_options(status, *, last_used_label, unvalidated_label):
    options = []
    seen = set()
    for entry in status.get("available_os") or []:
        option_id = str(entry.get("id") or "")
        if not option_id or option_id in seen:
            continue
        if option_id == "lastos":
            label = last_used_label
            command = ["set-default-os", "lastos"]
        elif option_id == "windows":
            label = str(entry.get("label") or "Windows")
            command = ["set-default-os", "windows"]
        else:
            loader = str(entry.get("loader") or "")
            if not loader:
                continue
            label = str(entry.get("label") or option_id)
            if not entry.get("validated", False):
                label = f"{label} ({unvalidated_label})"
            command = ["set-default-loader", loader]
        options.append({"id": option_id, "label": label, "command": command})
        seen.add(option_id)
    return options
