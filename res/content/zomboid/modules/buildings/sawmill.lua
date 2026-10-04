local rural = require "zomboid:buildings/_rural"

local put, room, surface = rural.put, rural.room, rural.surface

local sawmill = {
    kind = "sawmill",
    title = "лесопилка",
    color = {160, 110, 60},
    zones = {"forest"},
    weight = 1,
    cells = 1,
    loot = {
        crate = {
            {"zomboid:axe", 4, 1, 1}, {"zomboid:plank", 5, 4, 12}, {"zomboid:nails", 4, 10, 30},
            {"zomboid:hammer", 3, 1, 1}, {"zomboid:gas_can", 2, 1, 1}, {"zomboid:gas_can_empty", 2, 1, 1},
            {"zomboid:matches", 2, 1, 1}, {"zomboid:book_carpentry_1", 1, 1, 1}, {"zomboid:stick", 2, 2, 4},
        },
    },
}

local SHED = {2, 3, 14, 8}
local OFFICE = {3, 14, 6, 6}

function sawmill.plan(p, hash)
    p.w, p.d = 30, 24
    p.door = 15
    p.pile = 2 + math.floor(hash(1) * 2)
    p.car = {24, 19}
end

local function shed(out, x, z)
    local w, d = SHED[3], SHED[4]
    put(out, 0, "base:planks")
    put(out, 4, "zomboid:nature_metal_roof")
    local post = (x == 0 or x == w - 1 or x % 4 == 0) and (z == 0 or z == d - 1)
    for dy = 1, 3 do put(out, dy, post and "zomboid:nature_spruce_log" or "core:struct_air") end
    if z == 4 and x >= 2 and x <= 10 then
        put(out, 1, "base:metal")
    elseif z == 4 and x == 11 then
        put(out, 1, "zomboid:crate", 0)
    elseif z == 2 and x >= 3 and x <= 8 then
        put(out, 1, "zomboid:nature_log", 0)
    end
end

function sawmill.column(p, x, z, out)
    if x == p.car[1] and z == p.car[2] then
        surface(out, "zomboid:nature_dirt_path")
        put(out, 1, "zomboid:car_spawner")
        return
    end
    local sx, sz = x - SHED[1], z - SHED[2]
    if sx >= 0 and sx < SHED[3] and sz >= 0 and sz < SHED[4] then
        shed(out, sx, sz)
        return
    end
    local ox, oz = x - OFFICE[1], z - OFFICE[2]
    if room(out, ox, oz, OFFICE[3], OFFICE[4], {wall = "zomboid:plank_wall", door = {2, 0}}) then
        if ox == 1 and oz == OFFICE[4] - 2 then
            put(out, 1, "zomboid:crate", 2)
        elseif ox == OFFICE[3] - 2 and oz == OFFICE[4] - 2 then
            put(out, 1, "zomboid:wardrobe", 2)
        end
        return
    end
    if x >= 18 and x <= 27 and (z >= 3 and z <= 5 or z >= 8 and z <= 10) then
        local top = z <= 5 and p.pile or 3
        for dy = 1, top do put(out, dy, "zomboid:nature_log", 0) end
    elseif x >= 18 and x <= 22 and z >= 14 and z <= 16 then
        put(out, 1, "base:planks")
        put(out, 2, "base:planks")
    elseif x == p.door and z <= 12 or z == 12 and x >= 5 and x < p.door or z == 13 and x == OFFICE[1] + 2 then
        surface(out, "zomboid:nature_dirt_path")
    end
end

return sawmill
