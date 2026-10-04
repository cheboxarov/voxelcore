local clock = require "zomboid:clock"
local survival = require "zomboid:survival"
local sandbox = require "zomboid:sandbox"
local fuel = require "zomboid:fuel"
local noise = require "zomboid:noise"

local power = {
    RADIUS = 14,
    GENERATOR_TANK = 10,
    LITERS_PER_HOUR = 0.5,
    NOISE_RADIUS = 22,
    generators = {},
    lamps = {},
}

local tick = 0
local grid_was_on

local function key(x, y, z)
    return x .. ":" .. y .. ":" .. z
end

function power.grid_on()
    return clock.day() < sandbox.get("power_shutoff_day")
end

function power.shutoff_hour()
    return (sandbox.get("power_shutoff_day") - 1) * 24
end

function power.is_running(x, y, z)
    return block.name(block.get(x, y, z)) == "zomboid:generator" and block.get_variant(x, y, z) == 1
end

function power.generator_near(x, y, z)
    for k, g in pairs(power.generators) do
        if not power.is_running(g[1], g[2], g[3]) then
            if block.name(block.get(g[1], g[2], g[3])) ~= "zomboid:generator" then
                power.generators[k] = nil
            end
        elseif vec3.distance(g, {x, y, z}) <= power.RADIUS then
            return true
        end
    end
    return false
end

function power.has_power(x, y, z)
    return power.grid_on() or power.generator_near(x, y, z)
end

function power.track_generator(x, y, z)
    local k = key(x, y, z)
    if power.generators[k] == nil then
        local last = block.get_field(x, y, z, "last") or 0
        power.generators[k] = {x, y, z, last = last > 0 and last or clock.hours}
    end
end

function power.untrack_generator(x, y, z)
    power.generators[key(x, y, z)] = nil
end

function power.refresh_lamp(x, y, z)
    if not world.is_open() then
        return
    end
    local name = block.name(block.get(x, y, z))
    if name ~= "zomboid:lamp" and name ~= "zomboid:lamp_off" then
        power.lamps[key(x, y, z)] = nil
        return
    end
    power.lamps[key(x, y, z)] = {x, y, z}
    local want = power.has_power(x, y, z) and "zomboid:lamp" or "zomboid:lamp_off"
    if name ~= want then
        block.set(x, y, z, block.index(want), block.get_states(x, y, z))
    end
end

function power.untrack_lamp(x, y, z)
    power.lamps[key(x, y, z)] = nil
end

function power.refresh_lamps()
    for _, p in pairs(power.lamps) do
        power.refresh_lamp(p[1], p[2], p[3])
    end
end

function power.set_running(x, y, z, on)
    block.set_variant(x, y, z, on and 1 or 0)
    power.track_generator(x, y, z)
    power.generators[key(x, y, z)].last = clock.hours
    block.set_field(x, y, z, "last", clock.hours)
    power.refresh_lamps()
end

function power.interact_generator(pid, x, y, z)
    local stored = block.get_field(x, y, z, "fuel") or 0
    local liters = fuel.held_can(pid)
    if liters then
        local poured = fuel.pour(pid, power.GENERATOR_TANK - stored)
        if poured <= 0 then
            survival.notify(pid, liters <= 0 and "Канистра пуста" or "Бак генератора полон")
        else
            block.set_field(x, y, z, "fuel", stored + poured)
            survival.notify(pid, string.format("Залито %.1f л. В баке %.1f / %d л", poured, stored + poured,
                power.GENERATOR_TANK), "#e0c060")
        end
        return
    end
    if power.is_running(x, y, z) then
        power.set_running(x, y, z, false)
        survival.notify(pid, string.format("Генератор выключен. В баке %.1f л", stored))
    elseif stored <= 0 then
        survival.notify(pid, "В генераторе нет бензина. Залейте его из канистры", "#ff9050")
    else
        power.set_running(x, y, z, true)
        survival.notify(pid, string.format("Генератор затарахтел. Бензина на %.0f ч. Его слышно издалека",
            stored / power.LITERS_PER_HOUR), "#e0c060")
    end
end

local function burn()
    for k, g in pairs(power.generators) do
        local x, y, z = g[1], g[2], g[3]
        local dh = math.max(0, clock.hours - g.last)
        g.last = clock.hours
        if block.name(block.get(x, y, z)) ~= "zomboid:generator" then
            power.generators[k] = nil
        elseif power.is_running(x, y, z) then
            local left = (block.get_field(x, y, z, "fuel") or 0) - dh * power.LITERS_PER_HOUR
            block.set_field(x, y, z, "fuel", math.max(0, left))
            block.set_field(x, y, z, "last", clock.hours)
            noise.emit({x + 0.5, y + 0.5, z + 0.5}, power.NOISE_RADIUS, nil, 3)
            if vc.is_client() then
                audio.play_sound("world/generator", x + 0.5, y + 0.5, z + 0.5, 0.8, 1.0)
            end
            if left <= 0 then
                power.set_running(x, y, z, false)
                local pid = player.get_nearest({x, y, z})
                if pid then
                    survival.notify(pid, "Генератор заглох: кончился бензин", "#ff9050")
                end
            end
        end
    end
end

function power.tick()
    tick = tick + 1
    if tick % 40 ~= 0 then
        return
    end
    burn()
    local grid = power.grid_on()
    if grid_was_on ~= nil and grid ~= grid_was_on and not grid then
        for _, pid in ipairs(player.get_all()) do
            survival.notify(pid, "Свет мигнул и погас. Электричества больше нет", "#ffb040")
        end
    end
    if grid ~= grid_was_on then
        grid_was_on = grid
        power.refresh_lamps()
    end
end

return power
