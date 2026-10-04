return require("zomboid:buildings/_store")({
    kind = "grocery",
    title = "продукты",
    color = {210, 190, 70},
    zones = {"downtown", "suburb"},
    weight = {downtown = 6, suburb = 3},
    container = "zomboid:shelf",
})
