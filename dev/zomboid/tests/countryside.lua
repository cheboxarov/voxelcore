-- Countryside lots: every rural kind exists, farm and cabin are built on flat ground, lanes are clear of trees
app.config_packs({"zomboid"})
app.new_world("zcountry", "777", "zomboid:town")
app.set_setting("chunks.load-distance", 5)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local countryside = require "zomboid:countryside"
local nature = require "zomboid:nature"
local loot = require "zomboid:loot"
local farming = require "zomboid:farming"
local G = town.GROUND
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

local found, first = {}, {}
for d = 0, 12 do
    for i = -d, d do
        for j = -d, d do
            if math.max(math.abs(i), math.abs(j)) == d then
                local p = countryside.lot(i, j)
                if p then
                    found[p.kind] = (found[p.kind] or 0) + 1
                    first[p.kind] = first[p.kind] or p
                    assert(town.building_at(town.to_world(p, 1, 1)) == p.kind, "building_at misses " .. p.kind)
                    assert(nature.river_dist((p.x0 + p.x1) / 2, (p.z0 + p.z1) / 2) > 40, "lot by the river")
                end
            end
        end
    end
end
for _, kind in ipairs({"farm", "hunting_cabin", "campsite", "trailer_park", "sawmill"}) do
    print("[zomboid-test] " .. kind .. ": " .. (found[kind] or 0))
    assert(found[kind], "no " .. kind .. " in the countryside")
end

local LEAVES = {["zomboid:nature_spruce_leaves"] = true, ["zomboid:nature_birch_leaves"] = true, ["base:leaves"] = true}

local function lot_checks(p)
    local cx, cz = math.floor((p.lx0 + p.lx1) / 2), math.floor((p.lz0 + p.lz1) / 2)
    visit(cx, cz, 28)
    local leaves, bumpy = 0, 0
    for x = p.lx0, p.lx1, 2 do
        for z = p.lz0, p.lz1, 2 do
            assert(nature.height(x, z) == G, string.format("%s lot is not flat at %d,%d: %d", p.kind, x, z,
                nature.height(x, z)))
            for y = G + 1, G + 9 do
                if LEAVES[name_at(x, y, z)] then leaves = leaves + 1 end
            end
        end
    end
    assert(leaves == 0, p.kind .. " lot has " .. leaves .. " leaves")
    local lx, sz = p.lane_x, p.spur_z
    visit(lx, sz, 16)
    assert(name_at(lx, G, sz) == "zomboid:nature_dirt_path", "lane at " .. lx .. "," .. sz .. ": " .. name_at(lx, G, sz))
    local dx = p.rot == 1 and 1 or -1
    assert(name_at(lx + dx * 3, G, sz) == "zomboid:nature_dirt_path", "spur to " .. p.kind)
    for z = sz - 12, sz + 12 do
        if countryside.column(lx, z) == "dirt_road" then
            for y = G + 1, G + 9 do
                assert(not LEAVES[name_at(lx, y, z)] and block.material(block.get(lx, y, z)) ~= "base:wood",
                    "tree over the lane at " .. lx .. "," .. z)
            end
        end
    end
end

-- farm: farmhouse, barn crates, silo, ripe crops
local p = first.farm
lot_checks(p)
local hx, hz = town.to_world(p, 2 + p.house.door, 2)
assert(name_at(hx, G + 1, hz) == "base:wooden_door", "farmhouse door: " .. name_at(hx, G + 1, hz))
local bx, bz = town.to_world(p, 29, 5)
assert(name_at(bx, G + 1, bz) == "zomboid:crate", "barn crate: " .. name_at(bx, G + 1, bz))
local sx, sz = town.to_world(p, 17 + 3, 7)
assert(name_at(sx, G + 8, sz) == "zomboid:nature_silo", "silo: " .. name_at(sx, G + 8, sz))
local crops, crop_at = 0, nil
for x = p.x0, p.x1 do
    for z = p.z0, p.z1 do
        local n = name_at(x, G + 1, z)
        if n == "zomboid:crop_carrot" or n == "zomboid:crop_potato" then
            assert(name_at(x, G, z) == "zomboid:garden_bed")
            crops = crops + 1
            crop_at = crop_at or {x, G + 1, z}
        end
    end
end
print("[zomboid-test] farm crops: " .. crops)
assert(crops > 300, "farm field has " .. crops .. " crops")
farming.update(crop_at[1], crop_at[2], crop_at[3])
assert(block.get_variant(crop_at[1], crop_at[2], crop_at[3]) == farming.STAGES, "generated crops are ripe")
local found_crate = loot.table_for("crate", bx, bz)
local seeds = false
for _, e in ipairs(found_crate) do seeds = seeds or e[1] == "zomboid:seeds_carrot" end
assert(seeds, "farm crate loot has no seeds")

-- hunting cabin: shotgun in the gun crate, campfire in front
p = first.hunting_cabin
lot_checks(p)
local cx, cz = town.to_world(p, 1, 1)
assert(name_at(cx, G + 1, cz) == "zomboid:crate", "cabin crate: " .. name_at(cx, G + 1, cz))
local gun = false
for _, e in ipairs(loot.table_for("crate", cx, cz)) do gun = gun or e[1] == "zomboid:shotgun" end
assert(gun, "no shotgun in the cabin loot")
local fx, fz = town.to_world(p, p.door + 3, -4)
assert(name_at(fx, G + 1, fz) == "zomboid:campfire", "cabin campfire: " .. name_at(fx, G + 1, fz))

for _, kind in ipairs({"campsite", "trailer_park", "sawmill"}) do
    lot_checks(first[kind])
end

-- generated campfires have nothing flammable around them and never start a forest fire on their own
local fire = require "zomboid:fire"
local function campfire_safe(x, z)
    visit(x, z, 8)
    assert(name_at(x, G + 1, z) == "zomboid:campfire", "campfire at " .. x .. "," .. z)
    player.set_pos(pid, x + 20, 90, z)
    for _ = 1, 400 do
        assert(not fire.unattended(x, G + 1, z), "generated campfire set fire at " .. x .. "," .. z)
    end
end
campfire_safe(fx, fz)
local camp = first.campsite
campfire_safe(town.to_world(camp, 13, 10))

app.close_world(false)
app.delete_world("zcountry")
