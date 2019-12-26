local item_types = {
    "item",
    "ammo",
    "capsule",
    "gun",
    "item-with-entity-data",
    "item-with-label",
    "item-with-inventory",
    "blueprint-book",
    "item-with-tags",
    "selection-tool",
    "blueprint",
    "copy-paste-tool",
    "deconstruction-item",
    "upgrade-item",
    "module",
    "rail-planner",
    "tool",
    "armor",
    "repair-tool",
}

function find_proto(types, name)
    if type(types) == "string" then
        return data.raw[types] ~= nil and data.raw[types][name] or nil
    else
        for _, type in pairs(types) do
            if data.raw[type] ~= nil and data.raw[type][name] ~= nil then
                return data.raw[type][name]
            end
        end
    end

    return nil
end

function find_item_proto(name)
    return find_proto(item_types, name)
end

function get_proto_icons(proto)
    if proto.icons ~= nil then
        return proto.icons

    elseif proto.icon ~= nil then
        return {{
            icon = proto.icon,
            icon_size = proto.icon_size
        }}
    end

    return nil
end
