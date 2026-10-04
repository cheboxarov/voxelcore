local noise = {
    marks = {},
    LOUD = 40,
}

function noise.emit(pos, radius, pid, duration)
    local now = time.uptime()
    for i = #noise.marks, 1, -1 do
        local m = noise.marks[i]
        if now - m.time > m.duration then
            table.remove(noise.marks, i)
        end
    end
    local mark = {
        pos = {pos[1], pos[2], pos[3]}, radius = radius, pid = pid, time = now, duration = duration or 3,
    }
    table.insert(noise.marks, mark)
    return mark
end

function noise.audibility(mark, pos, now)
    local age = (now or time.uptime()) - mark.time
    if age > mark.duration then
        return -1
    end
    local reach = mark.radius * (1 - 0.5 * age / mark.duration)
    return reach - vec3.distance(mark.pos, pos)
end

function noise.loudest(pos, since)
    local now = time.uptime()
    local best, best_value = nil, 0
    for _, m in ipairs(noise.marks) do
        if m.time > since then
            local value = noise.audibility(m, pos, now)
            if value > best_value then
                best, best_value = m, value
            end
        end
    end
    return best
end

function noise.loud_since(since)
    local out = {}
    for _, m in ipairs(noise.marks) do
        if m.time > since and m.radius >= noise.LOUD then
            table.insert(out, m)
        end
    end
    return out
end

return noise
