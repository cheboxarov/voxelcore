local kit = require "zomboid:buildings/_kit"

local CORE = {
    "#%%D%%..%%%D%%#",
    "#m..m%18%d...d#",
    "#m..m%27%.....#",
    "#m.Lm%36%..L..#",
    "#m..m%45%d...d#",
    "#m..m%44%.....#",
    "#c..c%%%%t..uu#",
    "#WW#WW###WW#WW#",
}

local WARD = {
    "#WW#WW#WW#WW",
    "#b.b%b.b%b.b",
    "W...%...%...",
    "#.L.%.L.%.L.",
    "Wb.b%b.b%b.b",
    "#...%...%...",
    "Wm.n%m.n%m.n",
    "#...%...%...",
    "Wb.b%b.b%b.b",
    "#...%...%...",
    "W.w.%.w.%.w.",
    "#...%...%...",
    "#%D%%%D%%%D%",
    "W...........",
    "#....L......",
    "#%%%%D%%%%%%",
    "#mmm.....mmm",
    "W...........",
    "#...d.L.d...",
    "W...d...d...",
    "#...........",
    "#kkn.....ccc",
    "#WW#WW#WW#WW",
}

local DAYROOM = {
    "#WWWW#WWW#WWWW#",
    "#uu.........uu#",
    "#.............#",
    "#...L.....L...#",
    "#t...........t#",
    "#.............#",
    "#...kkk.kkk...#",
    "#....m...m....#",
    "#...L.....L...#",
    "#b.b.b...b.b.b#",
    "#.............#",
    "#b.b.b...b.b.b#",
    "#.............#",
    "...............",
    "...L.......L...",
}

local GROUND = {
    {"#WW#WW#WW#WW", "#WWWW#DDD#WWWW#", "WW#WW#WW#WW#"},
    {"#b.b.m.b.b.m", "#uu.........uu#", "mmmmm.mmmmm#"},
    {"W...........", "#.............#", "...........W"},
    {"#....L....L.", "D...L.....L...#", ".sss.L.sss.#"},
    {"W...........", "#uu.........uu#", ".mmm...mmm.W"},
    {"#b.b.m.b.b.m", "#.............#", "...........#"},
    {"Wb.b.m.b.b.m", "#...kkk.kkk...#", ".sss.L.sss.W"},
    {"#...........", "#.............#", ".mmm...mmm.#"},
    {"W....L....L.", "#...L.....L...#", "...........W"},
    {"#...........", "#.............#", "cc.......cc#"},
    {"Wmmm.....kkn", "#.............#", "cc...L...ccW"},
    {"#...........", "#.............#", "...........#"},
    {"#%%%%%D%%%%%", "#.............#", "%%%%%D%%%%%#"},
    {"D...........", "...............", "...........D"},
    {"#....L......", "...L.......L...", "......L....#"},
    {"#%%%%D%%%%%%", nil, "%%%%%D%%%%%#"},
    {"#b.b.b.b.b.b", nil, "lllll.lllll#"},
    {"W...........", nil, "...........W"},
    {"#b.b.b.b.b.b", nil, "u....L....fW"},
    {"W....L......", nil, "u..........#"},
    {"#b.b.b.b.b.b", nil, "...........W"},
    {"#ff.......ff", nil, "kkon.....tu#"},
    {"#WW#WW#WW#WW", nil, "WW#WW#WW#WW#"},
}

local function ground()
    local rows = {}
    for z, r in ipairs(GROUND) do
        rows[z] = r[1] .. (r[2] or CORE[z - 15]) .. r[3]
    end
    return rows
end

local function ward(stairs)
    local rows = {}
    for z, w in ipairs(WARD) do
        local c = DAYROOM[z] or CORE[z - 15]
        if not stairs then c = c:gsub("%d", "0") end
        rows[z] = w .. c .. w:reverse()
    end
    return rows
end

local MEDS = {
    {"zomboid:bandage", 6, 2, 5}, {"zomboid:disinfectant", 5, 1, 2}, {"zomboid:painkillers", 5, 1, 2},
    {"zomboid:antibiotics", 4, 1, 2}, {"zomboid:splint", 3, 1, 1}, {"zomboid:rag", 2, 2, 4},
    {"zomboid:book_first_aid_1", 1, 1, 1}, {"zomboid:book_first_aid_2", 1, 1, 1},
}

return kit.building {
    kind = "hospital",
    title = "больница",
    color = {235, 235, 240},
    zones = {"downtown"},
    weight = {downtown = 2},
    cells = 2,
    materials = {
        wall = {"zomboid:bld_plaster", "base:brick"},
        inner = "zomboid:bld_plaster",
        floor = "zomboid:bld_linoleum",
        floor2 = "zomboid:tiles",
        stair = "zomboid:bld_concrete",
        slab = "zomboid:bld_step",
    },
    floors = {ground(), ward(true), ward(false)},
    loot = {
        medicine_cabinet = MEDS,
        shelf = {rolls = {3, 6}, unpack(MEDS)},
        crate = {
            rolls = {2, 4},
            {"zomboid:bandage", 5, 3, 8}, {"zomboid:disinfectant", 3, 1, 3}, {"zomboid:splint", 2, 1, 2},
            {"zomboid:water_bottle", 2, 1, 3}, {"zomboid:rag", 2, 3, 6},
        },
        locker = {
            {"zomboid:flashlight", 3, 1, 1}, {"zomboid:bandage", 3, 1, 2}, {"zomboid:painkillers", 2, 1, 1},
            {"zomboid:sweater", 2, 1, 1}, {"zomboid:boots", 1, 1, 1}, {"zomboid:cigarettes", 2, 1, 1},
            {"zomboid:chocolate", 2, 1, 1}, {"zomboid:novel", 1, 1, 1}, {"zomboid:school_bag", 1, 1, 1},
        },
    },
    zombies = {count = {6, 10}, shirts = {"doctor", "doctor", "patient", "patient", "white"}},
}
