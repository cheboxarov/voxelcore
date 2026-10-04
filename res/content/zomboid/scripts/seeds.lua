local farming = require "zomboid:farming"
local inv = require "zomboid:inv"

function on_use_on_block(x, y, z, pid)
    farming.plant(pid, x, y, z, item.properties[inv.held(pid)]["zomboid:crop"])
    return true
end
