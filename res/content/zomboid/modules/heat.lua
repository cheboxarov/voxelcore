local power = require "zomboid:power"

local heat = {}

function heat.near(x, y, z, radius)
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    radius = radius or 2
    for dx = -radius, radius do
        for dz = -radius, radius do
            for dy = -1, 1 do
                local id = block.get(x + dx, y + dy, z + dz)
                if id > 0 and block.has_tag(id, "zomboid:heat")
                    and (not block.has_tag(id, "zomboid:electric") or power.has_power(x + dx, y + dy, z + dz)) then
                    return true
                end
            end
        end
    end
    return false
end

function heat.near_player(pid, radius)
    local x, y, z = player.get_pos(pid)
    return heat.near(x, y, z, radius)
end

return heat
