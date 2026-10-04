local traits = require "zomboid:traits"
local zombies = require "zomboid:zombies"
local inv = require "zomboid:inv"

local skills = {
    LIST = {"melee", "carpentry", "cooking", "first_aid", "sneaking"},
    TITLES = {
        melee = "Ближний бой",
        carpentry = "Плотницкое дело",
        cooking = "Кулинария",
        first_aid = "Первая помощь",
        sneaking = "Скрытность",
    },
    MAX_LEVEL = 10,
    THRESHOLDS = {75, 225, 525, 1000, 1700, 2600, 3700, 5000, 6500, 8200},
    EFFECTS = {
        melee_damage = {skill = "melee", per_level = 0.06, title = "Урон"},
        melee_stamina = {skill = "melee", per_level = -0.04, title = "Расход выносливости на удар"},
        barricade_hp = {skill = "carpentry", per_level = 0.1, title = "Прочность баррикад"},
        hammer_noise = {skill = "carpentry", per_level = -0.05, title = "Шум молотка"},
        food_value = {skill = "cooking", per_level = 0.05, title = "Сытость от еды"},
        food_poison = {skill = "cooking", per_level = -0.08, title = "Отравление несвежим"},
        treat_heal = {skill = "first_aid", per_level = 0.01, title = "Лечение при перевязке"},
        noise = {skill = "sneaking", per_level = -0.06, title = "Шум шагов"},
        sight = {skill = "sneaking", per_level = -0.05, title = "Заметность вприсядку"},
    },
    BOOKS = {
        {min = 0, max = 4, mult = 3.0},
        {min = 5, max = 9, mult = 5.0},
    },
    READ_HOURS = 1.5,
}

local function survival()
    return require "zomboid:survival"
end

local function xp_table(state)
    state.skills = state.skills or {}
    return state.skills
end

local function level_for(xp)
    local level = 0
    while level < skills.MAX_LEVEL and xp >= skills.THRESHOLDS[level + 1] do
        level = level + 1
    end
    return level
end

local function check_skill(skill)
    if skills.TITLES[skill] == nil then
        error("unknown skill: " .. tostring(skill))
    end
end

function skills.xp(pid, skill)
    check_skill(skill)
    return xp_table(survival().get(pid))[skill] or 0
end

function skills.level(pid, skill)
    return level_for(skills.xp(pid, skill))
end

function skills.progress(pid, skill)
    local xp = skills.xp(pid, skill)
    local level = level_for(xp)
    if level >= skills.MAX_LEVEL then
        return 1.0
    end
    local from = skills.THRESHOLDS[level] or 0
    return (xp - from) / (skills.THRESHOLDS[level + 1] - from)
end

function skills.set_level(pid, skill, level)
    check_skill(skill)
    level = math.max(0, math.min(skills.MAX_LEVEL, level))
    xp_table(survival().get(pid))[skill] = skills.THRESHOLDS[level] or 0
end

function skills.book_mult(pid, skill)
    local state = survival().get(pid)
    local level = skills.level(pid, skill)
    local mult = 1.0
    for volume, book in ipairs(skills.BOOKS) do
        if (state.books or {})[skill .. "_" .. volume] and level >= book.min and level <= book.max then
            mult = math.max(mult, book.mult)
        end
    end
    return mult
end

function skills.xp_mult(pid, skill)
    return skills.book_mult(pid, skill) * traits.mul(survival().get(pid), "xp")
end

function skills.add_xp(pid, skill, amount)
    check_skill(skill)
    local state = survival().get(pid)
    if state.dead then
        return 0
    end
    local xp = xp_table(state)
    local before = level_for(xp[skill] or 0)
    local gain = amount * skills.xp_mult(pid, skill)
    xp[skill] = math.min(skills.THRESHOLDS[skills.MAX_LEVEL], (xp[skill] or 0) + gain)
    local after = level_for(xp[skill])
    if after > before then
        survival().notify(pid, string.format("%s: уровень %d", skills.TITLES[skill], after), "#ffd070")
    end
    return gain
end

function skills.mul(pid, key)
    local state = survival().get(pid)
    local effect = skills.EFFECTS[key]
    local m = traits.mul(state, key)
    if effect then
        m = m * math.max(0.05, 1 + effect.per_level * level_for(xp_table(state)[effect.skill] or 0))
    end
    return m
end

function skills.book_of(itemid)
    local props = itemid ~= 0 and item.properties[itemid]
    local skill = props and props["zomboid:skill-book"]
    if skill == nil then
        return nil
    end
    local volume = props["zomboid:book-volume"] or 1
    return {skill = skill, volume = volume, key = skill .. "_" .. volume}
end

function skills.toggle_reading(pid)
    local itemid = inv.held(pid)
    local book = skills.book_of(itemid)
    if book == nil then
        return false
    end
    local S = survival()
    local state = S.get(pid)
    state.books = state.books or {}
    if state.reading then
        state.reading = nil
        S.notify(pid, "Вы отложили книгу")
    elseif state.books[book.key] then
        S.notify(pid, "Вы уже прочитали эту книгу")
    elseif zombies.count_near({player.get_pos(pid)}, 10) > 0 then
        S.notify(pid, "Не до чтения: рядом зомби", "#ff9050")
    else
        state.reading = {item = item.name(itemid)}
        S.notify(pid, "Вы начали читать: " .. item.caption(itemid))
    end
    return true
end

local function stop_reading(pid, state, text)
    state.reading = nil
    survival().notify(pid, text, "#ff9050")
end

local function update_reading(pid, state, dh)
    local itemid, _, invid, slot = inv.held(pid)
    if itemid == 0 or item.name(itemid) ~= state.reading.item then
        return stop_reading(pid, state, "Чтение прервано")
    end
    if state.sprinting or zombies.count_near({player.get_pos(pid)}, 8) > 0 then
        return stop_reading(pid, state, "Чтение прервано: рядом опасно")
    end
    local book = skills.book_of(itemid)
    local progress = (inventory.get_data(invid, slot, "read") or 0) + dh / skills.READ_HOURS
    if progress < 1 then
        inventory.set_data(invid, slot, "read", progress)
        state.reading.progress = progress
        return
    end
    inventory.set_data(invid, slot, "read", 1)
    inventory.set_description(invid, slot, "Прочитано")
    state.books[book.key] = true
    state.reading = nil
    local def = skills.BOOKS[book.volume]
    survival().notify(pid, string.format("Книга прочитана. %s: опыт x%g, пока качаете уровни %d-%d",
        skills.TITLES[book.skill], def.mult, def.min + 1, def.max + 1), "#ffd070")
end

function skills.update(pid, dh, dt)
    local state = survival().get(pid)
    if state.dead then
        return
    end
    if state.crouching and state.moving then
        local near = zombies.count_near({player.get_pos(pid)}, 15) > 0
        skills.add_xp(pid, "sneaking", dt * (near and 2.4 or 0.6))
    end
    if state.reading then
        update_reading(pid, state, dh)
    end
end

return skills
