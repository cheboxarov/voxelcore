local kit = require "zomboid:buildings/_kit"

local FLAT = {
    "#WW#WW#W#",
    "#t.....u#",
    "W.......#",
    "W...L..u#",
    "#.......#",
    "W.......D",
    "#.......#",
    "#%%D%%%%#",
    "#ko.n.f.#",
    "W...L...#",
    "#k.k....#",
    "#%D%%%D%#",
    "W..L%::m#",
    "#b..%:::#",
    "Wb..%n;:#",
    "#..w%:::#",
    "#WW###W##",
}

local HALL = {
    "#DD#", "....", ".L..", "....", "....", "....", "....", ".L..", "....", "....", "....",
    "%18%", "%27%", "%36%", "%45%", "%44%", "####",
}

local function storey(front, stairs)
    local rows = {}
    for i, flat in ipairs(FLAT) do
        local hall = HALL[i]
        if i == 1 then hall = front end
        if not stairs then hall = hall:gsub("%d", "0") end
        rows[i] = flat .. hall .. flat:reverse()
    end
    return rows
end

return kit.building {
    kind = "apartments",
    title = "многоэтажки",
    color = {150, 100, 90},
    zones = {"downtown", "suburb"},
    weight = 5,
    cells = 1,
    materials = {
        wall = {"base:brick", "zomboid:bld_concrete", "zomboid:bld_plaster"},
        floor = {"base:planks", "zomboid:carpet"},
        stair = "zomboid:bld_concrete",
    },
    floors = {
        storey("#DD#", true),
        storey("#WW#", true),
        storey("#WW#", true),
        storey("#WW#", false),
    },
    zombies = {count = {3, 6}},
}
