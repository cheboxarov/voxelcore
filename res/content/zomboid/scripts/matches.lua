local fire = require "zomboid:fire"
local survival = require "zomboid:survival"
local inv = require "zomboid:inv"

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    if not fire.burn(x, y, z) then
        survival.notify(pid, "Это не горит")
        return true
    end
    local _, _, invid, slot = inv.held(pid)
    inventory.use(invid, slot)
    survival.notify(pid, "Вы подожгли " .. block.caption(id), "#ff9050")
    return true
end
