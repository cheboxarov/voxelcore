-- Weather, rain barrels, building menu, gate and ladder, gardening
app.config_packs({"zomboid"})
app.new_world("zout", "5151", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local weather = require "zomboid:weather"
local building = require "zomboid:building"
local farming = require "zomboid:farming"
local skills = require "zomboid:skills"
local inv = require "zomboid:inv"
local G = town.GROUND

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

zombies.enabled = false
local pid = player.create("survivor")
local spawn = town.spawn_point(1)
player.set_pos(pid, spawn[1], spawn[2], spawn[3])
app.sleep_until(function()
    return block.get(math.floor(spawn[1]) + 16, G, math.floor(spawn[3]) + 16) ~= -1
        and block.get(math.floor(spawn[1]) - 16, G, math.floor(spawn[3]) - 16) ~= -1
end, 8000)
app.sleep(1)
local state = survival.get(pid)
local invid, slot = player.get_inventory(pid)

local function hold(name, count, uses)
    inventory.set(invid, slot, item.index(name), count or 1)
    if uses then
        inventory.set_data(invid, slot, "uses", uses)
    end
end

local function held_name()
    return item.name((inventory.get(invid, slot)))
end

local cx, cz = town.cell_at(math.floor(spawn[1]), math.floor(spawn[3]))
local p = town.plan(cx, cz)
local ox, oz = p.x0, p.z0
-- an open lawn spot in front of the house and a spot under its roof
local ax, az = ox + p.w + 1, oz - 1
local ix, iz = ox + p.mid, oz + 2

-- building: the menu needs a hammer and materials
check(not building.build(pid, 1), "no wall without materials")
inventory.add(invid, item.index("zomboid:plank"), 20)
inventory.add(invid, item.index("zomboid:nails"), 40)
check(not building.build(pid, 1), "no wall without a hammer")
inventory.add(invid, item.index("zomboid:hammer"), 1)
local xp = skills.xp(pid, "carpentry")
check(building.build(pid, 1), "wall built")
check(inv.count(invid, "zomboid:plank_wall.item") == 2, "two wall blocks")
check(inv.count(invid, "zomboid:plank") == 17 and inv.count(invid, "zomboid:nails") == 36, "materials spent")
check(skills.xp(pid, "carpentry") > xp, "carpentry xp")
check(building.build(pid, 2) and building.build(pid, 4) and building.build(pid, 6), "gate, ladder and barrel")
check(inv.count(invid, "zomboid:wooden_gate.item") == 1 and inv.count(invid, "zomboid:ladder.item") == 2
    and inv.count(invid, "zomboid:rain_barrel.item") == 1, "building items")

-- zombies can break a plank wall
local barricade = require "zomboid:barricade"
local wx, wy, wz = ax + 3, G + 1, az
block.set(wx, wy, wz, block.index("zomboid:plank_wall"), 0)
check(barricade.is_bashable(block.get(wx, wy, wz)), "wall is bashable")
local hits = 0
while block.get(wx, wy, wz) ~= 0 and hits < 50 do
    barricade.bash(wx, wy, wz, 5)
    hits = hits + 1
end
log("plank wall broken by " .. hits .. " zombie hits")
check(hits > 5 and block.get(wx, wy, wz) == 0, "wall held a while")

-- gate opens and closes
local gx, gy, gz = ax + 5, G + 1, az
block.set(gx, gy, gz, block.index("zomboid:wooden_gate"), 0)
local rot = block.get_rotation(gx, gy, gz)
events.emit("zomboid:wooden_gate.interact", gx, gy, gz, pid)
check(block.get_rotation(gx, gy, gz) ~= rot, "gate opened")
events.emit("zomboid:wooden_gate.interact", gx, gy, gz, pid)
check(block.get_rotation(gx, gy, gz) == rot, "gate closed")

-- ladder: looking up climbs it
local lx, lz = ax + 7, az
for y = G + 1, G + 6 do
    block.set(lx, y, lz, block.index("zomboid:ladder"), 0)
end
block.set(lx, G + 6, lz + 1, block.index("zomboid:wood_floor"), 0)
player.set_pos(pid, lx + 0.5, G + 1.9, lz + 0.5)
player.set_rot(pid, 0, 80, 0)
local y0 = select(2, player.get_pos(pid))
app.sleep(1.5)
local y1 = select(2, player.get_pos(pid))
log(string.format("ladder: %.1f -> %.1f", y0, y1))
check(y1 > y0 + 2, "climbed the ladder")
player.set_rot(pid, 0, 0, 0)
player.set_pos(pid, spawn[1], spawn[2], spawn[3])
app.sleep(0.5)

-- weather: rain sets the flag, wets outdoors only
weather.set_raining(false)
check(not weather.is_raining(), "clear")
weather.set_raining(true)
check(weather.raining and weather.is_raining(), "raining flag")
check(weather.is_wet(ax + 0.5, G + 1, az + 0.5), "wet outside")
check(not weather.is_wet(ix + 0.5, G + 1, iz + 0.5), "dry under the roof")

-- rain barrels fill outdoors, not under a roof
block.set(ax, G + 1, az, block.index("zomboid:rain_barrel"), 0)
block.set(ix, G + 1, iz, block.index("zomboid:rain_barrel"), 0)
app.tick()
weather.next_change = clock.hours + 100
clock.reset(clock.hours + 3)
app.sleep(3)
local outside = block.get_field(ax, G + 1, az, "water")
local inside = block.get_field(ix, G + 1, iz, "water") or 0
log(string.format("barrels after 3h of rain: outside %.1f, inside %.1f", outside, inside))
check(outside >= 10, "outdoor barrel filled")
check(inside == 0, "indoor barrel stays empty")
hold("zomboid:empty_bottle")
events.emit("zomboid:rain_barrel.interact", ax, G + 1, az, pid)
check(held_name() == "zomboid:water_bottle", "bottle from the barrel")
check(block.get_field(ax, G + 1, az, "water") < outside, "barrel water used")
state.thirst = 40
hold("zomboid:bat")
events.emit("zomboid:rain_barrel.interact", ax, G + 1, az, pid)
check(state.thirst > 60, "drank from the barrel")

-- the weather changes by itself
weather.next_change = clock.hours - 0.1
app.sleep(3)
check(not weather.raining, "rain stopped on schedule")
check(weather.next_change > clock.hours, "next change scheduled")

-- gardening: dig, plant, water, grow, harvest
local bx, bz = ax + 2, az - 2
local by = G
for y = G + 3, G - 3, -1 do
    if block.is_solid_at(bx, y, bz) then by = y break end
end
check(block.name(block.get(bx, by, bz)) == "base:grass_block", "lawn: " .. block.name(block.get(bx, by, bz)))
hold("zomboid:shovel")
events.emit("zomboid:shovel.useon", bx, by, bz, pid, {0, 1, 0})
check(block.name(block.get(bx, by, bz)) == "zomboid:garden_bed", "dug a bed")
hold("zomboid:seeds_carrot", 3)
events.emit("zomboid:seeds_carrot.useon", bx, by, bz, pid, {0, 1, 0})
check(block.name(block.get(bx, by + 1, bz)) == "zomboid:crop_carrot", "planted")
check(select(2, inventory.get(invid, slot)) == 2, "seed used")
local grow = farming.GROW_HOURS.carrot
for _ = 1, 4 do
    hold("zomboid:water_bottle")
    events.emit("zomboid:crop_carrot.interact", bx, by + 1, bz, pid)
    clock.reset(clock.hours + grow / 4 + 0.5)
    farming.update(bx, by + 1, bz)
end
log("carrot stage after watering: " .. block.get_variant(bx, by + 1, bz))
check(block.get_variant(bx, by + 1, bz) == farming.STAGES, "ripe")
local carrots = inv.count(invid, "zomboid:carrot")
hold("zomboid:bat")
events.emit("zomboid:crop_carrot.interact", bx, by + 1, bz, pid)
check(inv.count(invid, "zomboid:carrot") > carrots, "harvested carrots")
check(block.get(bx, by + 1, bz) == 0, "crop removed")

-- without water the plant dries out
hold("zomboid:seeds_potato", 1)
events.emit("zomboid:seeds_potato.useon", bx, by, bz, pid, {0, 1, 0})
clock.reset(clock.hours + 100)
farming.update(bx, by + 1, bz)
check(block.get_variant(bx, by + 1, bz) == farming.DEAD, "dried out")

-- rain waters an outdoor plant
block.set(bx, by + 1, bz, 0, 0)
hold("zomboid:seeds_potato", 1)
events.emit("zomboid:seeds_potato.useon", bx, by, bz, pid, {0, 1, 0})
block.set_field(bx, by + 1, bz, "water", 0)
weather.set_raining(true)
farming.update(bx, by + 1, bz)
check(block.get_field(bx, by + 1, bz, "water") >= 99, "rain watered the plant")

app.close_world(false)
app.delete_world("zout")
