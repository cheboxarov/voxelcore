local sandbox = require "zomboid:sandbox"

local choice = {}

local function caption(opt)
    for _, v in ipairs(opt.values) do
        if v[1] == choice[opt.key] then
            return v[2]
        end
    end
    return tostring(choice[opt.key])
end

local function refresh()
    local list = document.options
    list:clear()
    for i, opt in ipairs(sandbox.OPTIONS) do
        list:add(string.format(
            "<button onclick='cycle(%d)' padding='6' text-align='left' size='428,30'>%s: %s</button>",
            i, opt.title, caption(opt)))
    end
end

function cycle(index)
    local opt = sandbox.OPTIONS[index]
    local next = 1
    for i, v in ipairs(opt.values) do
        if v[1] == choice[opt.key] then
            next = i % #opt.values + 1
        end
    end
    choice[opt.key] = opt.values[next][1]
    refresh()
end

function confirm()
    sandbox.save(choice)
    choice = {}
    hud.close("zomboid:sandbox")
end

function on_open()
    if next(choice) == nil then
        for _, opt in ipairs(sandbox.OPTIONS) do
            choice[opt.key] = sandbox.get(opt.key)
        end
    end
    world.set_day_time_speed(0)
    refresh()
end
