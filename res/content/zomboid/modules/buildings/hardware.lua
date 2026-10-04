return require("zomboid:buildings/_store")({
    kind = "hardware",
    title = "хозтовары",
    color = {200, 120, 50},
    zones = {"downtown", "suburb"},
    weight = 7,
    container = "zomboid:crate",
    loot = {
        crate = {
            {"zomboid:plank", 5, 4, 12}, {"zomboid:nails", 5, 10, 40}, {"zomboid:hammer", 4, 1, 1},
            {"zomboid:axe", 2, 1, 1}, {"zomboid:crowbar", 2, 1, 1}, {"zomboid:flashlight", 2, 1, 1},
            {"zomboid:matches", 2, 1, 1}, {"zomboid:book_carpentry_1", 2, 1, 1}, {"zomboid:book_carpentry_2", 1, 1, 1},
            {"zomboid:shotgun_shells", 1, 2, 6}, {"zomboid:alarm_clock.item", 1, 1, 1},
            {"zomboid:stick", 2, 2, 4}, {"zomboid:raincoat", 1, 1, 1}, {"zomboid:boots", 2, 1, 1},
            {"zomboid:shovel", 3, 1, 1}, {"zomboid:gas_can_empty", 3, 1, 1}, {"zomboid:gas_can", 1, 1, 1}, {"zomboid:generator.item", 1, 1, 1}, {"zomboid:seeds_carrot", 2, 1, 3}, {"zomboid:seeds_potato", 2, 1, 3},
        },
    },
})
