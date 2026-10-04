local weather = require "zomboid:weather"
local survival = require "zomboid:survival"
local water = require "zomboid:water"
local inv = require "zomboid:inv"

function on_block_present(x, y, z)
    weather.track_barrel(x, y, z)
end

function on_block_removed(x, y, z)
    weather.untrack_barrel(x, y, z)
end

function on_placed(x, y, z, pid)
    weather.track_barrel(x, y, z)
    if not weather.sky_open(x, y, z) then
        survival.notify(pid, "Над бочкой крыша - дождь в неё не попадёт")
    end
end

function on_interact(x, y, z, pid)
    local stored = block.get_field(x, y, z, "water") or 0
    if stored < 1 then
        survival.notify(pid, string.format("Бочка почти пуста (%.1f л). Дождитесь дождя", stored))
        return true
    end
    if water.is_container(inv.held(pid)) then
        if water.fill_held(pid, true) then
            block.set_field(x, y, z, "water", stored - 1)
        end
        return true
    end
    local state = survival.get(pid)
    if state.thirst >= 98 then
        survival.notify(pid, string.format("Вы не хотите пить. В бочке %.0f л", stored))
        return true
    end
    survival.eat(pid, 0, 30)
    block.set_field(x, y, z, "water", stored - 1)
    survival.notify(pid, string.format("Вы напились дождевой воды. Осталось %.0f л", stored - 1), "#90c0ff")
    return true
end
