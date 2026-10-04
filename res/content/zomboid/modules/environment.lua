local power = require "zomboid:power"
local weather = require "zomboid:weather"
local building = require "zomboid:building"
local mapping = require "zomboid:mapping"
local radio = require "zomboid:radio"

local environment = {}

local SAVE_FILE = "environment.json"

local function path()
    return pack.data_file("zomboid", SAVE_FILE)
end

function environment.open()
    local data = file.exists(path()) and json.parse(file.read(path())) or {}
    weather.deserialize(data.weather)
end

function environment.save()
    file.write(path(), json.tostring({weather = weather.serialize()}, true))
end

function environment.tick()
    power.tick()
    weather.tick()
    radio.tick()
    mapping.tick()
    for _, pid in ipairs(player.get_all()) do
        building.climb(pid)
    end
end

return environment
