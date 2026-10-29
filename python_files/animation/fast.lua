hl.curve("ease", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })
hl.curve("easeOut", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("easeIn", { type = "bezier", points = { { 0.55, 0 }, { 0.55, 0.2 } } })

hl.animation({ leaf = "global", enabled = true, speed = 1, bezier = "ease" })

hl.animation({ leaf = "windows", enabled = true, speed = 2.4, bezier = "ease" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.0, bezier = "easeIn" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.0, bezier = "ease" })

hl.animation({ leaf = "fade", enabled = true, speed = 2.0, bezier = "ease" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.6, bezier = "easeIn" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.6, bezier = "ease" })

hl.animation({ leaf = "layers", enabled = true, speed = 2.0, bezier = "ease" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.6, bezier = "easeIn" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 2.2, bezier = "ease" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.0, bezier = "ease" })

hl.animation({ leaf = "border", enabled = true, speed = 2.5, bezier = "ease" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 3.0, bezier = "ease" })

hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.4, bezier = "ease" })
