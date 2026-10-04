local survival = require "zomboid:survival"
local clock = require "zomboid:clock"
local water = require "zomboid:water"
local inv = require "zomboid:inv"

function on_interact(x, y, z, pid)
    if clock.day() >= survival.WATER_SHUTOFF_DAY then
        survival.notify(pid, "Из крана не течёт ни капли. Водоснабжение отключено")
        return true
    end
    local itemid = inv.held(pid)
    if water.is_container(itemid) then
        water.fill_held(pid, true)
        return true
    end
    local state = survival.get(pid)
    if state.thirst >= 98 then
        survival.notify(pid, "Вы не хотите пить")
    else
        survival.eat(pid, 0, 30)
        survival.notify(pid, "Вы напились из-под крана", "#90c0ff")
    end
    return true
end
