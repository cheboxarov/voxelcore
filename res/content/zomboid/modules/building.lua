local inv = require "zomboid:inv"
local survival = require "zomboid:survival"
local crafting = require "zomboid:crafting"
local zombies = require "zomboid:zombies"
local skills = require "zomboid:skills"

local building = {}

local HAMMER = {"zomboid:hammer"}

building.RECIPES = {
    {
        title = "Дощатая стена (2 шт.)",
        result = {"zomboid:plank_wall.item", 2},
        need = {{"zomboid:plank", 3}, {"zomboid:nails", 4}},
        tools = HAMMER, xp = 3,
    },
    {
        title = "Калитка",
        result = {"zomboid:wooden_gate.item", 1},
        need = {{"zomboid:plank", 4}, {"zomboid:nails", 6}},
        tools = HAMMER, xp = 5,
    },
    {
        title = "Частокол (2 шт.)",
        result = {"zomboid:palisade.item", 2},
        need = {{"base:wood.item", 2}, {"zomboid:nails", 2}},
        tools = HAMMER, xp = 3,
    },
    {
        title = "Лестница (2 шт.)",
        result = {"zomboid:ladder.item", 2},
        need = {{"zomboid:plank", 3}, {"zomboid:nails", 4}},
        tools = HAMMER, xp = 3,
    },
    {
        title = "Дощатый настил (4 шт.)",
        result = {"zomboid:wood_floor.item", 4},
        need = {{"zomboid:plank", 2}, {"zomboid:nails", 2}},
        tools = HAMMER, xp = 2,
    },
    {
        title = "Бочка для дождевой воды",
        result = {"zomboid:rain_barrel.item", 1},
        need = {{"zomboid:plank", 5}, {"zomboid:nails", 6}},
        tools = HAMMER, xp = 4,
    },
}

function building.build(pid, index)
    local recipe = building.RECIPES[index]
    local invid = player.get_inventory(pid)
    if recipe == nil or not crafting.can_craft(invid, recipe) then
        survival.notify(pid, "Нужен молоток и материалы", "#ff9050")
        return false
    end
    for _, need in ipairs(recipe.need) do
        inv.take(invid, need[1], need[2])
    end
    inv.give(pid, recipe.result[1], recipe.result[2])
    skills.add_xp(pid, "carpentry", recipe.xp)
    local x, y, z = player.get_pos(pid)
    if vc.is_client() then
        audio.play_sound("world/hammer", x, y, z, 1.0, 0.9 + math.random() * 0.2)
    end
    zombies.noise({x, y, z}, 16, pid)
    survival.notify(pid, "Сколочено: " .. recipe.title .. ". ПКМ - поставить", "#90e090")
    return true
end

local function on_ladder(x, y, z)
    for dy = 0, 1 do
        local id = block.get(math.floor(x), math.floor(y + dy), math.floor(z))
        if id > 0 and block.has_tag(id, "zomboid:ladder") then
            return true
        end
    end
    return false
end

function building.climb(pid)
    local x, y, z = player.get_pos(pid)
    if not on_ladder(x, y - 0.9, z) then
        return
    end
    local vx, vy, vz = player.get_vel(pid)
    local _, pitch = player.get_rot(pid)
    if pitch > 15 then
        vy = 3.5
    elseif pitch < -25 then
        vy = -2.5
    else
        vy = math.max(vy, 0)
    end
    player.set_vel(pid, vx, vy, vz)
end

return building
