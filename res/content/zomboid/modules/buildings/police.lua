return require("zomboid:buildings/_store")({
    kind = "police",
    title = "полиция",
    color = {70, 100, 190},
    zones = {"downtown", "suburb"},
    weight = 5,
    wall = "base:stone",
    container = "zomboid:crate",
    back_row = "zomboid:wardrobe",
    fridge = false,
    loot = {
        crate = {
            {"zomboid:bat", 3, 1, 1}, {"zomboid:crowbar", 3, 1, 1}, {"zomboid:axe", 1, 1, 1},
            {"zomboid:knife", 3, 1, 1}, {"zomboid:flashlight", 4, 1, 1}, {"zomboid:bandage", 3, 1, 2},
            {"zomboid:spiked_bat", 1, 1, 1}, {"zomboid:book_melee_2", 1, 1, 1}, {"zomboid:book_sneaking_2", 1, 1, 1},
            {"zomboid:pistol", 1, 1, 1}, {"zomboid:shotgun", 0.5, 1, 1},
            {"zomboid:ammo_9mm", 2, 4, 12}, {"zomboid:shotgun_shells", 1.5, 2, 6}, {"zomboid:siren.item", 0.5, 1, 1},
            {"zomboid:hiking_bag", 1, 1, 1},
            {"zomboid:radio", 2, 1, 1}, {"zomboid:map", 2, 1, 1},
        },
        wardrobe = {
            {"zomboid:flashlight", 3, 1, 1}, {"zomboid:bandage", 3, 1, 2}, {"zomboid:bat", 2, 1, 1},
            {"zomboid:ammo_9mm", 1, 3, 8},
            {"zomboid:leather_jacket", 3, 1, 1}, {"zomboid:boots", 2, 1, 1},
        },
    },
})
