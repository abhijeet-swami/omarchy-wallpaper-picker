hl.curve("verticalEase", {
    type = "bezier",
    points = { { 0.16, 1 }, { 0.3, 1 } }
})
hl.curve("verticalSnap", {
    type = "bezier",
    points = { { 0.22, 1 }, { 0.36, 1 } }
})
hl.curve("verticalFade", {
    type = "bezier",
    points = { { 0.4, 0 }, { 1, 1 } }
})
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 4,
    bezier = "verticalEase"
})
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 4,
    bezier = "verticalEase",
    style = "popin"
})
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 3,
    bezier = "verticalEase",
    style = "popin 90%"
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 2,
    bezier = "verticalFade",
    style = "popin 90%"
})
hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 4,
    bezier = "verticalSnap"
})
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 3,
    bezier = "verticalEase"
})
hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 3,
    bezier = "verticalEase"
})
hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 2,
    bezier = "verticalFade"
})
hl.animation({
    leaf = "fadeDim",
    enabled = true,
    speed = 3,
    bezier = "verticalEase"
})
hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 4,
    bezier = "verticalEase"
})
hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 3,
    bezier = "verticalEase",
    style = "fade"
})
hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 2,
    bezier = "verticalFade",
    style = "fade"
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 4,
    bezier = "verticalSnap",
    style = "slidevert"
})
hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 3,
    bezier = "verticalEase",
    style = "fade"
})
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 3,
    bezier = "verticalEase"
})
hl.animation({
    leaf = "borderangle",
    enabled = true,
    speed = 4,
    bezier = "verticalSnap"
})
hl.animation({
    leaf = "fadeSwitch",
    enabled = true,
    speed = 2,
    bezier = "verticalEase"
})
