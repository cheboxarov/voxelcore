local inv = require "zomboid:inv"

local fuel = {CAN = 10}

function fuel.held_can(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local name = item.name(itemid)
    if name == "zomboid:gas_can" then
        return inventory.get_uses(invid, slot), invid, slot
    elseif name == "zomboid:gas_can_empty" then
        return 0, invid, slot
    end
    return nil
end

local function set_can(invid, slot, liters)
    if liters <= 0 then
        inventory.set(invid, slot, item.index("zomboid:gas_can_empty"), 1)
    else
        inventory.set(invid, slot, item.index("zomboid:gas_can"), 1)
        inventory.set_data(invid, slot, "uses", liters)
    end
end

function fuel.pour(pid, max)
    local liters, invid, slot = fuel.held_can(pid)
    local amount = math.max(0, math.min(liters or 0, math.floor(max)))
    if amount > 0 then
        set_can(invid, slot, liters - amount)
    end
    return amount
end

function fuel.fill(pid, available)
    local liters, invid, slot = fuel.held_can(pid)
    local amount = math.max(0, math.min(fuel.CAN - (liters or fuel.CAN), math.floor(available)))
    if amount > 0 then
        set_can(invid, slot, liters + amount)
    end
    return amount
end

return fuel
