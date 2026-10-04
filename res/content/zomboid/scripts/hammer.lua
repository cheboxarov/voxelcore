local survival = require "zomboid:survival"
local barricade = require "zomboid:barricade"

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if not barricade.is_target(id) then
        return false
    end
    local ok, err = barricade.add(pid, x, y, z)
    if not ok then
        survival.notify(pid, err)
    end
    return true
end
