return require("zomboid:buildings/_store")({
    kind = "pharmacy",
    title = "аптека",
    color = {90, 180, 90},
    zones = {"downtown", "suburb"},
    weight = {downtown = 3, suburb = 1},
    container = "zomboid:medicine_cabinet",
    loot = {
        medicine_cabinet = {
            {"zomboid:bandage", 5, 2, 5}, {"zomboid:disinfectant", 4, 1, 1}, {"zomboid:painkillers", 4, 1, 1},
            {"zomboid:antibiotics", 3, 1, 1}, {"zomboid:book_first_aid_1", 1, 1, 1}, {"zomboid:book_first_aid_2", 1, 1, 1},
            {"zomboid:splint", 2, 1, 1},
        },
    },
})
