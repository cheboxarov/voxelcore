local sandbox = {
    values = {},
    configured = false,
    DEFAULTS = {
        zombie_density = 1.0,
        zombie_speed = 1.0,
        day_minutes = 24,
        water_shutoff_day = 5,
        power_shutoff_day = 4,
        hunger_rate = 1.0,
    },
    OPTIONS = {
        {key = "zombie_density", title = "Плотность зомби",
            values = {{0.5, "Низкая"}, {1.0, "Обычная"}, {1.6, "Высокая"}, {2.5, "Безумная"}}},
        {key = "zombie_speed", title = "Скорость зомби",
            values = {{0.75, "Шаркающие"}, {1.0, "Обычные"}, {1.35, "Быстрые"}}},
        {key = "day_minutes", title = "Длина суток",
            values = {{12, "12 минут"}, {24, "24 минуты"}, {48, "48 минут"}, {96, "96 минут"}}},
        {key = "water_shutoff_day", title = "Отключение воды",
            values = {{2, "на 2-й день"}, {5, "на 5-й день"}, {10, "на 10-й день"}, {30, "на 30-й день"}}},
        {key = "power_shutoff_day", title = "Отключение света",
            values = {{2, "на 2-й день"}, {4, "на 4-й день"}, {8, "на 8-й день"}, {30, "на 30-й день"}}},
        {key = "hunger_rate", title = "Голод и жажда",
            values = {{0.6, "Медленно"}, {1.0, "Обычно"}, {1.5, "Быстро"}}},
    },
}

local function path()
    return pack.data_file("zomboid", "sandbox.json")
end

function sandbox.get(key)
    local default = sandbox.DEFAULTS[key]
    if default == nil then
        error("unknown sandbox option: " .. tostring(key))
    end
    local value = sandbox.values[key]
    if value == nil then
        return default
    end
    return value
end

function sandbox.apply()
    world.set_day_time_speed(24 / sandbox.get("day_minutes"))
end

function sandbox.load()
    local exists = file.exists(path())
    sandbox.values = exists and json.parse(file.read(path())) or {}
    sandbox.configured = exists
    sandbox.apply()
end

function sandbox.save(values)
    local clean = {}
    for key, value in pairs(values) do
        if sandbox.DEFAULTS[key] == nil or type(value) ~= "number" then
            error("invalid sandbox option: " .. tostring(key))
        end
        clean[key] = value
    end
    sandbox.values = clean
    sandbox.configured = true
    file.write(path(), json.tostring(clean, true))
    sandbox.apply()
end

return sandbox
