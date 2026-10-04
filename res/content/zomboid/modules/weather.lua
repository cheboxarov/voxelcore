local clock = require "zomboid:clock"
local survival = require "zomboid:survival"
local vitals = require "zomboid:vitals"

local weather = {
    raining = false,
    next_change = nil,
    BARREL_CAPACITY = 40,
    BARREL_FILL_PER_HOUR = 4,
    barrels = {},
}

local tick = 0
local last_hours
local shown

function weather.is_raining()
    return weather.raining
end

function weather.sky_open(x, y, z)
    for yy = y + 1, y + 48 do
        if block.get(x, yy, z) > 0 then
            return false
        end
    end
    return true
end

function weather.is_wet(x, y, z)
    return weather.raining and weather.sky_open(math.floor(x), math.floor(y + 1), math.floor(z))
end

local function schedule()
    local hours = weather.raining and (2 + math.random() * 6) or (8 + math.random() * 22)
    weather.next_change = clock.hours + hours
end

function weather.set_raining(raining)
    if weather.raining == raining then
        return
    end
    weather.raining = raining
    vitals.rain = raining and 1 or 0
    schedule()
    for _, pid in ipairs(player.get_all()) do
        survival.notify(pid, raining and "Начался дождь" or "Дождь закончился", "#90b0d0")
    end
    events.emit("zomboid:weather", raining)
end

local function show()
    if not gfx or not gfx.weather or shown == weather.raining then
        return
    end
    shown = weather.raining
    local name = weather.raining and "rain" or "clear"
    local path = file.find("presets/weather/" .. name .. ".json")
    if path then
        gfx.weather.change(json.parse(file.read(path)), 15, name)
    end
end

function weather.track_barrel(x, y, z)
    weather.barrels[x .. ":" .. y .. ":" .. z] = {x, y, z}
end

function weather.untrack_barrel(x, y, z)
    weather.barrels[x .. ":" .. y .. ":" .. z] = nil
end

local function fill_barrels(dh)
    for k, b in pairs(weather.barrels) do
        local x, y, z = b[1], b[2], b[3]
        if block.name(block.get(x, y, z)) ~= "zomboid:rain_barrel" then
            weather.barrels[k] = nil
        elseif weather.sky_open(x, y, z) then
            local water = block.get_field(x, y, z, "water") or 0
            block.set_field(x, y, z, "water", math.min(weather.BARREL_CAPACITY, water + dh * weather.BARREL_FILL_PER_HOUR))
        end
    end
end

function weather.tick()
    tick = tick + 1
    show()
    if tick % 40 ~= 0 then
        return
    end
    if weather.next_change == nil then
        schedule()
    end
    local dh = last_hours and math.max(0, clock.hours - last_hours) or 0
    last_hours = clock.hours
    if weather.raining and dh > 0 then
        fill_barrels(math.max(0, math.min(dh, weather.next_change - (clock.hours - dh))))
    end
    if clock.hours >= weather.next_change then
        weather.set_raining(not weather.raining)
    end
end

function weather.serialize()
    return {raining = weather.raining, next_change = weather.next_change}
end

function weather.deserialize(data)
    weather.raining = data and data.raining or false
    vitals.rain = weather.raining and 1 or 0
    weather.next_change = data and data.next_change
    shown = nil
    last_hours = nil
end

return weather
