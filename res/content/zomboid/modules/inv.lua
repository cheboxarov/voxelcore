local inv = {}

local function id_of(item_name)
    if type(item_name) == "number" then
        return item_name
    end
    return item.index(item_name)
end

local function matches(id, itemid)
    local fresh = id ~= 0 and item.properties[id]["zomboid:fresh"]
    return id == itemid or (fresh and item.index(fresh) == itemid)
end

function inv.count(invid, item_name)
    local itemid = id_of(item_name)
    local total = 0
    for slot = 0, inventory.size(invid) - 1 do
        local id, count = inventory.get(invid, slot)
        if matches(id, itemid) then
            total = total + count
        end
    end
    return total
end

function inv.take(invid, item_name, amount)
    amount = amount or 1
    if inv.count(invid, item_name) < amount then
        return false
    end
    local itemid = id_of(item_name)
    for slot = 0, inventory.size(invid) - 1 do
        if amount <= 0 then
            break
        end
        local id, count = inventory.get(invid, slot)
        if matches(id, itemid) then
            local taken = math.min(count, amount)
            inventory.decrement(invid, slot, taken)
            amount = amount - taken
        end
    end
    return true
end

function inv.give(pid, item_name, amount, data)
    local invid = player.get_inventory(pid)
    local itemid = id_of(item_name)
    amount = amount or 1
    if data then
        for _ = 1, amount do
            local slot = inventory.find_by_item(invid, 0, 0, inventory.size(invid) - 1, 0)
            if slot == nil then
                inv.drop(pid, itemid, 1, data)
            else
                inventory.set(invid, slot, itemid, 1)
                inventory.set_all_data(invid, slot, data)
            end
        end
        return
    end
    local rest = inventory.add(invid, itemid, amount)
    if rest > 0 then
        inv.drop(pid, itemid, rest)
    end
end

function inv.drop(pid, itemid, count, data)
    local x, y, z = player.get_pos(pid)
    local util = require "base:util"
    return util.drop({x, y, z}, itemid, count, data, 1.5)
end

function inv.held(pid)
    local invid, slot = player.get_inventory(pid)
    local itemid, count = inventory.get(invid, slot)
    return itemid, count, invid, slot
end

function inv.clear(invid)
    for slot = 0, inventory.size(invid) - 1 do
        inventory.set(invid, slot, 0, 0)
    end
end

return inv
