local barricade = require "zomboid:barricade"

function on_use_on_block(x, y, z, pid)
    if block.has_tag(block.get(x, y, z), "zomboid:barricade") then
        barricade.remove(pid, x, y, z)
        return true
    end
    return false
end
