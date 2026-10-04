local radio = require "zomboid:radio"
local power = require "zomboid:power"
local clock = require "zomboid:clock"
local survival = require "zomboid:survival"

function on_interact(x, y, z, pid)
    if not power.has_power(x, y, z) then
        survival.notify(pid, "Телевизор не включается: нет электричества")
        return true
    end
    survival.notify(pid, radio.broadcast(clock.hours, true) or "ТВ: на всех каналах сетка настройки и писк",
        "#c0d8ff")
    return true
end
