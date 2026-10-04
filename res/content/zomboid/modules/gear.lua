local traits = require "zomboid:traits"

local gear = {
    SLOTS = {"head", "torso", "jacket", "legs", "feet", "back"},
    TITLES = {
        head = "Голова", torso = "Тело", jacket = "Верхняя одежда",
        legs = "Ноги", feet = "Обувь", back = "Рюкзак",
    },
    CAPACITY = 12.0,
    DEFAULT_WEIGHT = 0.5,
}

local INDEX = {}
for i, name in ipairs(gear.SLOTS) do
    INDEX[name] = i - 1
end

local COVERS = {
    head = {"head"}, torso = {"torso", "arms"}, jacket = {"torso", "arms"},
    legs = {"legs"}, feet = {"legs"}, back = {"torso"},
}
local OUTER_FIRST = {"jacket", "torso", "head", "legs", "feet"}
local PARTS = {{"torso", 0.4}, {"arms", 0.3}, {"legs", 0.2}, {"head", 0.1}}

local STARTER = {"zomboid:tshirt", "zomboid:jeans", "zomboid:boots"}

local function prop(itemid, name)
    local props = itemid ~= 0 and item.properties[itemid]
    return props and props[name]
end
gear.prop = prop

function gear.inventory(state)
    if state.gear_inv == nil then
        local invid = inventory.create(#gear.SLOTS)
        for _, e in ipairs(state.gear or {}) do
            local itemid = item.index(e.name)
            if itemid then
                inventory.set(invid, e.slot, itemid, 1, e.data)
            end
        end
        state.gear = nil
        state.gear_inv = invid
    end
    return state.gear_inv
end

function gear.worn(state, slot_name)
    local invid = gear.inventory(state)
    local slot = INDEX[slot_name]
    return inventory.get(invid, slot), invid, slot
end

function gear.dump(state)
    if state.gear_inv == nil then
        return state.gear
    end
    local list = {}
    for slot = 0, #gear.SLOTS - 1 do
        local itemid = inventory.get(state.gear_inv, slot)
        if itemid ~= 0 then
            table.insert(list, {slot = slot, name = item.name(itemid), data = inventory.get_all_data(state.gear_inv, slot)})
        end
    end
    return list
end

function gear.take_all(state)
    local items = {}
    for _, e in ipairs(gear.dump(state) or {}) do
        table.insert(items, {e.name, 1, e.data})
    end
    if state.gear_inv then
        inventory.remove(state.gear_inv)
        state.gear_inv = nil
    end
    state.gear = nil
    return items
end

function gear.dress(state)
    local invid = gear.inventory(state)
    for _, name in ipairs(STARTER) do
        local itemid = item.index(name)
        inventory.set(invid, INDEX[prop(itemid, "zomboid:slot")], itemid, 1)
    end
end

function gear.fits(itemid, slot)
    return prop(itemid, "zomboid:slot") == gear.SLOTS[slot + 1]
end

function gear.equip(state, invid, slot)
    local itemid = inventory.get(invid, slot)
    local target = INDEX[prop(itemid, "zomboid:slot")]
    if target == nil then
        return nil
    end
    local ginv = gear.inventory(state)
    local old, old_data = inventory.get(ginv, target), inventory.get_all_data(ginv, target)
    inventory.set(ginv, target, itemid, 1, inventory.get_all_data(invid, slot))
    inventory.set(invid, slot, old, old ~= 0 and 1 or 0, old ~= 0 and old_data or nil)
    return item.caption(itemid), old ~= 0 and item.caption(old) or nil
end

function gear.sum(state, name)
    local invid = gear.inventory(state)
    local total = 0
    for slot = 0, #gear.SLOTS - 1 do
        total = total + (prop(inventory.get(invid, slot), name) or 0)
    end
    return total
end

function gear.warmth(state)
    return gear.sum(state, "zomboid:warmth")
end

function gear.waterproof(state)
    return math.min(0.95, gear.sum(state, "zomboid:waterproof"))
end

function gear.dirt(invid, slot)
    return inventory.get_data(invid, slot, "dirt") or 0
end

local function describe(invid, slot)
    local dirt = gear.dirt(invid, slot)
    inventory.set_description(invid, slot,
        dirt >= 70 and "Очень грязная" or dirt >= 40 and "Грязная" or "Чистая")
end

function gear.soil(invid, slot, amount)
    if inventory.get(invid, slot) == 0 then
        return
    end
    inventory.set_data(invid, slot, "dirt", math.min(100, gear.dirt(invid, slot) + amount))
    describe(invid, slot)
end

function gear.soil_all(state, amount)
    local invid = gear.inventory(state)
    for slot = 0, INDEX.feet do
        gear.soil(invid, slot, amount)
    end
end

function gear.dirty_count(state)
    local invid = gear.inventory(state)
    local n = 0
    for slot = 0, INDEX.feet do
        if inventory.get(invid, slot) ~= 0 and gear.dirt(invid, slot) >= 40 then
            n = n + 1
        end
    end
    return n
end

function gear.wash(invid, slot)
    if not prop(inventory.get(invid, slot), "zomboid:slot") then
        return false
    end
    inventory.set_data(invid, slot, "dirt", 0)
    describe(invid, slot)
    return true
end

local function pick_part()
    local r = math.random()
    for _, p in ipairs(PARTS) do
        r = r - p[2]
        if r <= 0 then
            return p[1]
        end
    end
    return "torso"
end

local function covers(slot_name, part)
    for _, p in ipairs(COVERS[slot_name]) do
        if p == part then
            return true
        end
    end
    return false
end

-- Returns caption of the clothing that stopped the wound, caption of torn clothing, and whether the wound sits under dirty clothes
function gear.absorb(state, kind)
    local invid = gear.inventory(state)
    local part = pick_part()
    local dirty = false
    for _, slot_name in ipairs(OUTER_FIRST) do
        local slot = INDEX[slot_name]
        local itemid = inventory.get(invid, slot)
        if itemid ~= 0 and covers(slot_name, part) then
            local caption = item.caption(itemid)
            local chance = (prop(itemid, "zomboid:protection") or 0) * (kind == "bite" and 0.5 or 1.0)
            local blocked = math.random() < chance
            for _ = 1, blocked and (kind == "bite" and 4 or 2) or 1 do
                inventory.use(invid, slot)
            end
            local torn = inventory.get(invid, slot) == 0 and caption or nil
            if blocked then
                return caption, torn, false
            end
            gear.soil(invid, slot, 15)
            dirty = dirty or gear.dirt(invid, slot) >= 40
            if torn then
                return nil, torn, dirty
            end
        end
    end
    return nil, nil, dirty
end

local function contents_weight(contents)
    local total = 0
    for _, e in ipairs(contents or {}) do
        total = total + gear.weight(item.index(e[1]), e[3]) * e[2]
    end
    return total
end

function gear.weight(itemid, data, worn)
    local own = prop(itemid, "zomboid:weight") or gear.DEFAULT_WEIGHT
    if data and data.contents then
        local k = worn and (1 - (prop(itemid, "zomboid:weight-reduction") or 0)) or 1
        own = own + contents_weight(data.contents) * k
    end
    return own
end

function gear.load(pid, state)
    local total = 0
    local invid = player.get_inventory(pid)
    for slot = 0, inventory.size(invid) - 1 do
        local itemid, count = inventory.get(invid, slot)
        if itemid ~= 0 then
            total = total + gear.weight(itemid, inventory.get_all_data(invid, slot)) * count
        end
    end
    local ginv = gear.inventory(state)
    for slot = 0, #gear.SLOTS - 1 do
        local itemid = inventory.get(ginv, slot)
        if itemid ~= 0 then
            total = total + gear.weight(itemid, inventory.get_all_data(ginv, slot), true)
        end
    end
    return total
end

function gear.capacity(state)
    return gear.CAPACITY * traits.mul(state, "carry")
end

-- Backpack contents live in the worn bag's item data; the pack inventory is a temporary view of them
function gear.open_pack(state)
    local bag, ginv, slot = gear.worn(state, "back")
    local size = prop(bag, "zomboid:slots")
    if not size then
        return nil
    end
    local view = inventory.create(size)
    for i, e in ipairs(inventory.get_data(ginv, slot, "contents") or {}) do
        local itemid = item.index(e[1])
        if itemid and i <= size then
            inventory.set(view, i - 1, itemid, e[2], e[3])
        end
    end
    return view
end

function gear.sync_pack(state, view, pid)
    local bag, ginv, slot = gear.worn(state, "back")
    local playerinv = player.get_inventory(pid)
    local contents = {}
    for s = 0, inventory.size(view) - 1 do
        local itemid, count = inventory.get(view, s)
        if itemid ~= 0 and prop(itemid, "zomboid:slots") then
            inventory.move(view, s, playerinv)
            itemid, count = inventory.get(view, s)
        end
        if itemid ~= 0 then
            table.insert(contents, {item.name(itemid), count, inventory.get_all_data(view, s)})
        end
    end
    if prop(bag, "zomboid:slots") then
        inventory.set_data(ginv, slot, "contents", contents)
    end
end

return gear
