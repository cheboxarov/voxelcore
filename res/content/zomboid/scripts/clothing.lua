local survival = require "zomboid:survival"
local gear = require "zomboid:gear"
local water = require "zomboid:water"
local inv = require "zomboid:inv"

local function equip(pid)
    local _, _, invid, slot = inv.held(pid)
    local state = survival.get(pid)
    local caption, old = gear.equip(state, invid, slot)
    if caption then
        state.load = gear.load(pid, state)
        survival.notify(pid, "Вы надели: " .. caption .. (old and (". Сняли: " .. old) or ""), "#d0d0d0")
    end
    return true
end

function on_use(pid)
    return equip(pid)
end

function on_use_on_block(x, y, z, pid)
    if water.find_source(pid, x, y, z) then
        local _, _, invid, slot = inv.held(pid)
        gear.wash(invid, slot)
        survival.notify(pid, "Вы постирали вещь", "#90c0ff")
        return true
    end
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return equip(pid)
end
