-- Food spoilage stages are separate items: fresh, stale (own icon, same freshness data), rotten
app.config_packs({"zomboid"})
app.new_world("zstale", "5", "zomboid:town")

local spoilage = require "zomboid:spoilage"
local clock = require "zomboid:clock"
local inv = require "zomboid:inv"

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

local pid = player.create("survivor")
app.sleep(1)
local invid = player.get_inventory(pid)
inv.clear(invid)
local bread, stale = item.index("zomboid:bread"), item.index("zomboid:bread_stale")
local days = item.properties[bread]["zomboid:spoil-days"]

local own = {name = true, icon = true, description = true, ["model-name"] = true, ["zomboid:stale"] = true, ["zomboid:fresh"] = true}
for _, name in ipairs({"apple", "bread", "carrot", "potato", "raw_meat", "cooked_meat", "soup", "stew"}) do
    local fresh, old = item.index("zomboid:" .. name), item.index("zomboid:" .. name .. "_stale")
    check(item.properties[fresh]["zomboid:stale"] == "zomboid:" .. name .. "_stale", name .. " links its stale item")
    check(item.icon(old) == "items:" .. name .. "_stale" and item.icon(old) ~= item.icon(fresh), name .. " stale icon differs")
    for _, pair in ipairs({{fresh, old}, {old, fresh}}) do
        for key, value in pairs(item.properties[pair[1]]) do
            if type(value) ~= "table" and not own[key] then
                check(item.properties[pair[2]][key] == value, name .. " stale keeps " .. key .. ", rerun dev/zomboid/assets/items.py")
            end
        end
    end
    check(item.stack_size(old) == item.stack_size(fresh) and item.has_tag(old, "zomboid:food"), name .. " stale stacks and is food")
end

inventory.set(invid, 0, bread, 3)
inventory.set_data(invid, 0, "born", clock.hours - 24 * days * 0.7)
spoilage.check(invid, false)
check(inventory.get(invid, 0) == bread, "soon-to-spoil bread is still the fresh item")

inventory.set_data(invid, 0, "born", clock.hours - 24 * days * 1.2)
local age = spoilage.age(invid, 0)
spoilage.check(invid, false)
local id, count = inventory.get(invid, 0)
check(id == stale and count == 3, "bread turned stale")
check(math.abs(spoilage.age(invid, 0) - age) < 0.01, "stale bread keeps its age")
check(spoilage.ratio(invid, 0) > 1, "eating stale bread still carries the stale penalty")
log(string.format("stale bread: age %.1fh, ratio %.2f", spoilage.age(invid, 0), spoilage.ratio(invid, 0)))

check(inv.count(invid, "zomboid:bread") == 3, "stale bread counts as bread")
check(inv.take(invid, "zomboid:bread", 1) and inv.count(invid, "zomboid:bread") == 2, "stale bread is taken as bread")
check(inv.count(invid, "zomboid:bread_stale") == 2, "stale counts as itself")

inventory.set_data(invid, 0, "born", clock.hours - 24 * days * 1.6)
spoilage.check(invid, false)
check(inventory.get(invid, 0) == item.index("zomboid:rotten_food"), "stale bread rots")
