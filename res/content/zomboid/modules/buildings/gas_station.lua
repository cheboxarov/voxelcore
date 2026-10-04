local gas_station = require("zomboid:buildings/_store")({
    kind = "gas_station",
    title = "заправка",
    color = {200, 60, 50},
    zones = {"highway"},
    weight = 1,
    w = 11, d = 7,
    container = "zomboid:shelf",
    loot = {
        shelf = {
            {"zomboid:chips", 4, 1, 3}, {"zomboid:soda", 4, 1, 3}, {"zomboid:chocolate", 3, 1, 2},
            {"zomboid:water_bottle", 2, 1, 2}, {"zomboid:map", 3, 1, 1}, {"zomboid:gas_can_empty", 3, 1, 1},
            {"zomboid:gas_can", 2, 1, 1}, {"zomboid:matches", 2, 1, 1},
        },
    },
})

function gas_station.plan_extra(p)
    p.oz = 15
    p.car = {p.mid, -8}
end

function gas_station.lot(p, hx, hz, out)
    if hz >= 0 or hx < -1 or hx > p.w then
        return nil
    end
    if out then
        table.insert(out, {0, "zomboid:asphalt", 0})
        if hz == -4 and (hx == 2 or hx == p.w - 3) then
            table.insert(out, {1, "zomboid:fuel_pump", 2})
        end
    end
    return "path"
end

return gas_station
