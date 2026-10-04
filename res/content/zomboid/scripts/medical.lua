local survival = require "zomboid:survival"
local inv = require "zomboid:inv"

local function apply(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local kind = item.name(itemid):sub(#"zomboid:" + 1)
    if survival.treat(pid, kind) then
        if item.uses(itemid) and item.uses(itemid) > 0 then
            inventory.use(invid, slot)
        else
            inventory.decrement(invid, slot, 1)
        end
    end
    return true
end

function on_use(pid)
    return apply(pid)
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return apply(pid)
end
