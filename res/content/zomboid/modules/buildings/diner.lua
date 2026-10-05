local kit = require "zomboid:buildings/_kit"

return kit.building {
    kind = "diner",
    title = "закусочная",
    color = {240, 140, 160},
    zones = {"downtown", "highway", "suburb"},
    weight = 3,
    cells = 1,
    materials = {
        wall = {"zomboid:siding_white", "zomboid:siding_yellow", "base:brick"},
        inner = "zomboid:siding_white",
        floor = {"zomboid:bld_linoleum", "zomboid:tiles"},
        floor2 = "zomboid:tiles",
    },
    floors = {{
        "#WWWWWW#WDW#WWWWWW#",
        "#ud.ud.ud..ud.ud.u#",
        "W.................W",
        "#...L.......L.....#",
        "W..d..d..d..d..d..W",
        "#.................#",
        "#kkkkkkkk.kkkkkkk.#",
        "#........L........#",
        "#%%%%%%D%%%%%%%%%%#",
        "#ooo::k:kk::n%ffff#",
        "#::::::;:::::D....#",
        "#:dd::::::kk:%cccc#",
        "#::::;:::::::%.L..#",
        "#ffkk::nn::::%cc.c#",
        "#WW#WWD#WW#WW#WWD##",
    }},
    loot = {
        fridge = {
            rolls = {2, 5},
            {"zomboid:raw_meat", 6, 1, 3}, {"zomboid:potato", 4, 1, 4}, {"zomboid:carrot", 4, 1, 4},
            {"zomboid:bread", 3, 1, 2}, {"zomboid:soda", 3, 1, 3}, {"zomboid:apple", 2, 1, 3},
            {"zomboid:water_bottle", 2, 1, 2},
        },
        kitchen_cabinet = {
            rolls = {1, 4},
            {"zomboid:canned_beans", 4, 1, 3}, {"zomboid:knife", 3, 1, 1}, {"zomboid:frying_pan", 3, 1, 1},
            {"zomboid:cooking_pot", 3, 1, 1}, {"zomboid:matches", 2, 1, 1}, {"zomboid:book_cooking_1", 1, 1, 1},
            {"zomboid:book_cooking_2", 1, 1, 1}, {"zomboid:rag", 2, 1, 2}, {"zomboid:chips", 2, 1, 2},
        },
        stove = {
            {"zomboid:frying_pan", 3, 1, 1}, {"zomboid:cooking_pot", 3, 1, 1}, {"zomboid:cooked_meat", 1, 1, 1},
            {"zomboid:soup", 1, 1, 1},
        },
        crate = {
            rolls = {2, 5},
            {"zomboid:potato", 5, 2, 6}, {"zomboid:carrot", 5, 2, 6}, {"zomboid:canned_beans", 4, 2, 5},
            {"zomboid:bread", 2, 1, 3}, {"zomboid:water_bottle", 2, 2, 4},
        },
    },
    zombies = {count = {2, 5}, shirts = {"white", "white", "red", "blue", "gray"}},
}
