-- Town generator: roads, houses, containers and spawn in a fresh world
app.config_packs({"zomboid"})
app.new_world("zgen", "777", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 4)

local town = require "zomboid:town"
local G = town.GROUND
local pid = player.create("tester")
player.set_pos(pid, 2, G + 3, 2)

local function wait_area(x, z, r)
    app.sleep_until(function()
        return block.get(x - r, G, z - r) ~= -1 and block.get(x + r, G, z + r) ~= -1
            and block.get(x - r, G, z + r) ~= -1 and block.get(x + r, G, z - r) ~= -1
    end, 6000)
end
local function name_at(x, y, z) return block.name(block.get(x, y, z)) end
wait_area(8, 20, 12)

-- roads at the crossing of cells
assert(name_at(2, G, 20) == "zomboid:asphalt" or name_at(2, G, 20) == "zomboid:road_line", name_at(2, G, 20))
assert(name_at(1, G + 1, 20) == "core:air", "air above road: " .. name_at(1, G + 1, 20))
assert(name_at(5, G, 20) == "zomboid:sidewalk", name_at(5, G, 20))

-- the spawn house in cell (0, 0)
local p = town.plan(0, 0)
assert(p and p.kind == "house")
local dx, dz = p.x0 + p.door, p.z0
player.set_pos(pid, dx, G + 3, dz)
wait_area(p.x0 + 8, p.z0 + 8, 10)
assert(name_at(dx, G + 1, dz) == "base:wooden_door", "door: " .. name_at(dx, G + 1, dz))
assert(name_at(p.x0, G + 1, p.z0) == "zomboid:trim", "corner: " .. name_at(p.x0, G + 1, p.z0))
assert(name_at(p.x0 + 2, G + 4, p.z0 + 2) == "zomboid:roof")
assert(name_at(p.x0 + p.mid, G + 1, p.z0 + 2) == "core:air", "interior: " .. name_at(p.x0 + p.mid, G + 1, p.z0 + 2))
local fx, fz = p.x0 + p.mid - 1, p.z0 + p.d - 2
assert(name_at(fx, G + 1, fz) == "zomboid:fridge", "fridge: " .. name_at(fx, G + 1, fz))

local containers = 0
local glass = 0
for x = p.x0, p.x0 + p.w - 1 do
    for z = p.z0, p.z0 + p.d - 1 do
        for y = G + 1, G + 2 do
            local id = block.get(x, y, z)
            if block.has_tag(id, "zomboid:container") and not block.is_segment(x, y, z) then
                containers = containers + 1
            end
            if block.has_tag(id, "zomboid:glass") then glass = glass + 1 end
        end
    end
end
print("[zomboid-test] house containers: " .. containers .. ", window blocks: " .. glass)
assert(containers >= 4, "containers " .. containers)
assert(glass >= 4, "windows " .. glass)

-- forest outside the town is not flat and has trees
local wood = 0
local wx = 200
player.set_pos(pid, wx, 70, 0)
wait_area(wx, 0, 10)
for x = wx - 8, wx + 8 do
    for z = -8, 8 do
        for y = 30, 70 do
            if block.name(block.get(x, y, z)) == "base:wood" then wood = wood + 1 end
        end
    end
end
print("[zomboid-test] wood blocks in forest sample: " .. wood)
assert(wood > 0)

app.close_world(false)
app.delete_world("zgen")
