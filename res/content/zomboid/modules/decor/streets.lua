local town = require "zomboid:town"
local util = require "zomboid:decor/_util"
local aftermath = require "zomboid:decor/aftermath"

local hash = town.hash

local streets = {zones = util.ZONES, kinds = {sidewalk = true, plaza = true}}

local SLOTS = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [7] = true, [10] = true}
local SPACING = 14
local CITY = {downtown = true, plaza = true}

local PLAZA = {}
for _, s in ipairs({{1, 0, 1}, {-1, 0, 3}, {0, 1, 0}, {0, -1, 2}}) do
    for _, t in ipairs({-2, 2}) do
        PLAZA[util.key(s[1] * 7 + s[2] * t, s[2] * 7 + s[1] * t)] = {{1, "zomboid:decor_bench", s[3]}}
    end
end
for _, c in ipairs({{6, 6}, {-6, 6}, {6, -6}, {-6, -6}}) do
    PLAZA[util.key(c[1], c[2])] = util.lamp(c[1] > 0 and 1 or 3)
end

local function road_dir(wx, wz, reach)
    local found
    for _, d in ipairs(util.DIRS) do
        if util.kind(wx + d[1] * reach, wz + d[2] * reach) == "road" then
            if found then
                return nil, true
            end
            found = d
        end
    end
    return found
end

local function near_entrance(wx, wz, dx, dz, curb)
    local across = curb and 1 or 2
    local width = util.run(wx + dx * across, wz + dz * across, dx, dz, "road", 12)
    for s = -1, 1 do
        local tx, tz = dz * s, dx * s
        for _, k in ipairs({curb and -2 or -1, across + width + (curb and 2 or 1)}) do
            if util.kind(wx + dx * k + tx, wz + dz * k + tz) == "path" then
                return true
            end
        end
    end
    local cx, cz = town.cell_at(wx - dx * 3, wz - dz * 3)
    local sx, sz = town.car_spot(cx and town.plan(cx, cz))
    return sx ~= nil and math.abs(wx - sx) <= 3 and math.abs(wz - sz) <= 3
end

local function maybe(t, wx, wz)
    return (t >= 0 and t <= 4) or (t == 7 and hash(wx, wz, 62) < 0.4)
        or (t == 10 and (hash(wx, wz, 64) < 0.6 or hash(wx, wz, 66) < 0.5))
end

local function place(out, entries)
    for _, e in ipairs(entries) do table.insert(out, e) end
    return true
end

local function bus_stop(wx, wz, dx, dz, t, out)
    local tx, tz = math.abs(dz), math.abs(dx)
    local sx, sz = wx - tx * (t - 1), wz - tz * (t - 1)
    if hash(sx, sz, 70) >= 0.08 then
        return false
    end
    local rot = util.face(dx, dz)
    local ox, oz = util.origin(sx, sz, rot, 3, 1)
    for i = 0, 2 do
        local x, z = sx + tx * i, sz + tz * i
        if util.kind(x, z) ~= "sidewalk" or aftermath.occupied(x, z) or util.kind(x - dx, z - dz) == "path" then
            return false
        end
    end
    if near_entrance(sx + tx, sz + tz, dx, dz, false) then
        return false
    end
    if wx == ox and wz == oz then
        place(out, {{1, "zomboid:decor_bus_stop", rot, 3}})
    end
    return true
end

local function corner(ctx, wx, wz, out)
    local wdx = util.kind(wx - 1, wz) == "road" and -1 or 1
    local wdz = util.kind(wx, wz - 1) == "road" and -1 or 1
    if CITY[ctx.zone] then
        return place(out, {{1, "zomboid:decor_pole", 0}, {2, "zomboid:decor_pole", 0},
            {3, "zomboid:decor_traffic_light", util.face(wdx, 0)}})
    end
    return place(out, {{1, "zomboid:decor_pole", 0}, {2, "zomboid:decor_sign_stop", util.face(0, wdz)}})
end

local function plaza(wx, wz, out)
    local dx, dz = wx - town.CENTER[1], wz - town.CENTER[2]
    local r2 = dx * dx + dz * dz
    local item = PLAZA[util.key(dx, dz)]
    if item == nil and r2 >= 25 and r2 <= 30 and math.abs(dx) > 1 and math.abs(dz) > 1 then
        item = {{0, "zomboid:decor_soil", 0}, {1, "base:flower", 0}}
    end
    return item ~= nil and place(out, item)
end

function streets.column(ctx, wx, wz, out)
    if ctx.kind == "plaza" then
        return plaza(wx, wz, out)
    end
    if ctx.kind ~= "sidewalk" or aftermath.occupied(wx, wz) then
        return false
    end
    local mx, mz = wx % SPACING, wz % SPACING
    local r = hash(wx, wz, 65)
    if not SLOTS[mx] and not SLOTS[mz] and r >= 0.04 then
        return false
    end
    local turn = hash(wx, wz, 61) < 0.5
    if r >= 0.03 and not turn and not maybe(mx, wx, wz) and not maybe(mz, wx, wz) then
        return false
    end
    local d, two = road_dir(wx, wz, 1)
    local curb = d ~= nil
    if d == nil then
        if turn and two and corner(ctx, wx, wz, out) then
            return true
        end
        d = road_dir(wx, wz, 2)
        if d == nil or util.kind(wx + d[1], wz + d[2]) ~= "sidewalk" then
            return false
        end
    end
    local dx, dz = d[1], d[2]
    local t = (dx == 0 and wx or wz) % SPACING
    local rot = util.face(dx, dz)
    local city = CITY[ctx.zone]
    local item
    if curb then
        if t == 0 then
            item = util.lamp(rot)
        elseif t == 7 and hash(wx, wz, 62) < 0.4 then
            item = {{1, "zomboid:decor_hydrant", 0}}
        elseif t == 10 and city and hash(wx, wz, 66) < 0.5 then
            local sign = hash(wx, wz, 67) < 0.6 and "speed" or "crossing"
            item = {{1, "zomboid:decor_pole", 0}, {2, "zomboid:decor_sign_" .. sign, util.face(dz, -dx)}}
        end
    elseif t >= 1 and t <= 3 and bus_stop(wx, wz, dx, dz, t, out) then
        return true
    elseif t == 4 and (city or hash(wx, wz, 63) < 0.35) then
        item = {{1, "zomboid:decor_trash_can", 0}}
    elseif t == 10 and hash(wx, wz, 64) < (city and 0.6 or 0.25) then
        item = {{1, "zomboid:decor_bench", rot}}
    end
    if item and not near_entrance(wx, wz, dx, dz, curb) then
        return place(out, item)
    end
    if r < 0.025 then
        return place(out, util.decal("litter", hash(wz, wx, 68)))
    elseif r < 0.03 then
        return place(out, util.decal("blood", hash(wz, wx, 69)))
    end
    return false
end

return streets
