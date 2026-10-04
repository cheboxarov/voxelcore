local farming = require "zomboid:farming"
local inv = require "zomboid:inv"

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    farming.plant(pid, x, y, z, item.properties[inv.held(pid)]["zomboid:crop"])
    return true
end
