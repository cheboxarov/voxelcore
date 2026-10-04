-- Item and block scripts through the engine event path: eating, drinking, medicine, containers, water, barricades, sleep
app.config_packs({"zomboid"})
app.new_world("zscripts", "2024", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local inv = require "zomboid:inv"
local sandbox = require "zomboid:sandbox"
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

local function use(name)
    events.emit(name .. ".use", pid)
end

local function held_name()
    return item.name((inventory.get(invid, slot)))
end

-- drinking: four sips leave an empty bottle
hold("zomboid:water_bottle")
for i = 1, 4 do
    state.thirst = 40
    use("zomboid:water_bottle")
    check(state.thirst > 60, "sip " .. i)
end
check(held_name() == "zomboid:empty_bottle", "bottle emptied: " .. held_name())

-- eating
hold("zomboid:canned_beans", 2)
state.hunger = 30
use("zomboid:canned_beans")
check(state.hunger > 60, "ate beans")
check(select(2, inventory.get(invid, slot)) == 1, "one can left")
state.hunger = 100
use("zomboid:canned_beans")
check(select(2, inventory.get(invid, slot)) == 1, "not hungry - nothing eaten")

-- spoiled bread causes sickness
hold("zomboid:bread")
inventory.set_data(invid, slot, "born", clock.hours - 24 * 4)
state.hunger, state.sickness = 40, 0
use("zomboid:bread")
check(state.sickness > 0, "stale bread")

-- medicine
survival.add_wound(pid, "laceration")
hold("zomboid:bandage", 2)
use("zomboid:bandage")
check(survival.bleeding_count(state) == 0, "bandage stops bleeding")
check(select(2, inventory.get(invid, slot)) == 1, "bandage consumed")
hold("zomboid:disinfectant")
use("zomboid:disinfectant")
check(inventory.get_uses(invid, slot) == item.uses(item.index("zomboid:disinfectant")) - 1, "disinfectant used")
state.wounds, state.infection, state.health = {}, nil, 100

-- containers: loot once, crafted crates stay empty
local cx, cz = town.cell_at(math.floor(spawn[1]), math.floor(spawn[3]))
local p = town.plan(cx, cz)
local ox, oz = p.x0, p.z0
local fx, fy, fz = ox + p.mid - 1, G + 1, oz + p.d - 2
check(block.name(block.get(fx, fy, fz)) == "zomboid:fridge", "fridge at " .. fx .. "," .. fz)
hold("zomboid:bat")
events.emit("zomboid:fridge.interact", fx, fy, fz, pid)
local finv = inventory.get_block(fx, fy, fz)
local first = 0
for s = 0, inventory.size(finv) - 1 do first = first + select(2, inventory.get(finv, s)) end
events.emit("zomboid:fridge.interact", fx, fy, fz, pid)
local second = 0
for s = 0, inventory.size(finv) - 1 do second = second + select(2, inventory.get(finv, s)) end
log("fridge items: " .. first)
check(first > 0 and first == second, "loot generated once")
local px, py, pz = ox + p.mid, G + 1, oz + 2
block.set(px, py, pz, block.index("zomboid:crate"), 0)
events.emit("zomboid:crate.placed", px, py, pz, pid)
events.emit("zomboid:crate.interact", px, py, pz, pid)
check(inv.count(inventory.get_block(px, py, pz), "zomboid:plank") == 0
    and inventory.get(inventory.get_block(px, py, pz), 0) == 0, "placed crate is empty")
block.set(px, py, pz, 0, 0)

-- sink: tap water before the shutoff, nothing after
local sx, sy, sz = ox + 2, G + 1, oz + p.d - 2
check(block.name(block.get(sx, sy, sz)) == "zomboid:sink", "sink")
hold("zomboid:empty_bottle")
events.emit("zomboid:sink.interact", sx, sy, sz, pid)
check(inv.count(invid, "zomboid:water_bottle") == 1, "tap water")

-- stove boils raw water while there is power
hold("zomboid:dirty_water_bottle")
local stx, sty, stz = ox + 3, G + 1, oz + p.d - 2
if block.name(block.get(stx, sty, stz)) == "zomboid:stove" then
    events.emit("zomboid:stove.interact", stx, sty, stz, pid)
    check(held_name() == "zomboid:water_bottle", "boiled on the stove")
else
    log("small house without a stove, skipped")
end

-- hammer and crowbar on a window
local wx
for x = ox + 1, ox + p.w - 2 do
    if block.name(block.get(x, G + 1, oz)) == "zomboid:window" then wx = x break end
end
check(wx, "window")
inventory.add(invid, item.index("zomboid:plank"), 2)
inventory.add(invid, item.index("zomboid:nails"), 4)
hold("zomboid:hammer")
events.emit("zomboid:hammer.useon", wx, G + 1, oz, pid, {0, 0, -1})
check(block.name(block.get(wx, G + 1, oz)) == "zomboid:barricade", "hammered")
hold("zomboid:crowbar")
events.emit("zomboid:crowbar.useon", wx, G + 1, oz, pid, {0, 0, -1})
check(block.name(block.get(wx, G + 1, oz)) == "zomboid:window", "plank removed, glass intact")
check(inv.count(invid, "zomboid:plank") == 2, "plank returned")

-- bed: refused near zombies, sleeps otherwise
local bx, by, bz = ox + p.w - 2, G + 1, oz + p.d - 2
check(block.name(block.get(bx, by, bz)) == "zomboid:bed", "bed")
state.energy = 30
local z = zombies.spawn(bx - 2, G + 1, bz - 2, {})
local hours = clock.hours
events.emit("zomboid:bed.interact", bx, by, bz, pid)
check(clock.hours - hours < 0.5, "no sleep with a zombie around")
z:despawn()
app.tick()
events.emit("zomboid:bed.interact", bx, by, bz, pid)
check(clock.hours - hours > 3, "slept")

-- tap water stops after the shutoff day
clock.reset(24 * (sandbox.get("water_shutoff_day") - 1) + 10)
hold("zomboid:empty_bottle")
events.emit("zomboid:sink.interact", sx, sy, sz, pid)
check(held_name() == "zomboid:empty_bottle", "no tap water after shutoff")

-- lake: fill a bottle with raw water from the shore
local found
for r = 140, 400, 6 do
    for _, d in ipairs({{r, 0}, {-r, 0}, {0, r}, {0, -r}}) do
        player.set_pos(pid, d[1], 70, d[2])
        app.sleep_until(function() return block.get(d[1], 30, d[2]) ~= -1 end, 4000)
        for y = 45, 30, -1 do
            if block.name(block.get(d[1], y, d[2])) == "base:water" then
                found = {d[1], y, d[2]}
                break
            elseif block.is_solid_at(d[1], y, d[2]) then
                break
            end
        end
        if found then break end
    end
    if found then break end
end
check(found, "a lake exists")
local bottom = found[2]
while not block.is_solid_at(found[1], bottom, found[3]) do bottom = bottom - 1 end
player.set_pos(pid, found[1] + 0.5, found[2] + 1.9, found[3] + 1.5)
hold("zomboid:empty_bottle")
events.emit("zomboid:empty_bottle.useon", found[1], bottom, found[3], pid, {0, 1, 0})
log("lake at " .. table.concat(found, ",") .. ", bottom " .. bottom)
check(inv.count(invid, "zomboid:dirty_water_bottle") == 1, "raw water from the lake")

app.close_world(false)
app.delete_world("zscripts")
