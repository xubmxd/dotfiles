hl.layer_rule({
    name = "waybar-blur",
    match = {
        namespace = "waybar",
    },
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "rofi-blur",
    match = {
        namespace = "rofi",
    },
    blur = true,
    ignore_alpha = 0.4,
})

hl.layer_rule({
    name = "rofi-blur",
    match = {
        namespace = "rofi",
    },
    blur = true,
})

hl.layer_rule({
    name = "sway-blur",
    match = {
        namespace = "swaync-control-center",
    },
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    match = {
        namespace = "gtk-layer-shell",
    },
    blur = true,
    ignore_alpha = 0.2,
})
