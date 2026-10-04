-- Zombies break into a closed house to reach the player
app.config_packs({"zomboid"})
app.new_world("zsiege", "31337", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
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
    return block.get(math.floor(spawn[1]) + 20, G, math.floor(spawn[3]) - 20) ~= -1
        and block.get(math.floor(spawn[1]) - 20, G, math.floor(spawn[3]) - 20) ~= -1
end, 8000)
app.sleep(1)
local state = survival.get(pid)
state.health = 100

local px, _, pz = player.get_pos(pid)
local cx, cz = math.floor(px / 32), math.floor(pz / 32)
local p = town.plan(cx, cz)
local ox, oz = cx * 32 + p.x0, cz * 32 + p.z0
check(block.name(block.get(ox + p.door, G + 1, oz)) == "base:wooden_door", "front door closed")

local z = zombies.spawn(ox + p.door, G + 1, oz - 5, {})
local comp = z:get_component("zomboid:zombie")
local reached = false
for _ = 1, 120 do
    comp.hear({player.get_pos(pid)}, pid, 5)
    app.sleep(0.5)
    local zp = comp.get_pos()
    if zp[3] > oz + 0.5 then
        reached = true
        break
    end
end
local opened = {}
for x = ox, ox + p.w - 1 do
    for y = G + 1, G + 2 do
        local name = block.name(block.get(x, y, oz))
        if name == "core:air" or name == "zomboid:window_broken" then
            table.insert(opened, x .. ":" .. y .. "=" .. name)
        end
    end
end
log("zombie inside: " .. tostring(reached) .. ", breaches: " .. table.concat(opened, " "))
check(reached, "zombie got inside")
check(#opened > 0, "door or window broken")

app.close_world(false)
app.delete_world("zsiege")
