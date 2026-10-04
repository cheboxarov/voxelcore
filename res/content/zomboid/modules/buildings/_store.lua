return function(def)
    def.cells = def.cells or 1

    function def.plan(p)
        p.w, p.d = def.w or 17, def.d or 13
        p.wall = def.wall or "base:brick"
        p.mid = math.floor(p.w / 2)
        p.split = math.floor(p.d / 2)
        p.door = p.mid
        if def.plan_extra then
            def.plan_extra(p)
        end
    end

    function def.column(p, hx, hz, out)
        local w, d = p.w, p.d
        local edge_x = hx == 0 or hx == w - 1
        local edge_z = hz == 0 or hz == d - 1
        table.insert(out, {0, "zomboid:tiles", 0})
        table.insert(out, {4, "zomboid:roof", 0})
        if edge_x or edge_z then
            table.insert(out, {5, p.wall, 0})
        end
        if edge_x and edge_z then
            for dy = 1, 3 do table.insert(out, {dy, p.wall, 0}) end
            return
        end
        if edge_x or edge_z then
            if hz == 0 and hx == p.door then
                table.insert(out, {1, "base:wooden_door", 0})
                table.insert(out, {3, p.wall, 0})
                return
            end
            if hz == d - 1 and hx == 2 then
                table.insert(out, {1, "base:wooden_door", 0})
                table.insert(out, {3, p.wall, 0})
                return
            end
            local glass = (hz == 0 and math.abs(hx - p.door) > 1 and hx > 1 and hx < w - 2)
                or (edge_x and hz % 4 == 2)
            local mat = glass and "zomboid:window" or p.wall
            table.insert(out, {1, mat, 0})
            table.insert(out, {2, mat, 0})
            table.insert(out, {3, p.wall, 0})
            return
        end
        local furniture, rot
        if (hz == 4 or hz == 7 or hz == 10) and hx >= 3 and hx <= w - 4 and hx ~= p.door then
            furniture, rot = def.container, (hz % 2 == 0) and 2 or 0
            if hz == 10 and def.back_row then
                furniture = def.back_row
            end
        elseif hz == 2 and hx >= 2 and hx <= 4 then
            furniture, rot = "zomboid:kitchen_cabinet", 0
        elseif hx == w - 2 and hz == d - 2 and def.fridge ~= false then
            furniture, rot = "zomboid:fridge", 3
        end
        if furniture then
            table.insert(out, {1, furniture, rot})
            if furniture == "zomboid:crate" or furniture == "zomboid:medicine_cabinet" or furniture == "zomboid:kitchen_cabinet" then
                table.insert(out, {2, "core:struct_air", 0})
            end
        else
            table.insert(out, {1, "core:struct_air", 0})
            table.insert(out, {2, "core:struct_air", 0})
        end
        table.insert(out, {3, (hx % 4 == 2 and hz % 4 == 2) and "zomboid:lamp" or "core:struct_air", 0})
    end

    return def
end
