local survival = require "zomboid:survival"
local inv = require "zomboid:inv"
local water = require "zomboid:water"

local function drink(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local props = item.properties[itemid]
    local state = survival.get(pid)
    if state.thirst >= 97 then
        survival.notify(pid, "Вы не хотите пить")
        return true
    end
    local sickness = props["zomboid:sickness"] or 0
    if sickness > 0 and math.random() > 0.6 then
        sickness = 0
    end
    survival.eat(pid, 0, props["zomboid:thirst"] or 25, sickness)
    if inventory.get_uses(invid, slot) <= 1 then
        inventory.set(invid, slot, item.index("zomboid:empty_bottle"), 1)
    else
        inventory.use(invid, slot)
    end
    if sickness > 0 then
        survival.notify(pid, "У воды странный привкус...", "#c0d060")
    end
    return true
end

function on_use(pid)
    if water.find_source(pid) then
        return water.fill_held(pid, false)
    end
    return drink(pid)
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return on_use(pid)
end
