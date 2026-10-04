local inv = require "zomboid:inv"
local survival = require "zomboid:survival"

local water = {}

-- Turns a held dirty water bottle into clean water, keeping the remaining sips.
function water.purify_held(pid)
    local itemid, _, invid, slot = inv.held(pid)
    if itemid ~= item.index("zomboid:dirty_water_bottle") then
        return false
    end
    local uses = inventory.get_uses(invid, slot)
    inventory.set(invid, slot, item.index("zomboid:water_bottle"), 1)
    inventory.set_data(invid, slot, "uses", uses)
    survival.notify(pid, "Вода прокипячена и теперь безопасна", "#90c0ff")
    return true
end

-- Fills the held bottle; clean = tap water.
function water.fill_held(pid, clean)
    local itemid, count, invid, slot = inv.held(pid)
    local name = item.name(itemid)
    local result = clean and "zomboid:water_bottle" or "zomboid:dirty_water_bottle"
    if name == "zomboid:empty_bottle" then
        inventory.decrement(invid, slot, 1)
        inv.give(pid, result, 1)
    elseif name == "zomboid:water_bottle" or (name == "zomboid:dirty_water_bottle" and not clean) then
        inventory.set_data(invid, slot, "uses", item.uses(itemid))
    elseif name == "zomboid:dirty_water_bottle" and clean then
        inventory.set(invid, slot, item.index(result), 1)
    else
        return false
    end
    survival.notify(pid, clean and "Бутылка наполнена чистой водой" or "Бутылка наполнена сырой водой. Лучше прокипятить",
        clean and "#90c0ff" or "#c0d060")
    return true
end

function water.is_container(itemid)
    local name = item.name(itemid)
    return name == "zomboid:empty_bottle" or name == "zomboid:water_bottle" or name == "zomboid:dirty_water_bottle"
end

-- Looks for a water block along the player's view.
function water.find_source(pid)
    local x, y, z = player.get_pos(pid)
    local eye = {x, y + 0.7, z}
    local hit = block.raycast(eye, player.get_dir(pid), 4.5, nil, nil, true)
    return hit and block.name(hit.block) == "base:water"
end

return water
