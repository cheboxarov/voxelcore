local clock = require "zomboid:clock"
local survival = require "zomboid:survival"
local weather = require "zomboid:weather"
local inv = require "zomboid:inv"

local farming = {
    GROW_HOURS = {carrot = 60, potato = 84},
    YIELD = {carrot = {2, 4}, potato = {2, 5}},
    WATER_PER_HOUR = 100 / 30,
    DRY_DEATH_HOURS = 48,
    STAGES = 3,
    DEAD = 4,
}

local DIGGABLE = {["base:grass_block"] = true, ["base:dirt"] = true}

function farming.dig(pid, x, y, z)
    if not DIGGABLE[block.name(block.get(x, y, z))] then
        return false
    end
    if block.get(x, y + 1, z) ~= 0 and not block.is_replaceable_at(x, y + 1, z) then
        survival.notify(pid, "Над землёй ничего не должно быть")
        return true
    end
    block.set(x, y + 1, z, 0, 0)
    block.set(x, y, z, block.index("zomboid:garden_bed"), 0)
    local _, _, invid, slot = inv.held(pid)
    inventory.use(invid, slot)
    survival.notify(pid, "Грядка готова. Посадите семена", "#a0d080")
    return true
end

function farming.plant(pid, x, y, z, kind)
    if block.name(block.get(x, y, z)) ~= "zomboid:garden_bed" then
        survival.notify(pid, "Семена сажают в грядку. Вскопайте её лопатой")
        return false
    end
    if block.get(x, y + 1, z) ~= 0 then
        survival.notify(pid, "Грядка уже занята")
        return false
    end
    block.set(x, y + 1, z, block.index("zomboid:crop_" .. kind), 0)
    block.set_field(x, y + 1, z, "water", 50)
    block.set_field(x, y + 1, z, "last", clock.hours)
    local _, _, invid, slot = inv.held(pid)
    inventory.decrement(invid, slot, 1)
    survival.notify(pid, "Посажено. Поливайте грядку, урожай через несколько дней", "#a0d080")
    return true
end

local function kind_of(x, y, z)
    return block.properties[block.get(x, y, z)]["zomboid:crop"]
end

function farming.update(x, y, z)
    local kind = kind_of(x, y, z)
    if kind == nil or block.get_variant(x, y, z) == farming.DEAD then
        return
    end
    if block.get_field(x, y, z, "last") == nil then
        block.set_field(x, y, z, "growth", farming.GROW_HOURS[kind])
        block.set_field(x, y, z, "water", 100)
    end
    local now = clock.hours
    local last = block.get_field(x, y, z, "last") or now
    local water = block.get_field(x, y, z, "water") or 0
    local growth = block.get_field(x, y, z, "growth") or 0
    local dry = block.get_field(x, y, z, "dry") or 0
    local rained = weather.raining and now or weather.started
    if rained and rained >= last - 0.01 and weather.sky_open(x, y, z) then
        growth = growth + rained - last
        last, water, dry = rained, 100, 0
    end
    local elapsed = math.max(0, now - last)
    block.set_field(x, y, z, "last", now)
    local wet = math.min(elapsed, water / farming.WATER_PER_HOUR)
    growth = growth + wet
    water = math.max(0, water - elapsed * farming.WATER_PER_HOUR)
    dry = water > 0 and 0 or dry + elapsed - wet
    block.set_field(x, y, z, "growth", growth)
    block.set_field(x, y, z, "water", water)
    block.set_field(x, y, z, "dry", dry)
    if dry > farming.DRY_DEATH_HOURS then
        block.set_variant(x, y, z, farming.DEAD)
        return
    end
    local stage = math.min(farming.STAGES, math.floor(growth / (farming.GROW_HOURS[kind] / farming.STAGES) + 1e-4))
    if stage ~= block.get_variant(x, y, z) then
        block.set_variant(x, y, z, stage)
    end
end

local function pour(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local name = item.name(itemid)
    if name ~= "zomboid:water_bottle" and name ~= "zomboid:dirty_water_bottle" then
        return false
    end
    if inventory.get_uses(invid, slot) <= 1 then
        inventory.set(invid, slot, item.index("zomboid:empty_bottle"), 1)
    else
        inventory.use(invid, slot)
    end
    return true
end

function farming.interact(pid, x, y, z)
    farming.update(x, y, z)
    local kind = kind_of(x, y, z)
    local stage = block.get_variant(x, y, z)
    if stage == farming.DEAD then
        block.set(x, y, z, 0, 0)
        survival.notify(pid, "Растение засохло. Вы выдернули его")
        return
    end
    if stage == farming.STAGES then
        local yield = farming.YIELD[kind]
        block.set(x, y, z, 0, 0)
        inv.give(pid, "zomboid:" .. kind, math.random(yield[1], yield[2]))
        inv.give(pid, "zomboid:seeds_" .. kind, math.random(1, 2))
        survival.notify(pid, "Урожай собран!", "#a0e080")
        return
    end
    if pour(pid) then
        block.set_field(x, y, z, "water", 100)
        survival.notify(pid, "Грядка полита", "#90c0ff")
        return
    end
    local water = block.get_field(x, y, z, "water") or 0
    survival.notify(pid, string.format("Растёт: стадия %d из %d, влага %d%%%s", stage + 1, farming.STAGES + 1,
        math.floor(water), water <= 0 and ". Нужно полить!" or ""))
end

return farming
