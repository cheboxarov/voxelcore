local kit = require "zomboid:buildings/_kit"

local TRIM = "zomboid:trim"
local EMPTY = string.rep(" ", 23)

local GROUND = {
    '""""#WDW#""""' .. '||||__||||',
    '""""#.L.#""""' .. '|"""__"""|',
    '""""W...W""""' .. '|g"g__g"g|',
    '#####...#####' .. '|"""__"""|',
    '#...#%D%#...#' .. '|g"g__g"g|',
    'W...........W' .. '|"""__"""|',
    '#pppp...pppp#' .. '|g"g__g"g|',
    'W...........W' .. '|"""__"""|',
    '#pppp.L.pppp#' .. '|g"g__g"g|',
    'W...........W' .. '|"""__"""|',
    '#pppp...pppp#' .. '|g"g__g"g|',
    'W.....L.....W' .. '|"""__"""|',
    '#pppp...pppp#' .. '|g"g__g"g|',
    'W...........W' .. '|"""__"""|',
    '#.....L.....#' .. '|g"g__g"g|',
    'W...ddddd...W' .. '|"""__"""|',
    '#...........D' .. '""""__g"g|',
    '#%%%%D%%%%%%#' .. '|"""_####|',
    '#ccc.L..kkon#' .. '|g"g_D..#|',
    'W..........wW' .. '|"""_#cc#|',
    '#cc.......uu#' .. '|g"g_####|',
    '#WW#WDW#WW#W#' .. '||||||||||',
}

local NAVE = {
    "    #WWW#    ",
    "    #000#    ",
    "    W000W    ",
    "#####000#####",
    "#000#####000#",
}

local function nave()
    local rows = {}
    for z = 1, #GROUND do
        local r
        if NAVE[z] then
            r = NAVE[z]
        elseif z <= 16 then
            local side = z % 2 == 0 and "W" or "#"
            r = side .. (z % 4 == 0 and "00000Q00000" or "00000000000") .. side
        elseif z == 17 then
            r = "#############"
        else
            r = string.rep(" ", 13)
        end
        rows[z] = r .. string.rep(" ", 10)
    end
    return rows
end

local function tower(top)
    local t = top and {"    #W#W#    ", "    W000W    ", "    WYTYW    ", "    W000W    ", "    #####    "}
        or {"    #WWW#    ", "    #000#    ", "    W000W    ", "    #000#    ", "    #####    "}
    local rows = {}
    for z = 1, #GROUND do
        rows[z] = t[z] and t[z] .. string.rep(" ", 10) or EMPTY
    end
    return rows
end

return kit.building {
    kind = "church",
    title = "церковь",
    color = {150, 125, 175},
    zones = {"suburb", "village", "outskirts"},
    weight = 2,
    cells = 1,
    materials = {
        wall = {"base:stone", "base:brick", "zomboid:bld_plaster"},
        inner = "zomboid:bld_plaster",
        floor = "base:planks",
        floor2 = "zomboid:carpet",
        window = "zomboid:bld_stained_glass",
    },
    legend = {
        p = {"zomboid:bld_pew", rot = 0},
        T = {void = true, top = {TRIM, TRIM, TRIM, TRIM, TRIM}},
        Y = {void = true, top = {false, false, false, TRIM}},
    },
    floors = {GROUND, nave(), tower(false), tower(true)},
    loot = {
        crate = {
            rolls = {2, 4},
            {"zomboid:canned_beans", 6, 1, 3}, {"zomboid:water_bottle", 4, 1, 2}, {"zomboid:chips", 2, 1, 2},
            {"zomboid:bread", 2, 1, 1}, {"zomboid:rag", 3, 1, 3}, {"zomboid:matches", 2, 1, 1},
            {"zomboid:flashlight", 1, 1, 1}, {"zomboid:sweater", 1, 1, 1}, {"zomboid:knit_hat", 1, 1, 1},
        },
        wardrobe = {
            {"zomboid:rag", 4, 1, 3}, {"zomboid:novel", 3, 1, 1}, {"zomboid:matches", 3, 1, 2},
            {"zomboid:sweater", 2, 1, 1}, {"zomboid:raincoat", 1, 1, 1}, {"zomboid:map", 1, 1, 1},
            {"zomboid:bandage", 1, 1, 2},
        },
    },
    zombies = {count = {2, 5}, yard = {2, 4}, shirts = {"gray", "white", "blue", "gray"}},
}
