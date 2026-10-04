local kit = require "zomboid:buildings/_kit"

return kit.building {
    kind = "bar",
    title = "бар",
    color = {140, 60, 90},
    zones = {"downtown", "highway", "village"},
    weight = 3,
    cells = 1,
    materials = {
        wall = {"base:brick", "zomboid:siding_red", "zomboid:bld_plaster"},
        inner = "zomboid:siding_white",
        floor = "base:planks",
        floor2 = "zomboid:tiles",
    },
    floors = {{
        "#WWW#WW#D#WW#WWW#",
        "#ud.du.....d.d..#",
        "W...............W",
        "#ud.du..L..d.d..#",
        "W...............W",
        "#..........dd...#",
        "#kkkkkkkk.......#",
        "#........L.....t#",
        "#ff.kkk.........#",
        "#%%%D%%%%%%D%%%%#",
        "#cc...cc%::;::nm#",
        "#c.....c%::::::.#",
        "#W#D#WW#WW#WW#WW#",
    }},
    loot = {
        kitchen_cabinet = {
            {"zomboid:cigarettes", 5, 1, 2}, {"zomboid:matches", 4, 1, 2}, {"zomboid:chips", 3, 1, 2},
            {"zomboid:soda", 3, 1, 2}, {"zomboid:empty_bottle", 3, 1, 3}, {"zomboid:bat", 1, 1, 1},
            {"zomboid:knife", 1, 1, 1}, {"zomboid:shotgun_shells", 0.4, 2, 4}, {"zomboid:magazine", 1, 1, 1},
        },
        fridge = {
            rolls = {2, 4},
            {"zomboid:soda", 6, 1, 3}, {"zomboid:water_bottle", 3, 1, 2}, {"zomboid:chocolate", 1, 1, 1},
        },
        crate = {
            rolls = {2, 4},
            {"zomboid:soda", 5, 2, 4}, {"zomboid:chips", 4, 2, 4}, {"zomboid:empty_bottle", 4, 2, 5},
            {"zomboid:cigarettes", 2, 1, 3}, {"zomboid:rag", 2, 1, 3},
        },
    },
    zombies = {count = {2, 5}},
}
