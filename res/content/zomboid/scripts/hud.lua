local survival = require "zomboid:survival"

local function toggle(layout)
    if hud.is_open(layout) then
        hud.close(layout)
    elseif not hud.is_inventory_open() and not survival.get(hud.get_player()).dead then
        hud.show_overlay(layout, true)
    end
end

function on_hud_open(playerid)
    hud.open_permanent("zomboid:hud")
    input.add_callback("zomboid.crafting", function()
        toggle("zomboid:crafting")
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
