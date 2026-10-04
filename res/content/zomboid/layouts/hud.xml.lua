local survival = require "zomboid:survival"
local clock = require "zomboid:clock"
local zombies = require "zomboid:zombies"
local sandbox = require "zomboid:sandbox"
local firearms = require "zomboid:firearms"
local combat = require "zomboid:combat"
local inv = require "zomboid:inv"
local vitals = require "zomboid:vitals"

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
    if state.reading then
        table.insert(lines, string.format("[#ffd070]Чтение: %d%%", math.floor((state.reading.progress or 0) * 100)))
    end
    vitals.status(state, lines)
    table.insert(lines, "[#a0a0a0]Выжито: " .. clock.duration(clock.hours - state.born))
    table.insert(lines, "[#a0a0a0]Убито зомби: " .. (state.kills or 0))
    return table.concat(lines, "\n"), #lines
end

local function combat_text(pid, state)
    local lines = {}
    local itemid, _, invid, slot = inv.held(pid)
    local gun = firearms.gun(itemid)
    if gun then
        table.insert(lines, string.format("[#e8d8a0]%s: %d/%d, запас %d", item.caption(itemid),
            firearms.loaded(invid, slot), gun.mag, inv.count(invid, gun.ammo)))
        if firearms.is_reloading(pid) then
            table.insert(lines, "[#ffb060]Перезарядка...")
        end
    end
    if state.crouching then
        table.insert(lines, "[#a0d0a0]Крадётесь")
    end
    if combat.is_grabbed(state) then
        table.insert(lines, "[#ff7050]Вас схватили! V - оттолкнуть")
    end
    return table.concat(lines, "\n")
end

local function update()
    local pid = hud.get_player()
    local state = survival.get(pid)
    if (state.setup or not sandbox.configured) and not state.dead and not hud.is_inventory_open()
            and not hud.is_paused() then
        hud.show_overlay(sandbox.configured and "zomboid:character" or "zomboid:sandbox", false)
    end
    local h = clock.hour()
    local part = (h >= 21 or h < 6) and "[ночь]" or ""
    document.clock.text = string.format("День %d, %s %s", clock.day(), clock.format(), part)
    bar("bar_health", state.health)
    bar("bar_hunger", state.hunger)
    bar("bar_thirst", state.thirst)
    bar("bar_energy", state.energy)
    bar("bar_stamina", state.stamina)
    local text, count = status_lines(state)
    if document.status.text ~= text then
        document.status.text = text
        document.status_box.size = {236, count * 24 + 6}
    end

    local now = time.uptime()
    local lines = {}
    for _, m in ipairs(state.messages) do
        if now - m.time < 7 then
            table.insert(lines, "[" .. m.color .. "]" .. m.text)
        end
    end
    document.messages.text = table.concat(lines, "\n")
    document.combat.text = combat_text(pid, state)

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
