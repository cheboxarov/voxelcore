-- Map details: street decor, wrecks and story places, street lamps on the grid, lore notes, loot, house variants
app.config_packs({"zomboid"})
app.new_world("zdetails", "555", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local util = require "zomboid:decor/_util"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local power = require "zomboid:power"
local sandbox = require "zomboid:sandbox"
local lore = require "zomboid:lore"
local loot = require "zomboid:loot"
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
survival.get(pid).fresh = nil

local function goto_area(x, z)
    player.set_pos(pid, x + 0.5, G + 3, z + 0.5)
    app.sleep_until(function()
        return block.get(x - 10, G, z - 10) ~= -1 and block.get(x + 10, G, z + 10) ~= -1
            and block.get(x - 10, G, z + 10) ~= -1 and block.get(x + 10, G, z - 10) ~= -1
    end, 8000)
    app.sleep(0.3)
end

local function name_at(x, y, z)
    return block.name(block.get(x, y, z))
end

-- generator output: decor is everywhere, never in buildings or on paths, roads stay drivable
local SOFT = {["core:struct_air"] = true, ["zomboid:decor_blood"] = true, ["zomboid:decor_litter"] = true,
    ["zomboid:decor_tape"] = true, ["zomboid:decor_note"] = true, ["zomboid:decor_firepit"] = true}
local counts, found, solid, bad, ids = {}, {}, {}, {}, {}
local first_pass = {}
local B = town.BOUNDS
for wx = B[1] - 170, 560 do
    for wz = B[2] - 5, B[4] + 5 do
        local out = {}
        local kind = town.column(wx, wz, out)
        for _, e in ipairs(out) do
            local name, dy = e[2], e[1]
            if name:find("decor_") then
                counts[name] = (counts[name] or 0) + 1
                found[name] = found[name] or {}
                table.insert(found[name], {wx, G + dy, wz, e[3]})
            end
            if dy >= 1 and kind ~= "building" and not SOFT[name] and not name:find("^zomboid:road") then
                solid[util.key(wx, wz)] = true
            end
            local id = ids[name] or block.index(name)
            ids[name] = id
            check(id >= 0, "unknown block " .. name)
            if block.is_extended(id) and dy >= 1 and kind ~= "building" and name:find("decor_") then
                local sx, _, sz = block.get_size(id)
                for _, c in ipairs(util.footprint(wx, wz, e[3], sx, sz)) do
                    local k = town.column(c[1], c[2])
                    solid[util.key(c[1], c[2])] = true
                    if k == "building" or k == "path" then
                        table.insert(bad, name .. " at " .. c[1] .. "," .. c[2] .. " over " .. k)
                    end
                end
            end
        end
        if (wx + wz) % 97 == 0 then
            table.insert(first_pass, {wx, wz, #out > 0 and out[#out][2] or ""})
        end
    end
end
check(#bad == 0, table.concat(bad, "; "))
for _, c in ipairs(first_pass) do
    local out = {}
    town.column(c[1], c[2], out)
    check((#out > 0 and out[#out][2] or "") == c[3], "deterministic column " .. c[1] .. "," .. c[2])
end
local MUST = {
    streetlight = 100, traffic_light = 8, sign_stop = 8, hydrant = 30, bench = 30, trash_can = 60, mailbox = 15,
    dumpster = 10, bus_stop = 5, fence = 50, hedge = 30, wreck_burnt = 5, wreck_police = 2, bus_wreck = 1,
    heli_wreck = 1, police_barrier = 4, tape = 10, sandbags = 10, army_crate = 3, tent = 4, blood = 30,
    litter = 30, note = 5, stairs = 4, workbench = 2, bathtub = 1, toilet = 4, desk = 1, bookshelf = 1, toybox = 1,
}
local summary = {}
for short, need in pairs(MUST) do
    local n = counts["zomboid:decor_" .. short] or 0
    check(n >= need, short .. ": " .. n .. " < " .. need)
    table.insert(summary, short .. "=" .. n)
end
table.sort(summary)
log("decor: " .. table.concat(summary, " "))

local blocked = {}
for _, c in ipairs(town.cells()) do
    for i, d in ipairs(util.DIRS) do
        local along_x = d[1] == 0
        local edge = (d[1] < 0 and c.x0) or (d[1] > 0 and c.x1) or (d[2] < 0 and c.z0) or c.z1
        local a0, a1 = along_x and c.x0 or c.z0, along_x and c.x1 or c.z1
        local function at(t, k)
            if along_x then return t, edge + d[2] * k end
            return edge + d[1] * k, t
        end
        local mid = math.floor((a0 + a1) / 2)
        local mx, mz = at(mid, 1)
        local width = util.run(mx, mz, d[1], d[2], "road", 12)
        if width >= 5 then
            local best, run = 0, 0
            for k = 1, width do
                local free = true
                for t = a0, a1 do
                    free = free and not solid[util.key(at(t, k))]
                end
                run = free and run + 1 or 0
                best = math.max(best, run)
            end
            if best < 3 then table.insert(blocked, c.cx .. ":" .. c.cz .. "/" .. i) end
        end
    end
end
log("street sides closed off: " .. table.concat(blocked, ", "))
check(#blocked >= 1 and #blocked <= 2, "only the overturned bus blocks a street")

-- houses: the spawn house stays simple, every variant exists
local variants = {floors = 0, gable = 0, garage = 0, basement = 0, boarded = 0, looted = 0, kids = 0, study = 0}
local two_story, basement, garage, boarded, looted
for _, c in ipairs(town.cells()) do
    local p = town.plan(c.cx, c.cz)
    if p and p.kind == "house" and p.cx == c.cx and p.cz == c.cz then
        for k in pairs(variants) do
            if (k == "floors" and p.floors == 2) or (k ~= "floors" and p[k]) then
                variants[k] = variants[k] + 1
            end
        end
        two_story = two_story or (p.floors == 2 and p) or nil
        basement = basement or (p.basement and p) or nil
        garage = garage or (p.garage and p) or nil
        boarded = boarded or (p.boarded and p) or nil
        looted = looted or (p.looted and p) or nil
    end
end
local vs = {}
for k, v in pairs(variants) do
    check(v > 0, "house variant " .. k)
    table.insert(vs, k .. "=" .. v)
end
table.sort(vs)
log("house variants: " .. table.concat(vs, " "))
local spawn = town.spawn_point(1)
local home = town.plan(town.cell_at(math.floor(spawn[1]), math.floor(spawn[3])))
check(home.classic and home.floors == 1 and not home.gable and not home.garage and not home.basement
    and not home.looted and not home.boarded, "spawn house is the classic one")

-- the overturned bus and the heli wreck are placed as whole extended blocks
local function check_wreck(name)
    local spot = found[name][1]
    goto_area(spot[1], spot[3])
    local id = block.index(name)
    check(block.get(spot[1], spot[2], spot[3]) == id and not block.is_segment(spot[1], spot[2], spot[3]),
        name .. " origin: " .. name_at(spot[1], spot[2], spot[3]))
    local sx, sy, sz = block.get_size(id)
    local cells = util.footprint(spot[1], spot[3], spot[4], sx, sz)
    local far = cells[#cells]
    check(block.get(far[1], spot[2] + sy - 1, far[2]) == id, name .. " far segment: " .. name_at(far[1], spot[2] + sy - 1, far[2]))
    return spot
end
check_wreck("zomboid:decor_bus_wreck")
check_wreck("zomboid:decor_heli_wreck")
log("bus and helicopter wrecks are complete")

-- street lamps go out with the grid
local lamp
for _, s in ipairs(found["zomboid:decor_streetlight"]) do
    if math.abs(s[1] - spawn[1]) + math.abs(s[3] - spawn[3]) < 60 then lamp = s break end
end
goto_area(lamp[1], lamp[3])
check(name_at(lamp[1], lamp[2], lamp[3]) == "zomboid:decor_streetlight", "street lamp lit on day 1")
check(name_at(lamp[1], lamp[2] - 1, lamp[3]) == "zomboid:decor_pole", "lamp pole")
clock.reset((sandbox.get("power_shutoff_day") - 1) * 24 + 2)
power.refresh_lamps()
check(name_at(lamp[1], lamp[2], lamp[3]) == "zomboid:decor_streetlight_off", "street lamp dark after the shutoff")
check(block.get_rotation(lamp[1], lamp[2], lamp[3]) == lamp[4], "lamp keeps its rotation")
clock.reset(clock.START_HOUR)
power.refresh_lamps()
check(name_at(lamp[1], lamp[2], lamp[3]) == "zomboid:decor_streetlight", "lamp back on with the grid")
log("street lamp follows the grid")

-- lore notes: story places hand out their own story, notes found in houses get a home story
check(#lore.STORIES >= 5 and #lore.STORIES <= 15, "story count " .. #lore.STORIES)
for _, place in ipairs({"tent", "heli", "cordon", "bus", "police"}) do
    check(lore.place_story(place), "story for " .. place)
end
local invid = player.get_inventory(pid)
local note_item = item.index("zomboid:lore_note")
local places = {}
for _, s in ipairs(found["zomboid:decor_note"]) do
    local id = lore.story_at(s[1], s[3])
    check(lore.STORIES[id], "story at note " .. s[1] .. "," .. s[3])
    if lore.STORIES[id].place then places[lore.STORIES[id].place] = s end
end
for _, place in ipairs({"tent", "heli", "cordon", "bus", "police"}) do
    check(places[place], "note placed at " .. place)
end
local police = places.police
goto_area(police[1], police[3])
check(name_at(police[1], police[2], police[3]) == "zomboid:decor_note", "note block on the ground")
events.emit("zomboid:decor_note.interact", police[1], police[2], police[3], pid)
local slot = inventory.find_by_item(invid, note_item)
check(slot ~= nil, "note picked up")
check(inventory.get_data(invid, slot, "story") == lore.place_story("police"), "police story")
check(lore.current[pid] == lore.place_story("police"), "story opened for reading")
check(name_at(police[1], police[2], police[3]) == "core:air", "note removed from the ground")
inventory.set(invid, slot, 0, 0)
local _, hand = player.get_inventory(pid)
inventory.set(invid, hand, note_item, 1)
events.emit("zomboid:lore_note.use", pid)
local story = lore.STORIES[inventory.get_data(invid, hand, "story")]
check(story and story.place == nil, "a found note gets a home story")
log("notes: " .. #found["zomboid:decor_note"] .. " on the ground, read: " .. story.title)
inventory.set(invid, hand, 0, 0)

-- new containers have loot, looted houses have less
local box = inventory.create(16)
for _, kind in ipairs({"mailbox", "trash", "dumpster", "army", "workbench", "desk", "bookshelf", "toys"}) do
    check(loot.table_for(kind, 0, 0), "loot table " .. kind)
    local total = 0
    for _ = 1, 6 do
        for s = 0, 15 do inventory.set(box, s, 0, 0) end
        total = total + loot.fill(box, kind, 1000, 1000, clock.START_HOUR)
    end
    check(total > 0, "loot in " .. kind)
end
local function average(p)
    local x, z = town.to_world(p, p.mid + 1, p.d - 2)
    local total = 0
    for _ = 1, 60 do
        for s = 0, 15 do inventory.set(box, s, 0, 0) end
        total = total + loot.fill(box, "wardrobe", x, z, clock.START_HOUR)
    end
    return total / 60
end
local full, poor = average(home), average(looted)
log(string.format("wardrobe items: normal %.2f, looted %.2f", full, poor))
check(poor < full, "looted houses have less loot")

-- a two-storey house: walk up the stairs to the upper floor
local p = two_story
local sx, sz = town.to_world(p, 1, 1)
local tx, tz = town.to_world(p, 1, 2)
goto_area(sx, sz)
check(name_at(tx, G + 1, tz) == "zomboid:decor_stairs", "first step: " .. name_at(tx, G + 1, tz))
local ux, uz = town.to_world(p, 2, 5)
check(name_at(ux, G + 4, uz) == "base:planks", "upper floor")
player.set_pos(pid, sx + 0.5, G + 1.05, sz + 0.5)
player.set_vel(pid, 0, 0, 0)
app.sleep(0.5)
local _, feet = player.get_pos(pid)
feet = feet - (G + 1)
local mob = entities.get(player.get_entity(pid)):get_component("core:mob")
local dir = {tx - sx, tz - sz}
local top = 0
for _ = 1, 400 do
    mob.go(dir, 1.0, false, false)
    app.tick()
    local _, y = player.get_pos(pid)
    top = math.max(top, y - feet)
    if top >= G + 5 then break end
end
log(string.format("climbed to y=%.2f (upper floor at %d)", top, G + 5))
check(top >= G + 4.9, "stairs lead to the upper floor")

-- basement, garage, boarded and looted houses
local bx, bz = town.to_world(basement, 2, basement.d - 3)
goto_area(bx, bz)
check(name_at(bx, G - 4, bz) == "zomboid:decor_concrete", "basement floor")
check(name_at(bx, G - 2, bz) == "core:air", "basement room")
local dx, dz = town.to_world(basement, basement.hw - 2, 1)
check(name_at(dx, G, dz) == "zomboid:decor_stairs", "basement stairs: " .. name_at(dx, G, dz))
local function walk(from, to, ticks, done)
    local d = {to[1] - from[1], to[2] - from[2]}
    for _ = 1, ticks do
        mob.go(d, 1.0, false, false)
        app.tick()
        if done() then return true end
    end
    return false
end
local ex, ez = town.to_world(basement, basement.hw - 3, 1)
local tx1, tz1 = town.to_world(basement, basement.hw - 2, 1)
local tx2, tz2 = town.to_world(basement, basement.hw - 2, 5)
player.set_pos(pid, ex + 0.5, G + 1.05, ez + 0.5)
player.set_vel(pid, 0, 0, 0)
app.sleep(0.3)
walk({ex, ez}, {tx1, tz1}, 200, function()
    local x, _, z = player.get_pos(pid)
    return math.floor(x) == tx1 and math.floor(z) == tz1 and math.abs(x - tx1 - 0.5) < 0.2 and math.abs(z - tz1 - 0.5) < 0.2
end)
local down = walk({tx1, tz1}, {tx2, tz2}, 400, function()
    local _, y = player.get_pos(pid)
    return y - feet <= G - 2.9
end)
local _, by = player.get_pos(pid)
by = by - feet
log(string.format("walked down to y=%.2f (basement floor at %d)", by, G - 3))
check(down, "stairs lead down to the basement")
-- wrecks block in every rotation: no walking into them, the lane beside them stays open
local function blocks_walk(name, spot)
    local id = block.index(name)
    local sx, _, sz = block.get_size(id)
    local cells, inside = util.footprint(spot[1], spot[3], spot[4], sx, sz), {}
    for _, c in ipairs(cells) do inside[util.key(c[1], c[2])] = true end
    local function open(x, z)
        return not inside[util.key(x, z)] and not solid[util.key(x, z)] and town.column(x, z) == "road"
    end
    for _, d in ipairs(util.DIRS) do
        local lane = {}
        for _, c in ipairs(cells) do
            if not inside[util.key(c[1] + d[1], c[2] + d[2])] then table.insert(lane, {c[1] + d[1], c[2] + d[2]}) end
        end
        local px, pz = d[2] ~= 0 and 1 or 0, d[1] ~= 0 and 1 or 0
        table.sort(lane, function(a, b) return a[1] * px + a[2] * pz < b[1] * px + b[2] * pz end)
        local a, b = lane[1], lane[#lane]
        local ok = open(a[1] - px, a[2] - pz) and open(b[1] + px, b[2] + pz)
        for _, c in ipairs(lane) do ok = ok and open(c[1], c[2]) end
        if ok then
            goto_area(spot[1], spot[3])
            player.set_pos(pid, a[1] - px + 0.5, G + 1.05, a[2] - pz + 0.5)
            player.set_vel(pid, 0, 0, 0)
            app.sleep(0.2)
            local passed = walk({0, 0}, {px, pz}, 200, function()
                local x, _, z = player.get_pos(pid)
                return math.floor(x) == b[1] + px and math.floor(z) == b[2] + pz
            end)
            check(passed, name .. " rot " .. spot[4] .. ": the lane beside it is open")
            local m = lane[math.ceil(#lane / 2)]
            player.set_pos(pid, m[1] + 0.5, G + 1.05, m[2] + 0.5)
            player.set_vel(pid, 0, 0, 0)
            app.sleep(0.2)
            walk({0, 0}, {-d[1], -d[2]}, 60, function() return false end)
            local x, _, z = player.get_pos(pid)
            check(not inside[util.key(math.floor(x), math.floor(z))], name .. " rot " .. spot[4] .. ": walked into it")
            return true
        end
    end
    return false
end
local rots = {}
for name, list in pairs(found) do
    if name:find("wreck_") or name:find("bus_wreck") then
        for _, s in ipairs(list) do
            if s[2] == G + 1 and not rots[s[4]] and blocks_walk(name, s) then rots[s[4]] = name end
        end
    end
end
for r = 0, 3 do check(rots[r], "a wreck tested in rotation " .. r) end
local heli = found["zomboid:decor_heli_wreck"][1]
goto_area(heli[1], heli[3])
local colliders, collider = 0, block.index("zomboid:decor_collider")
for dx = 0, 6 do
    for dz = -6, 6 do
        if block.get(heli[1] + dx, G + 2, heli[3] + dz) == collider then colliders = colliders + 1 end
    end
end
check(colliders == 20, "heli colliders only under its 4x5 body: " .. colliders)
-- a broken wreck leaves no invisible wall behind
local w = found["zomboid:decor_wreck_burnt"][1]
goto_area(w[1], w[3])
local wid = block.index("zomboid:decor_wreck_burnt")
local wcells = util.footprint(w[1], w[3], w[4], 2, 3)
local far = wcells[#wcells]
check(block.get(far[1], G + 2, far[2]) == collider, "collider over the wreck")
local _, hand = player.get_inventory(pid)
inventory.set(player.get_inventory(pid), hand, item.index("zomboid:crowbar"), 1)
for _ = 1, 2000 do
    if block.get(far[1], G + 1, far[2]) ~= wid then break end
    events.emit("zomboid:.blockbreaking", wid, far[1], G + 1, far[2], pid)
end
inventory.set(player.get_inventory(pid), hand, 0, 0)
check(block.get(w[1], G + 1, w[3]) == 0, "wreck broken: " .. name_at(w[1], G + 1, w[3]))
for _, c in ipairs(wcells) do
    check(block.get(c[1], G + 2, c[2]) ~= collider, "collider left at " .. c[1] .. "," .. c[2])
end
log("wrecks block in all rotations, a broken one leaves no wall, heli colliders: " .. colliders)

local wx, wz = town.to_world(garage, garage.hw + 3, garage.d - 2)
goto_area(wx, wz)
check(name_at(wx, G + 1, wz) == "zomboid:decor_workbench", "garage workbench")
local cx, cz = town.car_spot(garage)
check(town.building_at(cx, cz) == "house", "garage car stands inside")
local fx, fz = town.to_world(boarded, 1, boarded.d - 1)
goto_area(fx, fz)
check(name_at(fx, G + 1, fz) == "zomboid:door_barricade", "boarded back door")
local lx, lz = town.to_world(looted, 1, looted.d - 1)
goto_area(lx, lz)
check(name_at(lx, G + 1, lz) == "core:air", "looted house back door broken")

app.close_world(false)
app.delete_world("zdetails")
