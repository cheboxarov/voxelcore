-- Big buildings: expected loot of the key items per building stays within caps
app.config_packs({"zomboid"})
app.new_world("zloot", "1", "zomboid:town")

local town = require "zomboid:town"
local loot = require "zomboid:loot"

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

local CAPS = {
    hospital = {["zomboid:antibiotics"] = 20, ["zomboid:bandage"] = 120},
    military = {["zomboid:pistol"] = 1.2, ["zomboid:shotgun"] = 0.8, ["zomboid:ammo_9mm"] = 60, ["zomboid:shotgun_shells"] = 30},
    police = {["zomboid:pistol"] = 1.2, ["zomboid:shotgun"] = 0.6, ["zomboid:ammo_9mm"] = 60},
    fire_station = {["zomboid:axe"] = 3},
    warehouse = {["zomboid:generator.item"] = 1.5, ["zomboid:plank"] = 180, ["zomboid:nails"] = 600},
    factory = {["zomboid:generator.item"] = 1.5, ["zomboid:plank"] = 180, ["zomboid:nails"] = 600},
    supermarket = {["zomboid:canned_beans"] = 90},
}

local function expected(def)
    local p = {kind = def.kind, def = def, rot = 0, lot_w = 80, lot_d = 60}
    def.plan(p, function(n) return town.hash(1, 2, n) end)
    local total = {}
    for hz = 0, p.d - 1 do
        for hx = 0, p.w - 1 do
            local out = {}
            def.column(p, hx, hz, out)
            for _, e in ipairs(out) do
                local id = block.index(e[2])
                local cont = id and block.properties[id]["zomboid:loot"]
                local entries = cont and ((def.loot or {})[cont] or loot.table_for(cont, 100000, 100000))
                if entries then
                    local r = loot.rolls(cont, entries)
                    local sum = 0
                    for _, it in ipairs(entries) do sum = sum + it[2] end
                    for _, it in ipairs(entries) do
                        total[it[1]] = (total[it[1]] or 0) + (r[1] + r[2]) / 2 * it[2] / sum * (it[3] + it[4]) / 2
                    end
                end
            end
        end
    end
    return total
end

local over = {}
for kind, caps in pairs(CAPS) do
    local total = expected(town.building_def(kind))
    for name, cap in pairs(caps) do
        print("[zomboid-test]", kind, name, string.format("%.1f", total[name] or 0), "cap", cap)
        if (total[name] or 0) > cap then table.insert(over, kind .. " " .. name) end
    end
end
check(#over == 0, "loot over the cap: " .. table.concat(over, ", "))

app.close_world(false)
app.delete_world("zloot")
