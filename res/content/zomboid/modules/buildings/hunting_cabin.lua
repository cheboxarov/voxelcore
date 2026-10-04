local rural = require "zomboid:buildings/_rural"

local put, room = rural.put, rural.room

local cabin = {
    kind = "hunting_cabin",
    title = "охотничьи домики",
    color = {120, 84, 50},
    zones = {"forest"},
    weight = 4,
    cells = 1,
    loot = {
        crate = {
            {"zomboid:shotgun", 4, 1, 1}, {"zomboid:shotgun_shells", 6, 3, 10}, {"zomboid:knife", 2, 1, 1},
            {"zomboid:canned_beans", 2, 1, 3}, {"zomboid:matches", 2, 1, 1}, {"zomboid:map", 1, 1, 1},
        },
        wardrobe = {
            {"zomboid:leather_jacket", 3, 1, 1}, {"zomboid:boots", 3, 1, 1}, {"zomboid:knit_hat", 2, 1, 1},
            {"zomboid:hiking_bag", 2, 1, 1}, {"zomboid:shotgun_shells", 3, 2, 6}, {"zomboid:axe", 2, 1, 1},
            {"zomboid:flashlight", 1, 1, 1},
        },
    },
}

function cabin.plan(p, hash)
    p.w, p.d = 9, 8
    p.door = 4
    p.oz = 18
    p.logs = hash(1) < 0.5
end

function cabin.column(p, x, z, out)
    room(out, x, z, p.w, p.d, {wall = "zomboid:nature_spruce_log", door = {p.door, 0}})
    if x == 0 or z == 0 or x == p.w - 1 or z == p.d - 1 then
        return
    end
    local d = p.d
    if x == p.w - 2 and z >= d - 3 then
        put(out, 1, "zomboid:bed", 3)
    elseif x == 1 and z == d - 2 then
        put(out, 1, "zomboid:wardrobe", 2)
    elseif x == 1 and z == 1 then
        put(out, 1, "zomboid:crate", 1)
    elseif x == 2 and z == d - 2 then
        put(out, 1, "zomboid:stove", 2)
    elseif x == 3 and z == d - 2 then
        put(out, 1, "zomboid:kitchen_cabinet", 2)
    end
end

function cabin.lot(p, x, z, out)
    if z == -4 and x == p.door + 3 then
        if out then put(out, 1, "zomboid:campfire") end
        return "yard"
    end
    if x == -2 and z >= 1 and z <= 5 then
        if out then
            put(out, 1, "zomboid:nature_log", 1)
            if p.logs or z % 2 == 1 then put(out, 2, "zomboid:nature_log", 1) end
        end
        return "yard"
    end
    return nil
end

return cabin
