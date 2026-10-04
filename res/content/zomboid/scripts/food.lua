local survival = require "zomboid:survival"
local inv = require "zomboid:inv"
local clock = require "zomboid:clock"

local function eat(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local props = item.properties[itemid]
    local state = survival.get(pid)
    local hunger = props["zomboid:hunger"] or 0
    local thirst = props["zomboid:thirst"] or 0
    local sickness = props["zomboid:sickness"] or 0
    if hunger > thirst and state.hunger >= 97 then
        survival.notify(pid, "Вы не голодны")
        return true
    end
    local days = props["zomboid:spoil-days"]
    local born = inventory.get_data(invid, slot, "born")
    if days and born and (clock.hours - born) / 24 > days then
        hunger = hunger * 0.6
        sickness = sickness + 25
        survival.notify(pid, "На вкус так себе...", "#c0d060")
    end
    survival.eat(pid, hunger, thirst, sickness)
    inventory.decrement(invid, slot, 1)
    if sickness > 0 then
        survival.notify(pid, "Вас мутит", "#c0d060")
    end
    return true
end

function on_use(pid)
    return eat(pid)
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return eat(pid)
end
