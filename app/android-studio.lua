local home = os.getenv("HOME") or "/home/ced"

hl.env("ANDROID_AVD_HOME", home .. "/.config/.android/avd")
