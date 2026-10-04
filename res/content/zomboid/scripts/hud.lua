local survival = require "zomboid:survival"
local traits = require "zomboid:traits"
local firearms = require "zomboid:firearms"
local combat = require "zomboid:combat"
local mapping = require "zomboid:mapping"
local cars = require "zomboid:cars"

local function toggle(layout)
    if hud.is_open(layout) then
        hud.close(layout)
    elseif not hud.is_inventory_open() and not survival.get(hud.get_player()).dead then
        hud.show_overlay(layout, true)
    end
end

local function in_game()
    return not hud.is_inventory_open() and not hud.is_paused()
end

local function update_vision()
    local slot = gfx.posteffects.index("zomboid:myopia")
    if slot < 0 then
        return
    end
    gfx.posteffects.set_effect(slot, "zomboid_myopia")
    gfx.posteffects.set_intensity(slot, traits.has(survival.get(hud.get_player()), "short_sighted") and 1.0 or 0.0)
end

function on_hud_open(playerid)
    hud.open_permanent("zomboid:hud")
    input.add_callback("zomboid.crafting", function()
        toggle("zomboid:crafting")
    end)
    input.add_callback("zomboid.skills", function()
        toggle("zomboid:skills")
    end)
    input.add_callback("key:escape", function()
        if hud.is_open("zomboid:sandbox") or hud.is_open("zomboid:character") then
            hud.pause()
            return true
        end
    end)
    events.on("zomboid:character_ready", update_vision)
    events.on("zomboid:new_character", update_vision)
    update_vision()
    input.add_callback("player.attack", function()
        if in_game() then
            firearms.fire(hud.get_player())
        end
    end)
    input.add_callback("zomboid.reload", function()
        if in_game() then
            firearms.reload(hud.get_player())
        end
    end)
    input.add_callback("zomboid.push", function()
        if in_game() then
            combat.push(hud.get_player())
        end
    end)
    input.add_callback("zomboid.gear", function()
        toggle("zomboid:gear")
    end)
    input.add_callback("zomboid.building", function()
        toggle("zomboid:build")
    end)
    input.add_callback("zomboid.map", function()
        if hud.is_open("zomboid:map") or mapping.has_map(hud.get_player()) then
            toggle("zomboid:map")
        else
            survival.notify(hud.get_player(), "Нужна карта города. Поищите её в домах или на заправке")
        end
    end)
    input.add_callback("zomboid.car", function()
        cars.toggle(hud.get_player())
    end)
    events.on("zomboid:player_died", function(pid)
        if pid == hud.get_player() then
            hud.close_inventory()
            hud.show_overlay("zomboid:death", false)
        end
    end)
    if survival.get(playerid).dead then
        hud.show_overlay("zomboid:death", false)
    end
end
