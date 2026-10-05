-- Countryside generator: terrain and biome mirror, river through the town, trees by biome
app.config_packs({"zomboid"})
app.new_world("znature", "777", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local nature = require "zomboid:nature"
local zombies = require "zomboid:zombies"
local survival = require "zomboid:survival"
local SEA = nature.SEA_LEVEL
local H = nature.height
local pid = player.create("tester")
survival.get(pid).fresh = nil

local function name_at(x, y, z) return block.name(block.get(x, y, z)) end
local function visit(x, z, r)
    player.set_pos(pid, x, 90, z)
    app.sleep_until(function()
        return block.get(x - r, 0, z - r) ~= -1 and block.get(x + r, 0, z + r) ~= -1
            and block.get(x - r, 0, z + r) ~= -1 and block.get(x + r, 0, z - r) ~= -1
    end, 6000)
end

local defs = toml.parse(file.read("zomboid:generators/town.files/biomes.toml"))
for _, b in ipairs(nature.BIOMES) do
    local def = defs[b[1]]
    assert(def, "biome missing in biomes.toml: " .. b[1])
    for i = 1, 3 do
        assert(def.parameters[i].value == b[i + 1][1] and def.parameters[i].weight == b[i + 1][2],
            "biome parameters differ from biomes.toml: " .. b[1])
    end
end

local gen = toml.parse(file.read("zomboid:generators/town.toml"))
assert(gen["sea-level"] == SEA and gen["heights-bpd"] == nature.HEIGHTS_BPD and gen["biome-bpd"] == nature.BIOMES_BPD,
    "town.toml differs from nature constants")

local TOP = {forest = "zomboid:nature_podzol", swamp = "zomboid:nature_mud", river = "base:sand"}
local LAYER = {["base:grass_block"] = true, ["base:dirt"] = true, ["base:sand"] = true,
    ["zomboid:nature_podzol"] = true, ["zomboid:nature_mud"] = true}

local function check_mirror(x0, z0, r)
    local checked, biomes_checked = 0, 0
    for x = x0 - r, x0 + r, 3 do
        for z = z0 - r, z0 + r, 3 do
            if town.column(x, z) == nil then
                local h = nature.height(x, z)
                local top, above = name_at(x, h, z), name_at(x, h + 1, z)
                assert(top ~= "core:air" and top ~= "base:water" and not LAYER[above],
                    string.format("height mirror at %d,%d: h=%d top=%s above=%s", x, z, h, top, above))
                if h < SEA then
                    assert(name_at(x, SEA, z) == "base:water", "water expected at " .. x .. "," .. z .. ": " .. name_at(x, SEA, z) .. " h=" .. h)
                    assert(nature.water_at(x, z))
                elseif LAYER[top] then
                    local expected = TOP[nature.biome(x, z)] or "base:grass_block"
                    if expected == "base:grass_block" and top == "base:dirt" and block.is_solid_at(x, h + 1, z) then
                        expected = top
                    end
                    assert(top == expected, string.format("biome mirror at %d,%d: %s is %s, expected %s",
                        x, z, nature.biome(x, z), top, expected))
                    biomes_checked = biomes_checked + 1
                end
                checked = checked + 1
            end
        end
    end
    return checked, biomes_checked
end

local function find(biome, from)
    for d = from, 900, 16 do
        for _, p in ipairs({{d, 0}, {-d, 0}, {0, d}, {0, -d}, {d, d}, {-d, -d}, {d, -d}, {-d, d}}) do
            local ok = true
            for _, o in ipairs({{0, 0}, {12, 0}, {-12, 0}, {0, 12}, {0, -12}}) do
                local x, z = p[1] + o[1], p[2] + o[2]
                if nature.biome(x, z) ~= biome or nature.water_at(x, z) or town.column(x, z) ~= nil then
                    ok = false
                    break
                end
            end
            if ok then
                return p[1], p[2]
            end
        end
    end
    error("no " .. biome .. " found")
end

local function count(x0, z0, r, names)
    local n = {}
    for x = x0 - r, x0 + r do
        for z = z0 - r, z0 + r do
            local h = nature.height(x, z)
            for y = h + 1, h + 14 do
                local name = name_at(x, y, z)
                if names[name] then
                    n[name] = (n[name] or 0) + 1
                end
            end
        end
    end
    return n
end

-- the river crosses the town straight along x = RIVER_X
visit(nature.RIVER_X, 20, 12)
for _, z in ipairs({8, 20}) do
    assert(name_at(nature.RIVER_X, SEA, z) == "base:water", "river at z=" .. z)
    assert(nature.height(nature.RIVER_X, z) <= SEA - 3, "river is shallow at z=" .. z)
    assert(nature.water_at(nature.RIVER_X + 6, z) and not nature.water_at(nature.RIVER_X + 11, z))
end
local rz = town.FLAT_EXTENT + 150
local rx = math.floor(nature.river_x(rz))
visit(rx, rz, 16)
assert(name_at(rx, SEA, rz) == "base:water" and nature.water_at(rx, rz), "river outside the town at " .. rx .. "," .. rz)
local c, b = check_mirror(rx, rz, 16)
print("[zomboid-test] river mirror at " .. rx .. "," .. rz .. ": " .. c .. " columns, " .. b .. " biome tops")
assert(b > 10)

-- no swimming in the engine: water columns that cannot climb out one block at a time to dry land
local function traps(seed)
    local C0, C1 = -30, 30
    local N = (C1 - C0 + 1) * 16
    local hs = {}
    for cz = C0, C1 do
        for cx = C0, C1 do
            local ch = nature.chunk_heights(cx, cz, seed)
            for lz = 0, 15 do
                for lx = 0, 15 do
                    local x, z = cx * 16 + lx, cz * 16 + lz
                    hs[((cz - C0) * 16 + lz) * N + (cx - C0) * 16 + lx] = town.in_town(x, z) and -1 or ch[lz * 16 + lx + 1]
                end
            end
        end
    end
    local out, queue, head = {}, {}, 1
    for i = 0, N * N - 1 do
        if hs[i] >= SEA or hs[i] == -1 then
            out[i] = true
            queue[#queue + 1] = i
        end
    end
    while head <= #queue do
        local v = queue[head]
        head = head + 1
        for _, u in ipairs({v + 1, v - 1, v + N, v - N}) do
            if u >= 0 and u < N * N and math.abs(u % N - v % N) <= 1 and not out[u]
                and (hs[v] == -1 or hs[v] <= hs[u] + 1) then
                out[u] = true
                queue[#queue + 1] = u
            end
        end
    end
    local water, trapped = 0, {}
    for i = 0, N * N - 1 do
        local x, z = i % N, math.floor(i / N)
        if hs[i] >= 0 and hs[i] < SEA and x > 0 and z > 0 and x < N - 1 and z < N - 1 then
            water = water + 1
            if not out[i] then
                trapped[#trapped + 1] = string.format("%d,%d", C0 * 16 + x, C0 * 16 + z)
            end
        end
    end
    print(string.format("[zomboid-test] seed %s: %d of %d water columns trapped %s", tostring(seed), #trapped, water,
        table.concat(trapped, " ")))
    assert(water > 5000 and #trapped * 1000 <= water, "water is a trap")
end
traps(world.get_seed())

-- the river leaves the town through cut banks on both ends
for _, z in ipairs({-200, 200}) do
    visit(nature.RIVER_X, z, 12)
    assert(name_at(nature.RIVER_X, SEA, z) == "base:water", "river leaves the town at z=" .. z)
end

-- the highway, the village and the town stand on flat ground
for _, x in ipairs({-600, -400, -300, 300, 450, 615, 800}) do
    local z = math.floor(town.highway_z(x) + 0.5)
    assert(town.column(x, z) == "road", "highway at " .. x)
    for dz = -12, 12, 4 do
        assert(nature.height(x, z + dz) == town.GROUND, string.format("ground by the highway at %d,%d: %d", x, z + dz,
            nature.height(x, z + dz)))
    end
end

-- player and zombie climb out of the river, a lake, a swamp pool and a stream
local function dry(x, z) return H(x, z) >= SEA and town.column(x, z) == nil end
local function way_out(x0, z0)
    local prev, queue, head = {[x0 .. ":" .. z0] = false}, {{x0, z0}}, 1
    while head <= #queue do
        local c = queue[head]
        head = head + 1
        if dry(c[1], c[2]) then
            local path = {}
            while c do
                table.insert(path, 1, c)
                c = prev[c[1] .. ":" .. c[2]]
            end
            return path
        end
        for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
            local x, z = c[1] + d[1], c[2] + d[2]
            if prev[x .. ":" .. z] == nil and H(x, z) <= H(c[1], c[2]) + 1 and town.column(x, z) == nil then
                prev[x .. ":" .. z] = c
                queue[#queue + 1] = {x, z}
            end
        end
    end
end
local function walk_out(x, z, path)
    player.set_pos(pid, x + 0.5, H(x, z) + 1.1, z + 0.5)
    player.set_vel(pid, 0, 0, 0)
    app.sleep(0.5)
    local e = entities.get(player.get_entity(pid))
    local mob = e:get_component("core:mob")
    local i = 2
    for _ = 1, 1200 do
        local px, py, pz = player.get_pos(pid)
        local t = path[i]
        local dx, dz = t[1] + 0.5 - px, t[2] + 0.5 - pz
        if dx * dx + dz * dz < 0.09 then
            if i == #path then break end
            i = i + 1
        end
        mob.go({dx, dz}, 0.6, false, false)
        if H(t[1], t[2]) + 1 > py - 0.6 and e.rigidbody:is_grounded() then mob.jump() end
        app.tick()
    end
    local px, py, pz = player.get_pos(pid)
    return dry(math.floor(px), math.floor(pz)) and py >= SEA + 1
end
local function zombie_out(x, z, shore)
    local t, far = shore, 0
    for dx = -6, 6 do
        for dz = -6, 6 do
            local tx, tz = shore[1] + dx, shore[2] + dz
            local d = (tx - x) ^ 2 + (tz - z) ^ 2
            if dx * dx + dz * dz >= 16 and dry(tx, tz) and math.abs(H(tx, tz) - H(shore[1], shore[2])) <= 1 and d > far then
                t, far = {tx, tz}, d
            end
        end
    end
    local state = survival.get(pid)
    state.setup = nil
    math.randomseed(7)
    local e = zombies.spawn(x, H(x, z) + 1, z)
    local out = false
    local ticks = 0
    for _ = 1, 1200 do
        ticks = ticks + 1
        player.set_pos(pid, t[1] + 0.5, H(t[1], t[2]) + 1.1, t[2] + 0.5)
        state.health = 100
        app.tick()
        local p = e.transform:get_pos()
        if dry(math.floor(p[1]), math.floor(p[3])) and p[2] - zombies.KINDS.normal.half >= SEA + 0.9 then
            out = true
            break
        end
    end
    e:despawn()
    state.setup = true
    return out and ticks
end
local function find_water(pred)
    for d = 280, 1400, 6 do
        for _, a in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}}) do
            local x, z = a[1] * d, a[2] * d
            if not town.in_town(x, z) and H(x, z) < SEA and pred(x, z) then return x, z end
        end
    end
    error("no water found")
end
local waters = {
    {"river", rx, rz},
    {"lake", find_water(function(x, z) return H(x, z) <= SEA - 3 and nature.river_dist(x, z) > 40 and nature.biome(x, z) ~= "swamp" end)},
    {"swamp", find_water(function(x, z) return nature.biome(x, z) == "swamp" end)},
    {"stream", find_water(function(x, z) return H(x, z) == SEA - 1 and nature.river_dist(x, z) > 40 and nature.biome(x, z) ~= "swamp" end)},
}
for _, w in ipairs(waters) do
    local name, x, z = w[1], w[2], w[3]
    visit(x, z, 16)
    local path = way_out(x, z)
    assert(path, "no way out of the " .. name .. " at " .. x .. "," .. z)
    local walked, zombie = walk_out(x, z, path), zombie_out(x, z, path[#path])
    print(string.format("[zomboid-test] %s at %d,%d depth %d: player out %s, zombie out after %s ticks", name, x, z, SEA - H(x, z),
        tostring(walked), tostring(zombie)))
    assert(walked and zombie, "stuck in the " .. name .. " at " .. x .. "," .. z)
end

local LOGS = {["zomboid:nature_spruce_log"] = true, ["zomboid:nature_birch_log"] = true, ["base:wood"] = true,
    ["base:stone"] = true, ["zomboid:nature_mossy_stone"] = true}
local totals = {}
for _, biome in ipairs({"forest", "birch", "meadow", "swamp", "hills"}) do
    local x, z = find(biome, 160)
    visit(x, z, 20)
    app.sleep(30)
    local cols, tops = check_mirror(x, z, 20)
    local n = count(x, z, 20, LOGS)
    totals[biome] = n
    print(string.format("[zomboid-test] %s at %d,%d: mirror %d/%d, spruce %d, birch %d, oak %d, rocks %d", biome, x, z,
        cols, tops, n["zomboid:nature_spruce_log"] or 0, n["zomboid:nature_birch_log"] or 0, n["base:wood"] or 0,
        (n["base:stone"] or 0) + (n["zomboid:nature_mossy_stone"] or 0)))
    assert(tops > 20, "too few biome tops checked in " .. biome)
end
assert((totals.forest["zomboid:nature_spruce_log"] or 0) > 40, "forest without spruces")
assert((totals.birch["zomboid:nature_birch_log"] or 0) > 20, "birch grove without birches")
assert((totals.forest["zomboid:nature_spruce_log"] or 0) > 3 * (totals.meadow["zomboid:nature_spruce_log"] or 0) + 10)

app.close_world(false)
app.delete_world("znature")

-- the mirror holds for any seed, also text and 64-bit ones
for i, text in ipairs({"1", "123456789012345678", "zomboid text"}) do
    app.new_world("znature" .. i, text, "zomboid:town")
    pid = player.create("tester")
    survival.get(pid).fresh = nil
    traps(world.get_seed())
    for _, p in ipairs({{math.floor(nature.river_x(rz)), rz}, {700, -500}, {-900, 900}}) do
        visit(p[1], p[2], 16)
        local cols, tops = check_mirror(p[1], p[2], 16)
        print(string.format("[zomboid-test] seed %s mirror at %d,%d: %d/%d", text, p[1], p[2], cols, tops))
        assert(cols > 50)
    end
    app.close_world(false)
    app.delete_world("znature" .. i)
end
