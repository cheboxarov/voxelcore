-- Countryside generator: terrain and biome mirror, river through the town, trees by biome
app.config_packs({"zomboid"})
app.new_world("znature", "777", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local nature = require "zomboid:nature"
local SEA = nature.SEA_LEVEL
local pid = player.create("tester")
require("zomboid:survival").get(pid).fresh = nil

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
                    assert(name_at(x, SEA, z) == "base:water", "water expected at " .. x .. "," .. z)
                    assert(nature.water_at(x, z))
                elseif LAYER[top] then
                    local expected = TOP[nature.biome(x, z)] or "base:grass_block"
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
local c, b = check_mirror(nature.RIVER_X, 20, 12)
print("[zomboid-test] river mirror columns: " .. c .. ", biome tops: " .. b)

local LOGS = {["zomboid:nature_spruce_log"] = true, ["zomboid:nature_birch_log"] = true, ["base:wood"] = true,
    ["base:stone"] = true, ["zomboid:nature_mossy_stone"] = true}
local totals = {}
for _, biome in ipairs({"forest", "birch", "meadow", "swamp", "hills"}) do
    local x, z = find(biome, 160)
    visit(x, z, 20)
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
