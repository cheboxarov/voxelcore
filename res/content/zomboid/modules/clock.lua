local clock = {
    hours = 8.0,
    delta = 0.0,
    START_HOUR = 8.0,
}

local prev_daytime

function clock.reset(hours)
    clock.hours = hours or clock.START_HOUR
    clock.delta = 0.0
    prev_daytime = nil
    world.set_day_time((clock.hours % 24) / 24)
end

function clock.tick()
    local daytime = world.get_day_time()
    if prev_daytime == nil then
        prev_daytime = daytime
    end
    local delta = (daytime - prev_daytime) % 1.0
    prev_daytime = daytime
    clock.delta = delta * 24.0
    clock.hours = clock.hours + clock.delta
    return clock.delta
end

function clock.skip(hours)
    clock.hours = clock.hours + hours
    prev_daytime = (clock.hours % 24) / 24
    world.set_day_time(prev_daytime)
end

function clock.day()
    return math.floor(clock.hours / 24) + 1
end

function clock.hour()
    return clock.hours % 24
end

function clock.is_night()
    local h = clock.hour()
    return h >= 21 or h < 6
end

function clock.format(hours)
    hours = hours or clock.hours
    local h = math.floor(hours % 24)
    local m = math.floor((hours % 1) * 60)
    return string.format("%02d:%02d", h, m)
end

function clock.duration(hours)
    local days = math.floor(hours / 24)
    local h = math.floor(hours % 24)
    if days > 0 then
        return string.format("%d дн. %d ч.", days, h)
    end
    return string.format("%d ч. %d мин.", h, math.floor((hours % 1) * 60))
end

return clock
