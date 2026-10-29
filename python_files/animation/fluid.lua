hl.curve("fluidOut", {
    type = "bezier",
    points = { { 0.16, 1 }, { 0.3, 1 } }
})
hl.curve("fluidIn", {
    type = "bezier",
    points = { { 0.7, 0 }, { 0.84, 0 } }
})
hl.curve("fluidSmooth", {
    type = "bezier",
    points = { { 0.65, 0 }, { 0.35, 1 } }
})
hl.curve("fluidSnap", {
    type = "bezier",
    points = { { 0.22, 1 }, { 0.36, 1 } }
})
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 4,
    bezier = "fluidOut"
})
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 4,
    bezier = "fluidOut",
    style = "popin"
})
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 4,
    bezier = "fluidOut",
    style = "popin 85%"
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 2,
    bezier = "fluidIn",
    style = "popin 85%"
})
hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 4,
    bezier = "fluidSmooth",
    style = "slide"
})
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 3,
    bezier = "fluidOut"
})
hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 3,
    bezier = "fluidOut"
})
hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 2,
    bezier = "fluidIn"
})
hl.animation({
    leaf = "fadeDim",
    enabled = true,
    speed = 3,
    bezier = "fluidSmooth"
})
hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 4,
    bezier = "fluidOut"
})
hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 3,
    bezier = "fluidOut",
    style = "fade"
})
hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 2,
    bezier = "fluidIn",
    style = "fade"
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 4,
    bezier = "fluidSnap",
    style = "slide"
})
hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 3,
    bezier = "fluidOut",
    style = "fade"
})
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 3,
    bezier = "fluidOut"
})
hl.animation({
    leaf = "borderangle",
    enabled = true,
    speed = 4,
    bezier = "fluidSmooth"
})
hl.animation({
    leaf = "fadeSwitch",
    enabled = true,
    speed = 2,
    bezier = "fluidOut"
})
