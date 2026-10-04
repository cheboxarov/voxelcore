local inv = require "zomboid:inv"
local zombies = require "zomboid:zombies"

local barricade = {
    HP_PER_PLANK = 25,
    MAX_PLANKS = 4,
    DOOR_HP = 45,
}

local hp_cache = {}

local function key(x, y, z)
    return x .. ":" .. y .. ":" .. z
end

local function sound(name, x, y, z, volume)
    if vc.is_client() then
        audio.play_sound(name, x + 0.5, y + 0.5, z + 0.5, volume or 1.0, 0.9 + math.random() * 0.2)
    end
end

local function origin(x, y, z)
    if block.is_segment(x, y, z) then
        return block.seek_origin(x, y, z)
    end
    return x, y, z
end

function barricade.is_target(id)
    local name = block.name(id)
    return block.has_tag(id, "zomboid:window") or block.has_tag(id, "zomboid:barricade") or name == "base:wooden_door"
end

function barricade.add(pid, x, y, z)
    local id = block.get(x, y, z)
    if not barricade.is_target(id) then
        return false, "Здесь нечего заколачивать"
    end
    local invid = player.get_inventory(pid)
    if inv.count(invid, "zomboid:plank") < 1 or inv.count(invid, "zomboid:nails") < 2 then
        return false, "Нужна доска и 2 гвоздя"
    end
    local name = block.name(id)
    x, y, z = origin(x, y, z)
    if name == "zomboid:window" or name == "zomboid:window_broken" then
        block.set(x, y, z, block.index("zomboid:barricade"), 0)
        block.set_field(x, y, z, "glass", name == "zomboid:window" and 1 or 0)
        block.set_field(x, y, z, "hp", barricade.HP_PER_PLANK)
    elseif name == "base:wooden_door" then
        local rot = block.get_rotation(x, y, z)
        block.set(x, y, z, block.index("zomboid:door_barricade"), block.compose_state({rot, 0, 0}))
        block.set_field(x, y, z, "hp", barricade.HP_PER_PLANK)
    else
        local planks = block.get_variant(x, y, z) + 1
        if planks >= barricade.MAX_PLANKS then
            return false, "Больше досок не поместится"
        end
        block.set_variant(x, y, z, planks)
        block.set_field(x, y, z, "hp", math.min(barricade.HP_PER_PLANK * (planks + 1),
            (block.get_field(x, y, z, "hp") or 0) + barricade.HP_PER_PLANK))
    end
    inv.take(invid, "zomboid:plank", 1)
    inv.take(invid, "zomboid:nails", 2)
    sound("world/hammer", x, y, z)
    zombies.noise({x, y, z}, 16, pid)
    return true
end

function barricade.remove(pid, x, y, z)
    local id = block.get(x, y, z)
    if not block.has_tag(id, "zomboid:barricade") then
        return false
    end
    x, y, z = origin(x, y, z)
    local planks = block.get_variant(x, y, z)
    if planks > 0 then
        block.set_variant(x, y, z, planks - 1)
        block.set_field(x, y, z, "hp", math.min(block.get_field(x, y, z, "hp") or 0, barricade.HP_PER_PLANK * planks))
    else
        barricade.restore(x, y, z)
    end
    inv.give(pid, "zomboid:plank", 1)
    sound("world/hammer", x, y, z, 0.6)
    return true
end

function barricade.restore(x, y, z)
    local name = block.name(block.get(x, y, z))
    if name == "zomboid:door_barricade" then
        local rot = block.get_rotation(x, y, z)
        block.set(x, y, z, 0, 0)
        block.set(x, y, z, block.index("base:wooden_door"), block.compose_state({rot, 0, 0}))
    else
        local glass = block.get_field(x, y, z, "glass") == 1
        block.set(x, y, z, block.index(glass and "zomboid:window" or "zomboid:window_broken"), 0)
    end
end

function barricade.bash(x, y, z, amount)
    local id = block.get(x, y, z)
    if id <= 0 then
        return true
    end
    local name = block.name(id)
    x, y, z = origin(x, y, z)
    sound("world/bash", x, y, z, 0.8)
    if block.has_tag(id, "zomboid:barricade") then
        local hp = (block.get_field(x, y, z, "hp") or barricade.HP_PER_PLANK) - amount
        if hp <= 0 then
            if name == "zomboid:door_barricade" then
                block.set(x, y, z, 0, 0)
            else
                block.set(x, y, z, block.index("zomboid:window_broken"), 0)
            end
            sound("world/glass_break", x, y, z)
            zombies.noise({x, y, z}, 14)
            return true
        end
        block.set_field(x, y, z, "hp", hp)
        local planks = math.max(0, math.ceil(hp / barricade.HP_PER_PLANK) - 1)
        if planks < block.get_variant(x, y, z) then
            block.set_variant(x, y, z, planks)
        end
        return false
    end
    local k = key(x, y, z)
    local hp = hp_cache[k]
    if hp == nil then
        hp = name == "base:wooden_door" and barricade.DOOR_HP
            or (block.properties[id]["zomboid:bash-hp"] or 10)
    end
    hp = hp - amount
    if hp > 0 then
        hp_cache[k] = hp
        return false
    end
    hp_cache[k] = nil
    if block.has_tag(id, "zomboid:glass") then
        block.set(x, y, z, block.index("zomboid:window_broken"), 0)
        sound("world/glass_break", x, y, z)
        zombies.noise({x, y, z}, 18)
    else
        block.set(x, y, z, 0, 0)
        zombies.noise({x, y, z}, 12)
    end
    return true
end

function barricade.is_bashable(id)
    return id > 0 and (block.has_tag(id, "zomboid:bashable") or block.name(id) == "base:wooden_door")
end

return barricade
