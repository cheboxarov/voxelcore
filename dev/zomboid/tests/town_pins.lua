-- Every new building kind stands in town by its pinned lot, whatever the weights
app.config_packs({"zomboid"})
app.new_world("zpins", "1", "zomboid:town")

local KINDS = {"apartments", "hospital", "school", "church", "supermarket", "warehouse", "bar", "diner", "motel",
    "fire_station", "military", "factory", "workshop"}
for _, kind in ipairs(KINDS) do
    require("zomboid:buildings/" .. kind).weight = 0
end
local town = require "zomboid:town"

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

local count = {}
for _, c in ipairs(town.cells()) do
    local p = town.plan(c.cx, c.cz)
    if p and p.cx == c.cx and p.cz == c.cz then
        count[p.kind] = (count[p.kind] or 0) + 1
    end
end
for _, kind in ipairs(KINDS) do
    print("[zomboid-test]", kind, count[kind] or 0)
    check(count[kind] == 1, kind .. " stands on its pinned lot only")
end

app.close_world(false)
app.delete_world("zpins")
