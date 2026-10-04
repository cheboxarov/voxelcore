local survival = require "zomboid:survival"
local clock = require "zomboid:clock"
local water = require "zomboid:water"
local inv = require "zomboid:inv"
local loot = require "zomboid:loot"

function on_placed(x, y, z, pid)
    block.set_user_bits(x, y, z, 0, 1, 1)
end

function on_interact(x, y, z, pid)
    local itemid = inv.held(pid)
    if itemid == item.index("zomboid:dirty_water_bottle") then
        if clock.day() >= survival.POWER_SHUTOFF_DAY then
            survival.notify(pid, "Плита не работает: электричества больше нет")
        else
            water.purify_held(pid)
        end
        return true
    end
    local invid = inventory.get_block(x, y, z)
    if block.get_user_bits(x, y, z, 0, 1) == 0 then
        block.set_user_bits(x, y, z, 0, 1, 1)
        loot.fill(invid, "stove", x, z, clock.START_HOUR)
    end
    if hud then
        hud.open_block(x, y, z)
    end
    return true
end
