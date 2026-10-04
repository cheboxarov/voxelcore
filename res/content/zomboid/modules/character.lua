local survival = require "zomboid:survival"
local skills = require "zomboid:skills"
local traits = require "zomboid:traits"
local inv = require "zomboid:inv"
local sandbox = require "zomboid:sandbox"

local character = {}

character.PROFESSIONS = {
    {id = "unemployed", title = "Безработный", points = 8,
        text = "Ничего не умеет, зато есть очки на хорошие черты", skills = {}, items = {}},
    {id = "police", title = "Полицейский", points = 0,
        text = "Привык к дракам и к ночным патрулям", skills = {melee = 2, sneaking = 1, aiming = 2},
        items = {{"zomboid:bat", 1}, {"zomboid:flashlight", 1}, {"zomboid:bandage", 1}}},
    {id = "carpenter", title = "Плотник", points = 0,
        text = "Быстро заколачивает окна, баррикады выходят крепче", skills = {carpentry = 3, melee = 1},
        items = {{"zomboid:hammer", 1}, {"zomboid:nails", 12}, {"zomboid:plank", 3}}},
    {id = "chef", title = "Повар", points = 0,
        text = "Выжимает из еды больше и реже травится", skills = {cooking = 3, melee = 1},
        items = {{"zomboid:knife", 1}, {"zomboid:canned_beans", 2}, {"zomboid:apple", 2}}},
    {id = "doctor", title = "Врач", points = 0,
        text = "Перевязка сразу восстанавливает здоровье", skills = {first_aid = 3},
        items = {{"zomboid:bandage", 3}, {"zomboid:disinfectant", 1}, {"zomboid:painkillers", 1}}},
}

function character.profession(id)
    for _, prof in ipairs(character.PROFESSIONS) do
        if prof.id == id then
            return prof
        end
    end
    return nil
end

function character.balance(prof_id, trait_ids)
    local prof = character.profession(prof_id)
    if prof == nil then
        return nil, "Выберите профессию"
    end
    local points = prof.points
    for i, id in ipairs(trait_ids) do
        local def = traits.find(id)
        if def == nil then
            return nil, "Неизвестная черта: " .. tostring(id)
        end
        for j = 1, i - 1 do
            if trait_ids[j] == id then
                return nil, "Черта выбрана дважды: " .. def.title
            end
            if traits.conflict(trait_ids[j], id) then
                return nil, "Несовместимые черты: " .. traits.find(trait_ids[j]).title .. " и " .. def.title
            end
        end
        points = points - def.cost
    end
    if points < 0 then
        return points, "Не хватает очков: возьмите отрицательные черты"
    end
    return points
end

function character.apply(pid, prof_id, trait_ids)
    local state = survival.get(pid)
    if not state.setup then
        return false, "Персонаж уже создан"
    end
    local _, err = character.balance(prof_id, trait_ids)
    if err then
        return false, err
    end
    local prof = character.profession(prof_id)
    state.profession = prof.id
    state.traits = table.copy(trait_ids)
    for skill, level in pairs(prof.skills) do
        skills.set_level(pid, skill, level)
    end
    for _, id in ipairs(trait_ids) do
        for skill, bonus in pairs(traits.find(id).skills or {}) do
            skills.set_level(pid, skill, skills.level(pid, skill) + bonus)
        end
    end
    for _, entry in ipairs(prof.items) do
        inv.give(pid, entry[1], entry[2])
    end
    state.setup = nil
    sandbox.apply()
    survival.notify(pid, "Профессия: " .. prof.title .. ". K - навыки персонажа", "#ffe0a0")
    events.emit("zomboid:character_ready", pid)
    return true
end

return character
