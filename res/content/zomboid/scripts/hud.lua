local survival = require "zomboid:survival"
local traits = require "zomboid:traits"

local function toggle(layout)
    if hud.is_open(layout) then
        hud.close(layout)
    elseif not hud.is_inventory_open() and not survival.get(hud.get_player()).dead then
        hud.show_overlay(layout, true)
    end
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
    events.on("zomboid:character_ready", update_vision)
    events.on("zomboid:new_character", update_vision)
    update_vision()
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
