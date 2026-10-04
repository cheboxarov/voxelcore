function on_interact(x, y, z)
    if block.is_segment(x, y, z) then
        x, y, z = block.seek_origin(x, y, z)
    end
    local open = block.get_user_bits(x, y, z, 0, 1) > 0
    block.set_user_bits(x, y, z, 0, 1, open and 0 or 1)
    block.set_rotation(x, y, z, (block.get_rotation(x, y, z) + (open and 3 or 1)) % 4)
    if vc.is_client() then
        audio.play_sound(open and "blocks/door_close" or "blocks/door_open", x + 0.5, y + 1, z + 0.5, 1, 1)
    end
    return true
end
