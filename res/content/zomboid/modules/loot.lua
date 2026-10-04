local town = require "zomboid:town"

local loot = {}

local TABLES = {
    fridge = {
        {"zomboid:bread", 4, 1, 2}, {"zomboid:apple", 4, 1, 3}, {"zomboid:water_bottle", 3, 1, 1},
        {"zomboid:soda", 4, 1, 2}, {"zomboid:chocolate", 2, 1, 1}, {"zomboid:canned_beans", 1, 1, 1},
    },
    kitchen_cabinet = {
        {"zomboid:canned_beans", 5, 1, 2}, {"zomboid:chips", 3, 1, 2}, {"zomboid:empty_bottle", 3, 1, 2},
        {"zomboid:knife", 2, 1, 1}, {"zomboid:frying_pan", 2, 1, 1}, {"zomboid:matches", 2, 1, 1},
        {"zomboid:rag", 2, 1, 2}, {"zomboid:chocolate", 1, 1, 1}, {"zomboid:book_cooking_1", 1, 1, 1},
        {"zomboid:alarm_clock.item", 1, 1, 1},
    },
    stove = {
        {"zomboid:frying_pan", 3, 1, 1}, {"zomboid:canned_beans", 1, 1, 1}, {"zomboid:book_cooking_2", 1, 1, 1},
    },
    wardrobe = {
        {"zomboid:rag", 6, 1, 3}, {"zomboid:bat", 1, 1, 1}, {"zomboid:flashlight", 2, 1, 1},
        {"zomboid:bandage", 1, 1, 1}, {"zomboid:painkillers", 1, 1, 1}, {"zomboid:matches", 1, 1, 1},
        {"zomboid:book_melee_1", 1, 1, 1}, {"zomboid:book_sneaking_1", 1, 1, 1},
        {"zomboid:alarm_clock.item", 1, 1, 1},
    },
    medicine_cabinet = {
        {"zomboid:bandage", 5, 1, 3}, {"zomboid:disinfectant", 3, 1, 1}, {"zomboid:painkillers", 3, 1, 1},
        {"zomboid:antibiotics", 1, 1, 1}, {"zomboid:rag", 2, 1, 2}, {"zomboid:book_first_aid_1", 1, 1, 1},
    },
    crate = {
        {"zomboid:plank", 4, 2, 6}, {"zomboid:nails", 4, 5, 20}, {"zomboid:hammer", 2, 1, 1},
        {"zomboid:empty_bottle", 2, 1, 2}, {"zomboid:flashlight", 1, 1, 1}, {"zomboid:bat", 1, 1, 1},
        {"zomboid:crowbar", 1, 1, 1}, {"zomboid:book_carpentry_1", 1, 1, 1},
    },
    shelf = {
        {"zomboid:canned_beans", 5, 1, 3}, {"zomboid:chips", 4, 1, 3}, {"zomboid:chocolate", 3, 1, 2},
        {"zomboid:soda", 4, 1, 3}, {"zomboid:water_bottle", 4, 1, 2}, {"zomboid:bread", 2, 1, 2},
    },
}

local BUILDING = {
    hardware = {
        crate = {
            {"zomboid:plank", 5, 4, 12}, {"zomboid:nails", 5, 10, 40}, {"zomboid:hammer", 4, 1, 1},
            {"zomboid:axe", 2, 1, 1}, {"zomboid:crowbar", 2, 1, 1}, {"zomboid:flashlight", 2, 1, 1},
            {"zomboid:matches", 2, 1, 1}, {"zomboid:book_carpentry_1", 2, 1, 1}, {"zomboid:book_carpentry_2", 1, 1, 1},
            {"zomboid:shotgun_shells", 1, 2, 6}, {"zomboid:alarm_clock.item", 1, 1, 1},
        },
    },
    police = {
        crate = {
            {"zomboid:bat", 3, 1, 1}, {"zomboid:crowbar", 3, 1, 1}, {"zomboid:axe", 1, 1, 1},
            {"zomboid:knife", 3, 1, 1}, {"zomboid:flashlight", 4, 1, 1}, {"zomboid:bandage", 3, 1, 2},
            {"zomboid:spiked_bat", 1, 1, 1}, {"zomboid:book_melee_2", 1, 1, 1}, {"zomboid:book_sneaking_2", 1, 1, 1},
            {"zomboid:pistol", 1, 1, 1}, {"zomboid:shotgun", 0.5, 1, 1},
            {"zomboid:ammo_9mm", 2, 4, 12}, {"zomboid:shotgun_shells", 1.5, 2, 6}, {"zomboid:siren.item", 0.5, 1, 1},
        },
        wardrobe = {
            {"zomboid:flashlight", 3, 1, 1}, {"zomboid:bandage", 3, 1, 2}, {"zomboid:bat", 2, 1, 1},
            {"zomboid:ammo_9mm", 1, 3, 8},
        },
    },
    pharmacy = {
        medicine_cabinet = {
            {"zomboid:bandage", 5, 2, 5}, {"zomboid:disinfectant", 4, 1, 1}, {"zomboid:painkillers", 4, 1, 1},
            {"zomboid:antibiotics", 3, 1, 1}, {"zomboid:book_first_aid_1", 1, 1, 1}, {"zomboid:book_first_aid_2", 1, 1, 1},
        },
    },
}

local ROLLS = {
    fridge = {1, 4}, kitchen_cabinet = {1, 3}, stove = {0, 1}, wardrobe = {0, 3}, medicine_cabinet = {1, 3},
    crate = {1, 4}, shelf = {2, 5},
}

local function choose(entries)
    local total = 0
    for _, e in ipairs(entries) do total = total + e[2] end
    local r = math.random() * total
    for _, e in ipairs(entries) do
        r = r - e[2]
        if r <= 0 then
            return e
        end
    end
    return entries[#entries]
end

function loot.table_for(container, x, z)
    local kind = town.building_at(x, z)
    local special = kind and BUILDING[kind] and BUILDING[kind][container]
    return special or TABLES[container]
end

function loot.fill(invid, container, x, z, apocalypse_hour)
    local entries = loot.table_for(container, x, z)
    if entries == nil then
        return 0
    end
    local rolls = ROLLS[container] or {1, 3}
    local n = math.random(rolls[1], rolls[2])
    local added = 0
    for _ = 1, n do
        local e = choose(entries)
        local itemid = item.index(e[1])
        local count = math.random(e[3], e[4])
        local props = item.properties[itemid]
        if props and props["zomboid:spoil-days"] then
            for _ = 1, count do
                local slot = inventory.find_by_item(invid, 0, 0, inventory.size(invid) - 1, 0)
                if slot then
                    inventory.set(invid, slot, itemid, 1)
                    inventory.set_data(invid, slot, "born", apocalypse_hour - math.random() * 12)
                    added = added + 1
                end
            end
        else
            local rest = inventory.add(invid, itemid, count)
            added = added + count - rest
        end
    end
    return added
end

local ZOMBIE_DROPS = {
    {"zomboid:rag", 4, 1, 2}, {"zomboid:chips", 2, 1, 1}, {"zomboid:water_bottle", 1, 1, 1},
    {"zomboid:bandage", 1, 1, 1}, {"zomboid:matches", 1, 1, 1}, {"zomboid:chocolate", 1, 1, 1},
}

function loot.zombie_drop()
    local e = choose(ZOMBIE_DROPS)
    return item.index(e[1]), math.random(e[3], e[4])
end

return loot
