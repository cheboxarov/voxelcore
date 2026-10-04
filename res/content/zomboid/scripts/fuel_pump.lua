local power = require "zomboid:power"
local fuel = require "zomboid:fuel"
local survival = require "zomboid:survival"

local RESERVE = 300

function on_interact(x, y, z, pid)
    if block.is_segment(x, y, z) then
        x, y, z = block.seek_origin(x, y, z)
    end
    local liters = fuel.held_can(pid)
    if liters == nil then
        survival.notify(pid, "Возьмите в руку канистру, чтобы набрать бензин")
        return true
    end
    if not power.has_power(x, y, z) then
        survival.notify(pid, "Колонка мертва: без электричества насос не качает. Нужен генератор рядом", "#ff9050")
        return true
    end
    if block.get_field(x, y, z, "tapped") ~= 1 then
        block.set_field(x, y, z, "tapped", 1)
        block.set_field(x, y, z, "fuel", RESERVE)
    end
    local reserve = block.get_field(x, y, z, "fuel") or 0
    local added = fuel.fill(pid, reserve)
    if added > 0 then
        block.set_field(x, y, z, "fuel", reserve - added)
        survival.notify(pid, string.format("Набрано %d л бензина", added), "#e0c060")
    else
        survival.notify(pid, reserve <= 0 and "Цистерна колонки пуста" or "Канистра уже полна")
    end
    return true
end
