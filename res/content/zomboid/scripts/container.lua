local loot = require "zomboid:loot"
local clock = require "zomboid:clock"

function on_placed(x, y, z, pid)
    block.set_user_bits(x, y, z, 0, 1, 1)
end

function on_interact(x, y, z, pid)
    if block.is_segment(x, y, z) then
        x, y, z = block.seek_origin(x, y, z)
    end
    local invid = inventory.get_block(x, y, z)
    if block.get_user_bits(x, y, z, 0, 1) == 0 then
        block.set_user_bits(x, y, z, 0, 1, 1)
        local kind = block.properties[block.get(x, y, z)]["zomboid:loot"]
        loot.fill(invid, kind, x, z, clock.START_HOUR)
    end
    if hud then
        hud.open_block(x, y, z)
    end
    return true
end
