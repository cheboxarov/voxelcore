local rural = require "zomboid:buildings/_rural"

local put, surface = rural.put, rural.surface

local campsite = {
    kind = "campsite",
    title = "кемпинг",
    color = {150, 120, 70},
    zones = {"forest"},
    weight = 3,
    cells = 1,
    loot = {
        crate = {
            {"zomboid:canned_beans", 4, 1, 3}, {"zomboid:water_bottle", 3, 1, 2}, {"zomboid:matches", 3, 1, 1},
            {"zomboid:hiking_bag", 2, 1, 1}, {"zomboid:raincoat", 2, 1, 1}, {"zomboid:flashlight", 2, 1, 1},
            {"zomboid:cooking_pot", 1, 1, 1}, {"zomboid:map", 1, 1, 1}, {"zomboid:knife", 1, 1, 1},
            {"zomboid:soda", 2, 1, 2}, {"zomboid:chips", 2, 1, 2},
        },
    },
}

local TENTS = {{2, 3}, {8, 3}, {16, 3}, {21, 3}, {2, 14}, {9, 15}, {19, 14}}
local FIRE = {13, 10}

function campsite.plan(p, hash)
    p.w, p.d = 26, 22
    p.door = FIRE[1]
    p.tents = {}
    for i, t in ipairs(TENTS) do
        if hash(i) < 0.75 then
            table.insert(p.tents, {t[1], t[2], hash(i + 10) < 0.5 and "zomboid:nature_tent_green" or "zomboid:nature_tent_orange"})
        end
    end
    p.car = {23, 9}
end

-- an A-frame tent 3 wide and 4 deep, open at the front (local z = 0)
local function tent(out, x, z, canvas)
    if x == 1 then
        put(out, 2, canvas)
        if z == 3 then put(out, 1, canvas) end
        if z == 1 then put(out, 1, "zomboid:bed", 2) end
        if z == 2 then put(out, 1, "zomboid:crate", 2) end
        return
    end
    put(out, 1, canvas)
end

function campsite.column(p, x, z, out)
    if x == p.car[1] and z == p.car[2] then
        surface(out, "zomboid:nature_dirt_path")
        put(out, 1, "zomboid:car_spawner")
        return
    end
    for _, t in ipairs(p.tents) do
        local tx, tz = x - t[1], z - t[2]
        if tx >= 0 and tx < 3 and tz >= 0 and tz < 4 then
            tent(out, tx, tz, t[3])
            return
        end
    end
    local fx, fz = x - FIRE[1], z - FIRE[2]
    if fx == 0 and fz == 0 then
        surface(out, "base:sand")
        put(out, 1, "zomboid:campfire")
    elseif math.abs(fx) <= 1 and math.abs(fz) <= 1 then
        surface(out, "base:sand")
    elseif math.abs(fz) == 2 and math.abs(fx) <= 1 then
        put(out, 1, "zomboid:nature_log", 0)
    elseif math.abs(fx) == 2 and math.abs(fz) <= 1 then
        put(out, 1, "zomboid:nature_log", 1)
    elseif x == p.door and z < FIRE[2] - 2 or (z == 8 and x > FIRE[1] and x < p.car[1]) then
        surface(out, "zomboid:nature_dirt_path")
    end
end

return campsite
