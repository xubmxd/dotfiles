-- ~/.config/hypr/source-configs/appearance.lua

local function get_pywal_colors()
    local colors = {}
    local home = os.getenv("HOME")
    local file = io.open(home .. "/.cache/wal/colors-hyprland.conf", "r")
    
    if file then
        for line in file:lines() do
            local name, val = line:match("%$(color%d+)%s*=%s*(.*)")
            if name and val then
                colors[name] = val
            end
        end
        file:close()
    end
    
    colors.color0 = colors.color0 or "rgba(000000ff)"
    colors.color5 = colors.color5 or "rgba(888888ff)"
    colors.color12 = colors.color12 or "rgba(ccccccff)"
    
    return colors
end

local c = get_pywal_colors()

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 3,
        border_size = 0,
        col = {
            -- Gradient format updated to the new Lua table structure
            active_border = { colors = { c.color5, c.color12 }, angle = 45 },
            inactive_border = c.color0,
        },
        resize_on_border = false,
        allow_tearing = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        rounding_power = 5,
        active_opacity = 1.0,
        inactive_opacity = 0.5,
        shadow = {
            enabled = false,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 5,
            passes = 3,
            new_optimizations = true,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
})
