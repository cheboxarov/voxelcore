-- Fires (unattended campfire, spread, damage, dousing, rain), city map exploration, radio and TV broadcasts
app.config_packs({"zomboid"})
app.new_world("zfire", "6161", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local weather = require "zomboid:weather"
local fire = require "zomboid:fire"
local mapping = require "zomboid:mapping"
local radio = require "zomboid:radio"
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
weather.set_raining(false)
weather.next_change = clock.hours + 1000

local function hold(name, count, uses)
    inventory.set(invid, slot, item.index(name), count or 1)
    if uses then
        inventory.set_data(invid, slot, "uses", uses)
    end
end

local cx, cz = town.cell_at(math.floor(spawn[1]), math.floor(spawn[3]))
local p = town.plan(cx, cz)
local ox, oz = p.x0, p.z0

-- an unattended campfire next to planks starts a fire
local fx, fy, fz = ox + p.w + 2, G + 1, oz - 1
block.set(fx, fy, fz, block.index("zomboid:campfire"), 0)
for dx = 1, 4 do
    block.set(fx + dx, fy, fz, block.index("base:planks"), 0)
end
check(fire.is_flammable(block.index("base:planks")), "planks burn")
check(not fire.is_flammable(block.index("zomboid:campfire")), "campfire itself does not")
check(fire.unattended(fx, fy, fz) == false, "attended campfire is safe")
player.set_pos(pid, fx + 40.5, G + 2, fz + 0.5)
local ignited = false
for _ = 1, 400 do
    if fire.unattended(fx, fy, fz) then ignited = true break end
end
check(ignited, "unattended campfire ignited")
local burning = 0
for dx = -1, 1 do
    for dz = -1, 1 do
        for dy = 0, 1 do
            if block.name(block.get(fx + dx, fy + dy, fz + dz)) == "zomboid:fire" then burning = burning + 1 end
        end
    end
end
check(burning == 1, "something next to the campfire caught fire")
block.set(fx + 1, fy, fz, block.index("zomboid:fire"), 0)
app.sleep(25)
local burnt = 0
for dx = 1, 4 do
    if block.name(block.get(fx + dx, fy, fz)) ~= "base:planks" then burnt = burnt + 1 end
end
log("planks burnt after 25s: " .. burnt .. ", fires " .. fire.count)
check(burnt >= 2, "fire spread along the planks")

-- standing in fire hurts, water puts it out
for dx = 1, 4 do
    block.set(fx + dx, fy, fz, 0, 0)
end
block.set(fx + 2, fy, fz, block.index("zomboid:fire"), 0)
app.tick()
player.set_pos(pid, fx + 2.5, fy + 0.95, fz + 0.5)
state.health = 100
app.sleep(2)
check(state.health < 100, "burned: " .. state.health)
hold("zomboid:water_bottle", 1, 4)
events.emit("zomboid:fire.interact", fx + 2, fy, fz, pid)
check(block.get(fx + 2, fy, fz) == 0, "doused")
check(inventory.get_uses(invid, slot) == 3, "one sip of water used")
state.health = 100

-- rain puts out fires in the open
block.set(fx + 3, fy, fz, block.index("zomboid:fire"), 0)
player.set_pos(pid, fx + 20.5, G + 2, fz + 0.5)
weather.set_raining(true)
app.sleep(15)
check(block.get(fx + 3, fy, fz) == 0, "rain extinguished the fire")
weather.set_raining(false)
weather.next_change = clock.hours + 1000

-- matches set a block on fire
block.set(fx + 4, fy, fz, block.index("base:planks"), 0)
hold("zomboid:matches", 1, 8)
events.emit("zomboid:matches.useon", fx + 4, fy, fz, pid, {0, 1, 0})
check(block.name(block.get(fx + 4, fy, fz)) == "zomboid:fire", "set on fire with matches")
check(inventory.get_uses(invid, slot) == 7, "a match used")
fire.extinguish(fx + 4, fy, fz)

-- city map: explored area is remembered, the map needs the item
player.set_pos(pid, spawn[1], spawn[2], spawn[3])
app.sleep(2)
check(mapping.is_explored(pid, spawn[1], spawn[3]), "spawn explored")
check(not mapping.is_explored(pid, spawn[1] + 120, spawn[3] + 120), "far corner unknown")
check(not mapping.has_map(pid), "no map yet")
inv.give(pid, "zomboid:map", 1)
check(mapping.has_map(pid), "has a map")
local gp = town.find("gas_station")
local c = mapping.color(gp.x0 + 1, gp.z0 + 1)
check(c == gp.def.color, "gas station on the map")
check(mapping.color(2, 20) == mapping.COLORS.road, "road on the map")
local saved = survival.serialize()[tostring(pid)]
check(saved.explored and saved.explored[math.floor(spawn[1] / 8) .. ":" .. math.floor(spawn[3] / 8)], "exploration is saved")

-- a second local player explores and listens on their own
local pid2 = player.create("second")
survival.get(pid2).fresh = nil
player.set_pos(pid2, spawn[1] + 60, spawn[2], spawn[3])
app.sleep(2)
check(mapping.is_explored(pid2, spawn[1] + 60, spawn[3]), "second player explored own area")
check(not mapping.is_explored(pid2, spawn[1] - 40, spawn[3] - 40), "second player does not share the first one's map")
check(not survival.get(pid2).radio_on, "radio state is per player")

-- radio: news in the first days, then automatic messages and static
check(radio.broadcast(10, false):find("^Радио:"), "day 1 news")
check(radio.broadcast(24 + 10, true):find("^ТВ:"), "day 2 TV news")
check(radio.broadcast(24 * 4 + 10, true) == nil, "TV silent after day 3")
check(radio.broadcast(24 * 7 + 10, false) == "*шипение помех*", "static later")
inv.give(pid, "zomboid:radio", 1)
check(radio.toggle(pid), "radio on")
state.radio_slot = nil
check(radio.listen(pid) ~= nil, "heard a broadcast")
check(radio.listen(pid) == nil, "one message per slot")
local heard = #state.messages
clock.reset(clock.hours + radio.SLOT_HOURS)
app.sleep(3)
check(#state.messages > heard or state.radio_slot == math.floor(clock.hours / radio.SLOT_HOURS), "next broadcast")
check(not radio.toggle(pid), "radio off")

-- TV works only with power
local tx, ty, tz = ox + 1, G + 1, oz + 1
check(block.name(block.get(tx, ty, tz)) == "zomboid:tv", "tv in the living room: " .. block.name(block.get(tx, ty, tz)))
clock.reset(24 + 12)
local before = #state.messages
events.emit("zomboid:tv.interact", tx, ty, tz, pid)
check(state.messages[#state.messages].text:find("^ТВ:"), "tv news")
clock.reset(24 * (require("zomboid:sandbox").get("power_shutoff_day") - 1) + 12)
events.emit("zomboid:tv.interact", tx, ty, tz, pid)
check(state.messages[#state.messages].text:find("электричества"), "tv dead without power")

app.close_world(false)
app.delete_world("zfire")
