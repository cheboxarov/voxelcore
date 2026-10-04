local inv = require "zomboid:inv"
local survival = require "zomboid:survival"
local skills = require "zomboid:skills"
local water = require "zomboid:water"
local heat = require "zomboid:heat"

local crafting = {}

crafting.RECIPES = {
    {
        title = "Бинт",
        result = {"zomboid:bandage", 1},
        need = {{"zomboid:rag", 2}},
        xp = {"first_aid", 5},
    },
    {
        title = "Бита с гвоздями",
        result = {"zomboid:spiked_bat", 1},
        need = {{"zomboid:bat", 1}, {"zomboid:nails", 5}},
        tools = {"zomboid:hammer"},
        xp = {"carpentry", 20},
    },
    {
        title = "Копьё",
        result = {"zomboid:spear", 1},
        need = {{"zomboid:plank", 2}},
        tools = {"zomboid:knife"},
    },
    {
        title = "Доски из бревна",
        result = {"zomboid:plank", 3},
        need = {{"base:wood.item", 1}},
        tools = {"zomboid:axe"},
        xp = {"carpentry", 10},
    },
    {
        title = "Костёр",
        result = {"zomboid:campfire.item", 1},
        need = {{"zomboid:plank", 4}},
        uses = {"zomboid:matches"},
    },
    {
        title = "Факел (2 шт.)",
        result = {"base:torch.item", 2},
        need = {{"zomboid:plank", 1}, {"zomboid:rag", 1}},
        uses = {"zomboid:matches"},
    },
    {
        title = "Ящик для хранения",
        result = {"zomboid:crate.item", 1},
        need = {{"zomboid:plank", 6}, {"zomboid:nails", 4}},
        tools = {"zomboid:hammer"},
        xp = {"carpentry", 25},
    },
    {
        title = "Сирена-ловушка",
        result = {"zomboid:siren.item", 1},
        need = {{"zomboid:alarm_clock.item", 1}, {"zomboid:flashlight", 1}, {"zomboid:nails", 2}},
        tools = {"zomboid:hammer"},
    },
    {
        title = "Палки (2 шт.)",
        result = {"zomboid:stick", 2},
        need = {{"zomboid:plank", 1}},
    },
    {
        title = "Шина",
        result = {"zomboid:splint", 1},
        need = {{"zomboid:stick", 1}, {"zomboid:rag", 1}},
        xp = {"first_aid", 5},
    },
    {
        title = "Прокипятить грязный бинт",
        result = {"zomboid:bandage", 1},
        need = {{"zomboid:dirty_bandage", 1}},
        tools = {"zomboid:cooking_pot"},
        water = true,
        heat = true,
        xp = {"first_aid", 3},
    },
    {
        title = "Прокипятить грязную тряпку",
        result = {"zomboid:rag", 1},
        need = {{"zomboid:dirty_rag", 1}},
        tools = {"zomboid:cooking_pot"},
        water = true,
        heat = true,
        xp = {"first_aid", 3},
    },
    {
        title = "Жареное мясо",
        result = {"zomboid:cooked_meat", 1},
        need = {{"zomboid:raw_meat", 1}},
        tools = {"zomboid:frying_pan"},
        heat = true,
        xp = {"cooking", 10},
    },
    {
        title = "Овощной суп",
        result = {"zomboid:soup", 1},
        need = {{"zomboid:potato", 1}, {"zomboid:carrot", 1}},
        tools = {"zomboid:cooking_pot"},
        water = true,
        heat = true,
        xp = {"cooking", 15},
    },
    {
        title = "Рагу с мясом",
        result = {"zomboid:stew", 1},
        need = {{"zomboid:raw_meat", 1}, {"zomboid:potato", 1}, {"zomboid:carrot", 1}},
        tools = {"zomboid:cooking_pot"},
        water = true,
        heat = true,
        xp = {"cooking", 20},
    },
}

local CAPTIONS = {
    ["base:wood.item"] = "Бревно",
    ["base:torch.item"] = "Факел",
}

local function caption(name)
    return CAPTIONS[name] or item.caption(item.index(name))
end

local function names(list)
    local out = {}
    for _, entry in ipairs(list or {}) do
        local text = caption(type(entry) == "table" and entry[1] or entry)
        if type(entry) == "table" then
            text = text .. " x" .. entry[2]
        end
        table.insert(out, text)
    end
    return table.concat(out, ", ")
end

function crafting.describe(recipe)
    local parts = {names(recipe.need)}
    if recipe.tools then
        table.insert(parts, "инструмент: " .. names(recipe.tools))
    end
    if recipe.uses then
        table.insert(parts, "расходует: " .. names(recipe.uses))
    end
    if recipe.water then
        table.insert(parts, "глоток воды")
    end
    if recipe.heat then
        table.insert(parts, "нужен огонь рядом (костёр или плита)")
    end
    return table.concat(parts, "; ")
end

function crafting.can_craft(invid, recipe, pid)
    for _, need in ipairs(recipe.need) do
        if inv.count(invid, need[1]) < need[2] then
            return false
        end
    end
    for _, tool in ipairs(recipe.tools or {}) do
        if inv.count(invid, tool) < 1 then
            return false
        end
    end
    for _, used in ipairs(recipe.uses or {}) do
        if inv.count(invid, used) < 1 then
            return false
        end
    end
    if recipe.water and water.sip_slot(invid) == nil then
        return false
    end
    return not recipe.heat or (pid ~= nil and heat.near_player(pid))
end

function crafting.craft(pid, index)
    local recipe = crafting.RECIPES[index]
    local invid = player.get_inventory(pid)
    if recipe == nil or not crafting.can_craft(invid, recipe, pid) then
        survival.notify(pid, "Не хватает материалов", "#ff9050")
        return false
    end
    for _, need in ipairs(recipe.need) do
        inv.take(invid, need[1], need[2])
    end
    for _, used in ipairs(recipe.uses or {}) do
        local slot = inventory.find_by_item(invid, item.index(used))
        if slot then
            inventory.use(invid, slot)
        end
    end
    if recipe.water then
        water.take_sip(invid)
    end
    inv.give(pid, recipe.result[1], recipe.result[2])
    if recipe.xp then
        skills.add_xp(pid, recipe.xp[1], recipe.xp[2])
    end
    survival.notify(pid, "Создано: " .. recipe.title, "#90e090")
    return true
end

return crafting
