local clock = require "zomboid:clock"
local town = require "zomboid:town"

local zombies = {
    registry = {},
    MAX = 34,
    SPAWN_MIN = 26,
    SPAWN_MAX = 52,
    DESPAWN_DISTANCE = 110,
    horde_day = 0,
    enabled = true,
}

function zombies.register(uid, component)
    zombies.registry[uid] = component
end

function zombies.unregister(uid)
    zombies.registry[uid] = nil
end

function zombies.count()
    return table.count_pairs(zombies.registry)
end

function zombies.count_near(pos, radius)
    local n = 0
    for _, z in pairs(zombies.registry) do
        if vec3.distance(z.get_pos(), pos) <= radius then
            n = n + 1
        end
    end
    return n
end

function zombies.nearest_distance(pos)
    local best = math.huge
    for _, z in pairs(zombies.registry) do
        best = math.min(best, vec3.distance(z.get_pos(), pos))
    end
    return best
end

-- Every zombie within radius hears the sound and goes to check it.
function zombies.noise(pos, radius, pid)
    for _, z in pairs(zombies.registry) do
        local d = vec3.distance(z.get_pos(), pos)
        if d <= radius then
            z.hear(pos, pid, d)
        end
    end
end

local water_id

-- Feet level of a free spot in the column or nil if the chunk is not loaded.
function zombies.find_ground(x, z, top)
    water_id = water_id or block.index("base:water")
    for y = top or 80, 8, -1 do
        local id = block.get(x, y, z)
        if id == -1 then
            return nil
        end
        if block.is_solid_at(x, y, z) then
            if block.is_solid_at(x, y + 1, z) or block.is_solid_at(x, y + 2, z) then
                return nil
            end
            if block.get(x, y + 1, z) == water_id then
                return nil
            end
            return y + 1
        end
    end
    return nil
end

function zombies.spawn(x, y, z, args)
    return entities.spawn("zomboid:zombie", {x + 0.5, y + 0.95, z + 0.5}, {zomboid__zombie = args or {}})
end

local function pick_spot(ppos, look, min_dist, max_dist, behind)
    for _ = 1, 8 do
        local angle = math.random() * math.pi * 2
        local dir = {math.cos(angle), math.sin(angle)}
        if not behind or dir[1] * look[1] + dir[2] * look[3] < 0.3 then
            local dist = min_dist + math.random() * (max_dist - min_dist)
            local x = math.floor(ppos[1] + dir[1] * dist)
            local z = math.floor(ppos[3] + dir[2] * dist)
            local kind = town.building_at(x, z)
            local y
            if kind == nil then
                y = zombies.find_ground(x, z)
            elseif math.random() < 0.35 then
                y = zombies.find_ground(x, z, town.GROUND + 3)
            end
            if y then
                return x, y, z
            end
        end
    end
    return nil
end

function zombies.target_population()
    local base = clock.is_night() and 16 or 8
    return math.min(zombies.MAX, base + (clock.day() - 1) * 2)
end

function zombies.spawn_horde(pid)
    local ppos = {player.get_pos(pid)}
    local size = math.min(22, 6 + clock.day() * 3)
    local angle = math.random() * math.pi * 2
    local cx = ppos[1] + math.cos(angle) * 48
    local cz = ppos[3] + math.sin(angle) * 48
    local spawned = 0
    for _ = 1, size * 3 do
        if spawned >= size or zombies.count() >= zombies.MAX + 12 then
            break
        end
        local x = math.floor(cx + (math.random() - 0.5) * 16)
        local z = math.floor(cz + (math.random() - 0.5) * 16)
        if town.building_at(x, z) == nil then
            local y = zombies.find_ground(x, z)
            if y then
                local e = zombies.spawn(x, y, z, {horde = true})
                local comp = e and e:get_component("zomboid:zombie")
                if comp then
                    comp.hear(ppos, pid, 0)
                end
                spawned = spawned + 1
            end
        end
    end
    return spawned
end

local tick_counter = 0

function zombies.tick(survival)
    tick_counter = tick_counter + 1
    if not zombies.enabled or tick_counter % 40 ~= 0 then
        return
    end
    local hour = clock.hour()
    for _, pid in ipairs(player.get_all()) do
        local state = survival.get(pid)
        if not state.dead then
            local ppos = {player.get_pos(pid)}
            if clock.day() >= 2 and hour >= 22 and zombies.horde_day < clock.day() then
                zombies.horde_day = clock.day()
                local n = zombies.spawn_horde(pid)
                if n > 0 then
                    survival.notify(pid, "Вдалеке раздаётся вой орды. Они идут сюда!", "#ff5040")
                end
            end
            local near = zombies.count_near(ppos, zombies.SPAWN_MAX + 20)
            if near < zombies.target_population() and zombies.count() < zombies.MAX then
                local look = player.get_dir(pid)
                local x, y, z = pick_spot(ppos, look, zombies.SPAWN_MIN, zombies.SPAWN_MAX, true)
                if x then
                    zombies.spawn(x, y, z, {})
                end
            end
        end
    end
end

return zombies
