local survival = require "zomboid:survival"
local water = require "zomboid:water"

function on_use(pid)
    if water.find_source(pid) then
        return water.fill_held(pid, false)
    end
    survival.notify(pid, "Наберите воду из водоёма или крана")
    return true
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    if water.find_source(pid, x, y, z) then
        return water.fill_held(pid, false)
    end
    return on_use(pid)
end
