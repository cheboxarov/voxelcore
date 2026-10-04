local survival = require "zomboid:survival"
local clock = require "zomboid:clock"
local zombies = require "zomboid:zombies"

local BAR_WIDTH = 220

local function bar(id, value, max)
    document[id].size = {math.max(0, BAR_WIDTH * value / (max or 100)), document[id].size[2]}
end

local function status_lines(state)
    local lines = {}
    local bleeding = survival.bleeding_count(state)
    if bleeding > 0 then
        table.insert(lines, "[#ff5050]Кровотечение: " .. bleeding)
    end
    local bandaged = 0
    for _, w in ipairs(state.wounds) do
        if w.bandaged then bandaged = bandaged + 1 end
    end
    if bandaged > 0 then
        table.insert(lines, "[#d0d0d0]Перевязанные раны: " .. bandaged)
    end
    if state.infection and state.infection > survival.INFECTION_HOURS * 0.25 then
        table.insert(lines, "[#ff8040]Заражение крови")
    end
    if state.wound_infection then
        table.insert(lines, "[#e0c040]Воспаление раны")
    end
    if state.sickness > 40 then
        table.insert(lines, "[#c0d060]Тошнота")
    end
    if state.hunger < 20 then
        table.insert(lines, "[#e0a040]" .. (state.hunger <= 0 and "Истощение" or "Голод"))
    end
    if state.thirst < 20 then
        table.insert(lines, "[#60a0ff]" .. (state.thirst <= 0 and "Обезвоживание" or "Жажда"))
    end
    if state.energy < 20 then
        table.insert(lines, "[#a080e0]Усталость")
    end
    if state.pain > 0 then
        table.insert(lines, "[#a0e0a0]Обезболивающее")
    end
    table.insert(lines, "[#a0a0a0]Убито зомби: " .. (state.kills or 0))
    return table.concat(lines, "\n")
end

local function update()
    local pid = hud.get_player()
    local state = survival.get(pid)
    local h = clock.hour()
    local part = (h >= 21 or h < 6) and "[ночь]" or ""
    document.clock.text = string.format("День %d, %s %s", clock.day(), clock.format(), part)
    bar("bar_health", state.health)
    bar("bar_hunger", state.hunger)
    bar("bar_thirst", state.thirst)
    bar("bar_energy", state.energy)
    bar("bar_stamina", state.stamina)
    document.status.text = status_lines(state)

    local now = time.uptime()
    local lines = {}
    for _, m in ipairs(state.messages) do
        if now - m.time < 7 then
            table.insert(lines, "[" .. m.color .. "]" .. m.text)
        end
    end
    document.messages.text = table.concat(lines, "\n")

    local hurt = math.max(0, 1 - (now - (state.hurt or 0)) / 0.6)
    local low = state.health < 25 and (0.25 + 0.15 * math.sin(now * 5)) or 0
    document.hurt.color = {160, 0, 0, math.floor(math.max(hurt * 110, low * 255))}
    local dark = 0
    if h >= 21 or h < 6 then dark = 70 elseif h >= 19 then dark = (h - 19) * 35 elseif h < 7 then dark = (7 - h) * 70 end
    document.night.color = {0, 0, 16, math.floor(dark)}
end

function on_open()
    update()
    document.root:setInterval(100, update)
end
