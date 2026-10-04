local clock = require "zomboid:clock"
local town = require "zomboid:town"
local zombies = require "zomboid:zombies"
local noise = require "zomboid:noise"
local sandbox = require "zomboid:sandbox"

local population = {
    seeded = {},
    SEED_NEAR = 22,
    SEED_FAR = 60,
    PULL_COOLDOWN = 20,
}

local tick_counter = 0
local pull_checked = 0
local pull_ready = 0

local function ground(x, z)
    if town.building_at(x, z) then
        return nil
    end
    return zombies.find_ground(x, z)
end

local function spawn_group(key, n, args_fn)
    local spawned = 0
    for _ = 1, n * 3 do
        if spawned >= n or zombies.count() >= zombies.limit() then
            break
        end
        local x, z, args = args_fn()
        local y = ground(x, z)
        if y then
            args.kind = zombies.roll_kind()
            args.cell = key
            zombies.spawn(x, y, z, args)
            spawned = spawned + 1
        end
    end
    return spawned
end

function population.seed_cell(cx, cz)
    local key = cx .. ":" .. cz
    local p = town.plan(cx, cz)
    local day = clock.day()
    local ax, az
    if p then
        ax, az = town.to_world(p, p.door, -4)
    else
        ax, az = town.cell_center(cx, cz)
    end
    local crowd = math.floor((math.random(2, 3) + math.min(3, day - 1)) * sandbox.get("zombie_density") + 0.5)
    if p == nil and math.random() < 0.5 then
        crowd = 0
    end
    local ay = town.GROUND + 1
    local n = spawn_group(key, crowd, function()
        return ax + math.random(-3, 3), az + math.random(-2, 2), {anchor = {ax + 0.5, ay, az + 0.5}}
    end)
    if math.random() < 0.7 then
        local node = town.crossing_near(ax, az)
        n = n + spawn_group(key, math.random(1, 2), function()
            return node.x + math.random(-2, 2), node.z + math.random(-2, 2), {route = true}
        end)
    end
    if p and p.cx == cx and p.cz == cz and p.def.zombies then
        n = n + population.seed_building(p, key)
    end
    population.seeded[key] = day
    return n
end

function population.seed_building(p, key)
    local spec = p.def.zombies
    local n = 0
    for _, place in ipairs({"count", "yard"}) do
        local range, yard = spec[place], place == "yard"
        local want = range and math.floor(math.random(range[1], range[2]) * sandbox.get("zombie_density") + 0.5) or 0
        for _ = 1, want * 2 do
            if want <= 0 or zombies.count() >= zombies.limit() then
                break
            end
            local hx, f, hz = p.def.spot(p, math.random, yard)
            local x, z = town.to_world(p, hx, hz)
            local y = zombies.find_ground(x, z, town.GROUND + f * 4 + 3)
            if y then
                zombies.spawn(x, y, z, {kind = zombies.roll_kind(), cell = key, anchor = {x + 0.5, y, z + 0.5},
                    shirt = spec.shirts and spec.shirts[math.random(#spec.shirts)]})
                want = want - 1
                n = n + 1
            end
        end
    end
    return n
end

local function seed_near(ppos)
    for _, c in ipairs(town.cells()) do
        local key = c.cx .. ":" .. c.cz
        local x, z = town.cell_center(c.cx, c.cz)
        local center = {x, ppos[2], z}
        local d = vec3.distance(center, ppos)
        if population.seeded[key] ~= clock.day() and d >= population.SEED_NEAR and d <= population.SEED_FAR
            and block.get(x, town.GROUND, z) ~= -1 then
            if zombies.count_near(center, 20) >= 2 then
                population.seeded[key] = clock.day()
            else
                population.seed_cell(c.cx, c.cz)
            end
            return
        end
    end
end

function population.pull(mark, ppos)
    local n = math.floor(math.min(6, mark.radius / 20) * sandbox.get("zombie_density") + 0.5)
    local base = math.atan2(ppos[3] - mark.pos[3], ppos[1] - mark.pos[1]) + math.pi
    local spawned = 0
    for _ = 1, n * 3 do
        if spawned >= n or zombies.count() >= zombies.cap() then
            break
        end
        local angle = base + (math.random() - 0.5) * 2.4
        local dist = math.min(mark.radius, 44 + math.random() * 14)
        local x = math.floor(mark.pos[1] + math.cos(angle) * dist)
        local z = math.floor(mark.pos[3] + math.sin(angle) * dist)
        local y = ground(x, z)
        if y then
            local e = zombies.spawn(x, y, z, {kind = zombies.roll_kind()})
            local comp = e and e:get_component("zomboid:zombie")
            if comp then
                comp.hear(mark.pos, mark.pid, dist)
            end
            spawned = spawned + 1
        end
    end
    return spawned
end

function population.tick(survival)
    tick_counter = tick_counter + 1
    if not zombies.enabled or tick_counter % 20 ~= 0 then
        return
    end
    local now = time.uptime()
    local loud = noise.loud_since(pull_checked)
    pull_checked = now
    for _, pid in ipairs(player.get_all()) do
        if not survival.get(pid).dead then
            local ppos = {player.get_pos(pid)}
            if now >= pull_ready and #loud > 0 then
                pull_ready = now + population.PULL_COOLDOWN
                population.pull(loud[#loud], ppos)
            end
            if zombies.count() < zombies.limit() then
                seed_near(ppos)
            end
        end
    end
end

return population
