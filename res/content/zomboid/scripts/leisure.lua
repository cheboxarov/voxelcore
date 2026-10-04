local survival = require "zomboid:survival"
local vitals = require "zomboid:vitals"
local inv = require "zomboid:inv"

local MESSAGES = {
    novel = "Вы прочитали главу. Мысли отвлеклись от кошмара вокруг",
    magazine = "Вы полистали журнал. Стало чуть веселее",
    cigarettes = "Вы закурили. Нервы немного успокоились",
}

local function use(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local name = item.name(itemid):sub(#"zomboid:" + 1)
    local state = survival.get(pid)
    if state.boredom < 5 and state.unhappiness < 5 then
        survival.notify(pid, "Сейчас не до этого")
        return true
    end
    if name == "cigarettes" then
        local mslot = inventory.find_by_item(invid, item.index("zomboid:matches"))
        if mslot == nil then
            survival.notify(pid, "Нечем прикурить: нужны спички")
            return true
        end
        inventory.use(invid, mslot)
    end
    vitals.cheer(state, item.properties[itemid]["zomboid:mood"] or 0)
    if item.uses(itemid) and item.uses(itemid) > 0 then
        inventory.use(invid, slot)
    else
        inventory.decrement(invid, slot, 1)
    end
    survival.notify(pid, MESSAGES[name] or "Стало немного легче", "#c0b0f0")
    return true
end

function on_use(pid)
    return use(pid)
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return use(pid)
end
