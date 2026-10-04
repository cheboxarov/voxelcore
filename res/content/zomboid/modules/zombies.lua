local clock = require "zomboid:clock"
local town = require "zomboid:town"
local sandbox = require "zomboid:sandbox"
local noise = require "zomboid:noise"

local zombies = {
    registry = {},
    SPAWN_MIN = 26,
    SPAWN_MAX = 52,
    DESPAWN_DISTANCE = 110,
    horde_day = 0,
    enabled = true,
    KINDS = {
        normal = {hp = {55, 95}, half = 0.9, speed = 13.0, chase = 1.0, bash = 1.0, knockback = 1.0},
        crawler = {hp = {30, 50}, half = 0.3, speed = 7.0, chase = 1.0, bash = 0.6, knockback = 0.7, grab = true,
            hitbox = {0.6, 0.6, 0.6}},
        fat = {hp = {170, 230}, half = 0.97, speed = 9.0, chase = 1.0, bash = 2.5, knockback = 0.3, heavy = true,
            size = {1.3, 1.08, 1.3}},
        sprinter = {hp = {45, 75}, half = 0.94, speed = 13.0, chase = 2.1, bash = 1.0, knockback = 1.1,
            size = {0.92, 1.04, 0.92}, shirt = "sport"},
    },
}

function zombies.roll_kind()
    local r = math.random()
    local sprinters = clock.is_night() and 0.16 or 0.07
    if r < sprinters then
        return "sprinter"
    elseif r < sprinters + 0.12 then
        return "crawler"
    elseif r < sprinters + 0.24 then
        return "fat"
    end
    return "normal"
end

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

function zombies.noise(pos, radius, pid, duration)
    return noise.emit(pos, radius, pid, duration)
end

local water_id

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
    args = args or {}
    local half = zombies.KINDS[args.kind or "normal"].half
    return entities.spawn("zomboid:zombie", {x + 0.5, y + half + 0.05, z + 0.5}, {zomboid__zombie = args})
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

function zombies.limit()
    return math.floor(34 * sandbox.get("zombie_density") + 0.5)
end

function zombies.cap()
    return zombies.limit() + 12
end

function zombies.target_population()
    local base = clock.is_night() and 16 or 8
    return math.min(zombies.limit(), math.floor((base + (clock.day() - 1) * 2) * sandbox.get("zombie_density") + 0.5))
end

function zombies.spawn_horde(pid)
    local ppos = {player.get_pos(pid)}
    local size = math.floor(math.min(22, 6 + clock.day() * 3) * sandbox.get("zombie_density") + 0.5)
    local angle = math.random() * math.pi * 2
    local cx = ppos[1] + math.cos(angle) * 48
    local cz = ppos[3] + math.sin(angle) * 48
    local spawned = 0
    for _ = 1, size * 3 do
        if spawned >= size or zombies.count() >= zombies.cap() then
            break
        end
        local x = math.floor(cx + (math.random() - 0.5) * 16)
        local z = math.floor(cz + (math.random() - 0.5) * 16)
        if town.building_at(x, z) == nil then
            local y = zombies.find_ground(x, z)
            if y then
                local e = zombies.spawn(x, y, z, {horde = true, kind = zombies.roll_kind()})
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
            if near < zombies.target_population() and zombies.count() < zombies.limit() then
                local look = player.get_dir(pid)
                local x, y, z = pick_spot(ppos, look, zombies.SPAWN_MIN, zombies.SPAWN_MAX, true)
                if x then
                    zombies.spawn(x, y, z, {kind = zombies.roll_kind()})
                end
            end
        end
    end
end

return zombies
