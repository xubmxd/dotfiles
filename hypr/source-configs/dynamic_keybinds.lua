local mainMod = "SUPER"
hl.bind(mainMod .. " + SHIFT + apostrophe", hl.dsp.exec_cmd("quickshell ipc call island toggleWallpaper"))
hl.bind("ALT+F4", hl.dsp.exec_cmd("quickshell ipc call island togglePower"))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("qs ipc call island toggleAppLauncher"))

