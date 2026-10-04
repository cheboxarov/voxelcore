local kit = require "zomboid:buildings/_kit"

local CLASS = {
    "#WW#WW#WW#WW",
    "#...........",
    "#B..d.d.d.d.",
    "WB...L....L.",
    "#B.d..d.d.d.",
    "WB...L....L.",
    "#...d.d.d.d.",
    "#kk........w",
    "#%%%%%%%%D%%",
    "W...........",
    "#.....L.....",
}

local LOBBY = {
    "#WWWW#DDD#WWWW#",
    "#.............#",
    "#%%%..........#",
    "#44%.....L....#",
    "#45%..........#",
    "#36%..........#",
    "#27%...kkk....#",
    "#18%.....L....#",
    "#.............#",
    "...............",
    "...L.......L...",
}

local LIBRARY = {
    "#WWWW#WWW#WWWW#",
    "#.s.s.s.s.s.s.#",
    "#%%%..........#",
    "#44%.....L....#",
    "#45%.dd..dd...#",
    "#36%..........#",
    "#27%.dd..dd...#",
    "#18%.....L....#",
    "#.............#",
    "...............",
    "...L.......L...",
}

local BACK = {
    {"#%%%%D%%%%%%%%%D%%%%", "%%%%%%%%%D%%%%%%%%#"},
    {"#lllll.........lllll", "%.................#"},
    {"#...................", "%.ddd.ddd.ddd.ddd.W"},
    {"#pppppppp...pppppppp", "%.................#"},
    {"#...................", "%.ddd.ddd.ddd.ddd.W"},
    {"W...................", "%....L.....L......#"},
    {"#...................", "%.ddd.ddd.ddd.ddd.W"},
    {"W...................", "%.................#"},
    {"#...................", "%kkkkkk.....kkkkk.W"},
    {"W...................", "%%%%%%%%D%%%%%%%%%#"},
    {"#...................", "%ffff::::::;::::nn#"},
    {"#pppppppp...pppppppp", "%:::::::::::::::::W"},
    {"#...................", "%:oooo:kkkkk:oooo:#"},
    {"#cc.............cccc", "%:::::::;:::::::::W"},
    {"#cc.................", "%kkkkk:::::ccc:ccc#"},
    {"#WWW#WWW#DDD#WWW#WWW", "#WW#WW#WW#WW#WW#D##"},
}

local function storey(center, stairs)
    local rows = {}
    for z, c in ipairs(center) do
        if not stairs then c = c:gsub("%d", "0") end
        rows[z] = CLASS[z] .. c .. CLASS[z]:reverse()
    end
    for z, r in ipairs(BACK) do
        if stairs then
            rows[#center + z] = r[1] .. r[2]
        elseif z == 1 then
            rows[#center + z] = "####################" .. "#WW#WW#WW#WW#WW#WW#"
        elseif z == #BACK then
            rows[#center + z] = "#WWW#WWW#WWW#WWW#WWW#" .. string.rep(" ", 18)
        else
            local side = z % 2 == 0 and "W" or "#"
            local hall = (z == 5 or z == 11) and "0000Q00000Q00000Q00" or string.rep("0", 19)
            rows[#center + z] = side .. hall .. side .. string.rep(" ", 18)
        end
    end
    return rows
end

return kit.building {
    kind = "school",
    title = "школа",
    color = {200, 160, 100},
    zones = {"suburb"},
    weight = 2,
    cells = 2,
    materials = {
        wall = {"base:brick", "zomboid:bld_plaster"},
        inner = "zomboid:bld_plaster",
        floor = {"zomboid:bld_linoleum", "base:planks"},
        floor2 = "zomboid:tiles",
        stair = "zomboid:bld_concrete",
        slab = "zomboid:bld_step",
    },
    floors = {storey(LOBBY, true), storey(LIBRARY, false)},
    loot = {
        shelf = {
            rolls = {1, 3},
            {"zomboid:novel", 5, 1, 2}, {"zomboid:magazine", 3, 1, 2}, {"zomboid:book_carpentry_1", 1, 1, 1},
            {"zomboid:book_cooking_1", 1, 1, 1}, {"zomboid:book_first_aid_1", 1, 1, 1},
            {"zomboid:book_melee_1", 1, 1, 1}, {"zomboid:book_sneaking_1", 1, 1, 1}, {"zomboid:map", 1, 1, 1},
        },
        locker = {
            {"zomboid:school_bag", 4, 1, 1}, {"zomboid:tshirt", 3, 1, 1}, {"zomboid:sweater", 2, 1, 1},
            {"zomboid:jeans", 2, 1, 1}, {"zomboid:chips", 3, 1, 1}, {"zomboid:soda", 3, 1, 1},
            {"zomboid:chocolate", 2, 1, 1}, {"zomboid:bat", 1, 1, 1}, {"zomboid:magazine", 2, 1, 1},
            {"zomboid:cigarettes", 1, 1, 1},
        },
        crate = {
            {"zomboid:bat", 4, 1, 1}, {"zomboid:water_bottle", 3, 1, 2}, {"zomboid:boots", 2, 1, 1},
            {"zomboid:tshirt", 2, 1, 1}, {"zomboid:rag", 2, 1, 3}, {"zomboid:bandage", 1, 1, 1},
        },
        wardrobe = {
            {"zomboid:school_bag", 3, 1, 1}, {"zomboid:rag", 3, 1, 2}, {"zomboid:matches", 2, 1, 1},
            {"zomboid:flashlight", 2, 1, 1}, {"zomboid:map", 2, 1, 1}, {"zomboid:novel", 2, 1, 1},
            {"zomboid:radio", 1, 1, 1},
        },
        kitchen_cabinet = {
            rolls = {2, 4},
            {"zomboid:canned_beans", 6, 1, 3}, {"zomboid:chips", 3, 1, 2}, {"zomboid:cooking_pot", 2, 1, 1},
            {"zomboid:frying_pan", 2, 1, 1}, {"zomboid:knife", 2, 1, 1}, {"zomboid:empty_bottle", 2, 1, 2},
        },
        fridge = {
            rolls = {2, 5},
            {"zomboid:apple", 4, 1, 4}, {"zomboid:bread", 3, 1, 2}, {"zomboid:soda", 4, 1, 3},
            {"zomboid:water_bottle", 3, 1, 2}, {"zomboid:raw_meat", 2, 1, 2}, {"zomboid:carrot", 2, 1, 3},
            {"zomboid:potato", 2, 1, 3},
        },
    },
    zombies = {count = {5, 9}, shirts = {"sport", "sport", "white", "gray", "blue", "red"}},
}
