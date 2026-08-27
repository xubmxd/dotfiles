-- ~/.config/hypr/hyprland.lua
local home = os.getenv("HOME")

-- Add ~/.config/hypr to Lua's module search path so 'require' works cleanly
package.path = package.path .. ";" .. home .. "/.config/hypr/?.lua"

-- Load Pywal colors directly using dofile (since it's outside the config folder)
local wal_colors = home .. "/.cache/wal/colors-hyprland.lua"
local f = io.open(wal_colors, "r")
if f ~= nil then
    f:close()
    dofile(wal_colors)
end

--################
--### MONITORS ###
--################
require("source-configs.monitors")

--###################
--### MY PROGRAMS ###
--###################
require("source-configs.programs")

--#############################
--### ENVIRONMENT VARIABLES ###
--#############################
require("source-configs.enviornment-variables")

--#################
--### AUTOSTART ###
--#################
require("source-configs.autostarts")

--###################
--### Appearance  ###
--###################
require("source-configs.appearance")

--###################
--### Animations  ###
--###################
-- require("source-configs.animation.minimal")
-- require("source-configs.animation.minimal-smoother")
require("source-configs.animation.apple")
-- require("source-configs.animation.premium")

-- Load the dynamic Waybar workspace animations
require("source-configs.waybar_anim")

--#############
--### INPUT ###
--#############
require("source-configs.input")

--###################
--### KEYBINDINGS ###
--###################
require("source-configs.keybinds")

--##############################
--### WINDOWS AND WORKSPACES ###
--##############################
require("source-configs.window-rules")

--###################
--### Layer rules ###
--###################
require("source-configs.layer-rules")


require("source-configs.waybar_anim")

