-- New buildings: registry, generated blocks, climbable stairs, loot tables and residents
app.config_packs({"zomboid"})
app.new_world("zbld", "4242", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local population = require "zomboid:population"
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

local KINDS = {"apartments", "hospital", "school", "church", "supermarket", "warehouse", "bar", "diner", "motel",
    "fire_station", "military", "factory", "workshop"}

zombies.enabled = false
local pid = player.create("tester")
survival.get(pid).fresh = nil

local function wait_area(x0, z0, x1, z1)
    app.sleep_until(function()
        return block.get(x0, G, z0) ~= -1 and block.get(x1, G, z1) ~= -1
            and block.get(x0, G, z1) ~= -1 and block.get(x1, G, z0) ~= -1
    end, 20000)
end

local function columns(p)
    local list = {}
    for hz = 0, p.d - 1 do
        for hx = 0, p.w - 1 do
            local out = {}
            p.def.column(p, hx, hz, out)
            list[hz * p.w + hx] = out
        end
    end
    return list
end

-- registry and plans: deterministic, only existing blocks, loot for every container, doors not blocked by furniture
local blocked = {}
for _, kind in ipairs(KINDS) do
    local def = town.building_def(kind)
    check(def and def.title and def.color and def.zones, kind .. " registered")
    local a, b = {lot_w = 80, lot_d = 60, rot = 0}, {lot_w = 80, lot_d = 60, rot = 0}
    def.plan(a, function(n) return town.hash(7, 9, n) end)
    def.plan(b, function(n) return town.hash(7, 9, n) end)
    a.def, b.def = def, def
    local ca, cb = columns(a), columns(b)
    local blocks, containers, lamps = 0, {}, 0
    for i, out in pairs(ca) do
        check(#out == #cb[i], kind .. " deterministic")
        for j, e in ipairs(out) do
            check(e[2] == cb[i][j][2] and e[3] == cb[i][j][3], kind .. " deterministic block")
            local id = block.index(e[2])
            check(id ~= nil, kind .. " unknown block " .. tostring(e[2]))
            local cont = block.properties[id]["zomboid:loot"]
            if cont then containers[cont] = true end
            if e[2] == "zomboid:lamp" then lamps = lamps + 1 end
            blocks = blocks + 1
        end
    end
    for cont in pairs(containers) do
        check(loot.table_for(cont, 100000, 100000) or (def.loot or {})[cont], kind .. " has loot for " .. cont)
    end
    for _, entries in pairs(def.loot or {}) do
        for _, e in ipairs(entries) do
            check(item.index(e[1]) ~= nil, kind .. " loot item " .. e[1])
        end
    end
    check(lamps > 0, kind .. " has lamps")
    local function free(rows, x, z)
        local c = (rows[z] or ""):sub(x, x)
        local e = def.legend[c]
        return c == "" or c == " " or c == "D" or c:match("%d") or (e ~= nil and not e[1] and not e[2])
    end
    for f, rows in ipairs(def.floors) do
        for z, row in ipairs(rows) do
            for x = 1, #row do
                if row:sub(x, x) == "D" then
                    local along_x = not free(rows, x - 1, z) or not free(rows, x + 1, z)
                    local through_z = along_x and free(rows, x, z - 1) and free(rows, x, z + 1)
                    local through_x = not along_x and free(rows, x - 1, z) and free(rows, x + 1, z)
                    if not (through_z or through_x) then table.insert(blocked, string.format("%s %d:%d,%d", kind, f, x - 1, z - 1)) end
                end
            end
        end
    end
    log(kind, a.w .. "x" .. a.d, "blocks " .. blocks, "door " .. a.door)
end
check(#blocked == 0, "doors blocked by furniture: " .. table.concat(blocked, " "))

-- every kind in the current town is generated exactly as its def describes, rotated ones first
local placed, present = {}, 0
for _, c in ipairs(town.cells()) do
    local p = town.plan(c.cx, c.cz)
    if p and (placed[p.kind] == nil or (placed[p.kind].rot == 0 and p.rot ~= 0)) then
        placed[p.kind] = p
    end
end
for _, kind in ipairs(KINDS) do
    local p = placed[kind]
    if p then
        present = present + 1
        local x0, z0 = town.to_world(p, 0, 0)
        local x1, z1 = town.to_world(p, p.w - 1, p.d - 1)
        player.set_pos(pid, (x0 + x1) / 2, G + 30, (z0 + z1) / 2)
        wait_area(math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1))
        local cols, wrong, total = columns(p), 0, 0
        for i, out in pairs(cols) do
            local hx, hz = i % p.w, math.floor(i / p.w)
            local x, z = town.to_world(p, hx, hz)
            for _, e in ipairs(out) do
                if e[2] ~= "core:struct_air" and e[2] ~= "zomboid:car_spawner" and not block.is_segment(x, G + e[1], z) then
                    total = total + 1
                    if block.name(block.get(x, G + e[1], z)) ~= e[2] then wrong = wrong + 1 end
                end
            end
        end
        log("generated", kind, "rot", p.rot, "blocks", total, "mismatched", wrong)
        check(wrong == 0, kind .. " generated as planned")
        if p.def.car_color then
            local sx, sz = town.car_spot(p)
            local color
            app.sleep_until(function()
                for _, uid in ipairs(entities.get_all_in_radius({sx + 0.5, G + 1, sz + 0.5}, 2)) do
                    local car = entities.get(uid):get_component("zomboid:car")
                    if car then color = car.data.color end
                end
                return color ~= nil
            end, 5000)
            log(kind, "car", color)
            check(color == p.def.car_color, kind .. " car colour")
        end
    end
end

log("kinds in town", present, "of", #KINDS)
check(present == #KINDS, "every new building appears in town")

-- stamp each building into open land to check it as a player would
local AIR = block.index("core:air")
local function stamp(kind, ox, oz)
    local def = town.building_def(kind)
    local p = {kind = kind, def = def, rot = 0, lot_w = 80, lot_d = 60, cx = 1000, cz = 1000}
    def.plan(p, function(n) return town.hash(ox, oz, n) end)
    p.x0, p.z0, p.x1, p.z1 = ox, oz, ox + p.w - 1, oz + p.d - 1
    player.set_pos(pid, ox + p.w / 2, G + 40, oz + p.d / 2)
    wait_area(p.x0 - 1, p.z0 - 1, p.x1 + 1, p.z1 + 1)
    for x = p.x0 - 1, p.x1 + 1 do
        for z = p.z0 - 1, p.z1 + 1 do
            for y = G + 1, G + 24 do block.set(x, y, z, AIR, 0) end
        end
    end
    for i, out in pairs(columns(p)) do
        local x, z = p.x0 + i % p.w, p.z0 + math.floor(i / p.w)
        for _, e in ipairs(out) do
            local id = e[2] == "core:struct_air" and AIR or block.index(e[2])
            block.set(x, G + e[1], z, id, block.compose_state({e[3], 0, 0}))
        end
    end
    return p
end

local function walk(tx, tz)
    local mob = entities.get(player.get_entity(pid)):get_component("core:mob")
    for _ = 1, 400 do
        local x, _, z = player.get_pos(pid)
        local dx, dz = tx + 0.5 - x, tz + 0.5 - z
        if dx * dx + dz * dz < 0.04 then
            break
        end
        mob.go({dx, dz}, 0.6, false, false)
        app.tick()
    end
    local _, vy = player.get_vel(pid)
    player.set_vel(pid, 0, vy, 0)
end

local function stair_route(p)
    local rows = p.def.floors[1]
    local l0, l1
    for z, row in ipairs(rows) do
        local i1, i8 = row:find("1", 1, true), row:find("8", 1, true)
        if i1 and i8 and math.abs(i1 - i8) == 1 then
            local dir = (rows[z + 1] or ""):sub(i1, i1) == "2" and 1 or -1
            l0, l1 = {i1 - 1, z - 1, dir}, {i8 - 1, z - 1, dir}
        end
    end
    check(l0, p.kind .. " has a stair core")
    local function at(x, z)
        return {town.to_world(p, p.flip and p.w - 1 - x or x, z)}
    end
    local entry, landing = l0[2] - l0[3], l0[2] + 4 * l0[3]
    return {at(l0[1], entry), at(l0[1], landing), at(l1[1], landing), at(l1[1], entry)}
end

local function climb(p)
    local path, climbs = stair_route(p), 0
    for f = 1, #p.def.floors - 1 do
        for _, row in ipairs(p.def.floors[f]) do
            if row:find("1", 1, true) then climbs = f end
        end
    end
    player.set_pos(pid, path[1][1] + 0.5, G + 2, path[1][2] + 0.5)
    player.set_vel(pid, 0, 0, 0)
    app.sleep(0.3)
    for _ = 1, climbs do
        for _, pt in ipairs(path) do walk(pt[1], pt[2]) end
    end
    local _, y = player.get_pos(pid)
    log(p.kind, "rot", p.rot, "climbed to y", y, "floors", climbs)
    check(math.abs(y - (G + 1.9 + 4 * climbs)) < 0.3, p.kind .. " stairs lead to the top floor")
end

local ox = 300
local upstairs = 0
for _, kind in ipairs(KINDS) do
    local p = stamp(kind, ox, -20)
    local def = p.def
    local door = false
    for hz = 0, p.d - 1 do
        local x, z = town.to_world(p, p.door, hz)
        door = door or block.name(block.get(x, G + 1, z)) == "base:wooden_door"
            or (hz == 0 and block.get(x, G + 1, z) == 0 and block.get(x, G + 2, z) == 0)
    end
    check(door, kind .. " front door in the p.door column")

    local upper = 0
    for _, row in ipairs(def.floors[2] or {}) do
        if row:find("[%.:L;]") then upper = upper + 1 end
    end
    if upper > 0 then
        climb(p)
    end

    local n = population.seed_building(p, "test:" .. kind)
    local high = 0
    for _, comp in pairs(zombies.registry) do
        local pos = comp.get_pos()
        local hx, hz = pos[1] - p.x0, pos[3] - p.z0
        if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d and pos[2] > G + 4 then high = high + 1 end
    end
    log(kind, "residents", n, "upstairs", high)
    check(n > 0 or zombies.count() >= zombies.limit(), kind .. " has residents")
    upstairs = upstairs + high
    for uid in pairs(zombies.registry) do
        local e = entities.get(uid)
        if e then e:despawn() end
    end
    app.tick()
    ox = ox + p.w + 8
end

check(upstairs > 0, "residents on upper floors")

-- stairs in generated buildings work in every facade rotation
for _, kind in ipairs({"apartments", "school", "hospital", "fire_station", "warehouse", "factory"}) do
    local p = placed[kind]
    if p then
        local x0, z0 = town.to_world(p, 0, 0)
        local x1, z1 = town.to_world(p, p.w - 1, p.d - 1)
        player.set_pos(pid, (x0 + x1) / 2, G + 30, (z0 + z1) / 2)
        wait_area(math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1))
        climb(p)
    end
end

-- a zombie under or above the player takes the stairs to the player's floor
survival.get(pid).setup = nil
for _, kind in ipairs({"apartments", "hospital"}) do
    local p = placed[kind]
    local x0, z0 = town.to_world(p, 0, 0)
    local x1, z1 = town.to_world(p, p.w - 1, p.d - 1)
    player.set_pos(pid, (x0 + x1) / 2, G + 30, (z0 + z1) / 2)
    wait_area(math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1))
    local ground, best, best_d = {}, nil, -1
    local entry = stair_route(p)[1]
    for _, s in ipairs(p.def.spots) do
        if s[2] == 0 then ground[s[1] * 1000 + s[3]] = true end
    end
    for _, s in ipairs(p.def.spots) do
        local x, z = town.to_world(p, p.flip and p.w - 1 - s[1] or s[1], s[3])
        local d = math.abs(x - entry[1]) + math.abs(z - entry[2])
        if s[2] == 1 and ground[s[1] * 1000 + s[3]] and d > best_d then
            best, best_d = {x, z}, d
        end
    end
    check(best, kind .. " has a room above a room")
    local x, z = best[1], best[2]
    for _, up in ipairs({true, false}) do
        player.set_pos(pid, x + 0.5, G + (up and 5.9 or 1.9), z + 0.5)
        player.set_vel(pid, 0, 0, 0)
        survival.get(pid).health = 100
        local uid = zombies.spawn(x, G + (up and 1 or 5), z, {kind = "normal"}):get_uid()
        app.tick()
        local comp = zombies.registry[uid]
        comp.hear({player.get_pos(pid)}, pid)
        local ticks = 0
        repeat
            app.tick()
            ticks = ticks + 1
            local y = comp.get_pos()[2]
        until ticks >= 2400 or (up and y > G + 5.5 or not up and y < G + 2.5)
        log(kind, up and "upstairs" or "downstairs", "from", best_d, "blocks off the stairs, ticks", ticks,
            "zombie y", comp.get_pos()[2])
        check(ticks < 2400,
            kind .. " zombie follows the player " .. (up and "upstairs" or "downstairs"))
        entities.get(uid):despawn()
        app.tick()
    end
end

app.close_world(false)
app.delete_world("zbld")
