-- Town layout: districts, lots, river with bridges, plaza, highway, village; blocks of a fresh world
app.config_packs({"zomboid"})
app.new_world("zgen", "777", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local mapping = require "zomboid:mapping"
local G = town.GROUND
local pid = player.create("tester")
require("zomboid:survival").get(pid).fresh = nil

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

local function name_at(x, y, z) return block.name(block.get(x, y, z)) end

local function visit(x, z)
    player.set_pos(pid, x + 0.5, G + 3, z + 0.5)
    app.sleep_until(function()
        return block.get(x - 10, G, z - 10) ~= -1 and block.get(x + 10, G, z + 10) ~= -1
            and block.get(x - 10, G, z + 10) ~= -1 and block.get(x + 10, G, z - 10) ~= -1
    end, nil, 30)
end

-- layout: every building fits its lot, never stands on roads, water or another lot
local kinds, zones, rotations, buildings = {}, {}, {}, 0
for _, c in ipairs(town.cells()) do
    zones[c.zone] = (zones[c.zone] or 0) + 1
    local p = town.plan(c.cx, c.cz)
    if p and p.cx == c.cx and p.cz == c.cz then
        buildings = buildings + 1
        kinds[p.kind] = (kinds[p.kind] or 0) + 1
        rotations[p.rot] = true
        for hx = 0, p.w - 1, math.max(1, p.w - 1) do
            for hz = 0, p.d - 1, math.max(1, p.d - 1) do
                local x, z = town.to_world(p, hx, hz)
                check(town.column(x, z) == "building", p.kind .. " corner is not a building")
                local _, owner, lx, lz = town.building_at(x, z)
                check(owner == p and lx == hx and lz == hz, "to_world and to_local agree")
            end
        end
        local fx, fz = town.to_world(p, p.door, -1)
        local front = town.column(fx, fz)
        check(front ~= "building" and front ~= "river", p.kind .. " door is blocked: " .. tostring(front))
    end
end
local list = {}
for k, n in pairs(kinds) do table.insert(list, k .. "=" .. n) end
table.sort(list)
log("buildings " .. buildings .. ": " .. table.concat(list, " "))
for _, def in ipairs(town.building_defs()) do
    check(kinds[def.kind] or #def.zones == 0, "building type never appears: " .. def.kind)
end
for _, zone in ipairs({"downtown", "suburb", "industrial", "outskirts", "plaza", "village"}) do
    check(zones[zone], "district missing: " .. zone)
end
check(rotations[0] and rotations[1] and rotations[2] and rotations[3], "buildings face every direction")
check(buildings > 80, "town is big")

-- deterministic: the same column gives the same blocks
local a, b = {}, {}
town.column(-60, 2, a)
town.column(-60, 2, b)
check(#a == #b and a[1][2] == b[1][2], "deterministic column")

-- streets: crossings form a connected graph for roaming zombies
local start = town.crossing_near(town.CENTER[1], town.CENTER[2] - 40)
local seen, queue, n = {[start] = true}, {start}, 0
while #queue > 0 do
    local node = table.remove(queue)
    n = n + 1
    for _, other in ipairs(node.links) do
        if not seen[other] then seen[other] = true table.insert(queue, other) end
    end
end
log("reachable crossings: " .. n)
check(n > 60, "street network is connected")

-- highway leads to the village
check(town.column(400, math.floor(town.highway_z(400) + 0.5)) == "road", "highway between town and village")
check(town.flat_dist(400, math.floor(town.highway_z(400))) == 0, "highway is flat")
local vg = town.find("gas_station")
check(vg, "gas station")
local village = 0
for _, c in ipairs(town.cells()) do
    if c.zone == "village" and town.plan(c.cx, c.cz) then village = village + 1 end
end
check(village >= 4, "village has buildings: " .. village)
check(mapping.ORIGIN_X <= town.BOUNDS[1] and mapping.ORIGIN_X + mapping.SIZE > town.BOUNDS[3], "map covers town and village")

-- main street with sidewalks
visit(-60, 2)
check(name_at(-60, G, 2) == "zomboid:asphalt" or name_at(-60, G, 2) == "zomboid:road_line", "main street: " .. name_at(-60, G, 2))
check(name_at(-60, G + 1, 2) == "core:air", "air above the road")
check(name_at(-60, G, 6) == "zomboid:sidewalk", "sidewalk: " .. name_at(-60, G, 6))

-- river: water between the quays, a bridge on the main street, railings
visit(50, 0)
check(name_at(50, G - 2, 20) == "base:water", "river water: " .. name_at(50, G - 2, 20))
check(name_at(50, G, 20) == "core:air", "open water surface")
check(name_at(41, G, 20) == "zomboid:sidewalk", "quay: " .. name_at(41, G, 20))
check(name_at(42, G + 1, 20) == "zomboid:layout_railing", "quay railing: " .. name_at(42, G + 1, 20))
check(name_at(50, G, 1) == "zomboid:asphalt" or name_at(50, G, 1) == "zomboid:road_line", "bridge deck: " .. name_at(50, G, 1))
check(name_at(50, G - 2, 1) == "base:water", "water under the bridge")
check(name_at(50, G + 1, -4) == "zomboid:layout_railing", "bridge railing")

-- plaza with a fountain at the main crossing
local fx, fz = town.CENTER[1], town.CENTER[2]
visit(fx, fz + 12)
check(name_at(fx, G + 4, fz) == "base:metal", "monument on the fountain: " .. name_at(fx, G + 4, fz))
check(name_at(fx + 2, G, fz) == "base:water", "fountain water: " .. name_at(fx + 2, G, fz))
check(town.column(fx, fz + 12) == "plaza" or town.column(fx, fz + 12) == "park", "plaza around the fountain")

-- the spawn house: rotated buildings are built in their own frame
local spawn = town.spawn_point(1)
local p = town.plan(town.cell_at(math.floor(spawn[1]), math.floor(spawn[3])))
check(p and p.kind == "house" and p.rot == 0, "spawn house")
visit(p.x0 + 6, p.z0 + 6)
local dx, dz = town.to_world(p, p.door, 0)
check(name_at(dx, G + 1, dz) == "base:wooden_door", "door: " .. name_at(dx, G + 1, dz))
check(name_at(p.x0, G + 1, p.z0) == "zomboid:trim", "corner: " .. name_at(p.x0, G + 1, p.z0))
local fx2, fz2 = town.to_world(p, p.mid - 1, p.d - 2)
check(name_at(fx2, G + 1, fz2) == "zomboid:fridge", "fridge: " .. name_at(fx2, G + 1, fz2))
local containers, glass = 0, 0
for x = p.x0, p.x1 do
    for z = p.z0, p.z1 do
        for y = G + 1, G + 2 do
            local id = block.get(x, y, z)
            if block.has_tag(id, "zomboid:container") and not block.is_segment(x, y, z) then containers = containers + 1 end
            if block.has_tag(id, "zomboid:glass") then glass = glass + 1 end
        end
    end
end
log("spawn house containers: " .. containers .. ", window blocks: " .. glass)
check(containers >= 4 and glass >= 4, "house is furnished")

local rp
for _, c in ipairs(town.cells()) do
    local q = town.plan(c.cx, c.cz)
    if q and q.kind == "house" and q.rot == 1 then rp = q break end
end
visit(rp.x0 + 6, rp.z0 + 6)
local rdx, rdz = town.to_world(rp, rp.door, 0)
check(name_at(rdx, G + 1, rdz) == "base:wooden_door", "rotated house door: " .. name_at(rdx, G + 1, rdz))
local rfx, rfz = town.to_world(rp, rp.mid - 1, rp.d - 2)
check(name_at(rfx, G + 1, rfz) == "zomboid:fridge", "rotated house fridge: " .. name_at(rfx, G + 1, rfz))
check(block.get_rotation(rfx, G + 1, rfz) == (2 + rp.rot) % 4, "rotated furniture faces the room")

-- suburb yards are fenced
local fences = 0
visit(-130, 60)
for x = -150, -110 do
    for z = 40, 80 do
        if name_at(x, G + 1, z) == "zomboid:layout_fence" then fences = fences + 1 end
    end
end
log("fence blocks in a suburb sample: " .. fences)
check(fences > 10, "fences between yards")

-- the village gas station has pumps
local vp
for _, c in ipairs(town.cells()) do
    local q = town.plan(c.cx, c.cz)
    if c.zone == "village" and q and q.kind == "gas_station" then vp = q end
end
check(vp, "village gas station")
local px, pz = town.to_world(vp, 2, -4)
visit(px, pz)
check(name_at(px, G + 1, pz) == "zomboid:fuel_pump", "village pump: " .. name_at(px, G + 1, pz))

-- forest outside the town is not flat and has trees
local wood = 0
local wx, wz = 300, 140
player.set_pos(pid, wx, 70, wz)
app.sleep_until(function() return block.get(wx - 8, 50, wz - 8) ~= -1 and block.get(wx + 8, 50, wz + 8) ~= -1 end, nil, 30)
for x = wx - 8, wx + 8 do
    for z = wz - 8, wz + 8 do
        for y = 30, 70 do
            if block.name(block.get(x, y, z)) == "base:wood" then wood = wood + 1 end
        end
    end
end
log("wood blocks in forest sample: " .. wood)
check(wood > 0, "forest")

app.close_world(false)
app.delete_world("zgen")
