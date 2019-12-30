require("lib.proto")

function get_recipe_ingredients(recipe)
    if type(recipe.normal) == "table" then
        recipe = recipe.normal
    end

    return recipe.ingredients or nil
end

function recipe_has_multiple_results(recipe)
    if type(recipe.normal) == "table" then
        recipe = recipe.normal
    end

    if recipe.results ~= nil then
        local found = false
        for _ in ipairs(recipe.results) do
            if found then
                return true
            end
            found = true
        end
    end

    return false
end

function get_recipe_main_result(recipe)
    if type(recipe.normal) == "table" then
        recipe = recipe.normal
    end

    local result_type = nil
    local result_name = nil

    if recipe.result ~= nil then
        result_name = recipe.result
    elseif recipe.results ~= nil then
        if recipe.results[1].type ~= nil then
            result_type = recipe.results[1].type
            result_name = recipe.results[1].name
        else
            result_name = recipe.results[1][1]
        end
    end

    return result_type, result_name
end

function get_recipe_results(recipe)
    if type(recipe.normal) == "table" then
        recipe = recipe.normal
    end

    if recipe.results ~= nil then
        return recipe.results
    elseif recipe.result ~= nil then
        return {
            {
                recipe.result,
                recipe.result_count or 1
            }
        }
    else
        return nil
    end
end

function create_normalized_recipe(recipe)
    recipe = util.table.deepcopy(recipe)

    if type(recipe.normal) == "table" then
        for key, value in pairs(recipe.normal) do
            recipe[key] = value
        end
    end

    recipe.normal = nil
    recipe.expensive = nil

    recipe.results = get_recipe_results(recipe)
    recipe.result = nil
    recipe.result_count = nil

    recipe.ingredients = get_recipe_ingredients(recipe)

    return recipe
end

function get_recipe_localised_name(recipe)
    if recipe.localised_name then
        return recipe.localised_name
    end

    -- Not supporting main_product for single result since I'm not clear on how to use it.
    if not recipe_has_multiple_results(recipe) then
        local result_type, result_name = get_recipe_main_result(recipe)

        -- Abort if a result was not found.
        if not result_name then
            return nil
        end

        local result_proto = nil
        if result_type == nil then
            result_type = "item"
            result_proto = find_item_proto(result_name)
        else
            result_proto = find_proto(result_type, result_name)
        end

        if result_proto ~= nil then
            if result_type == nil then
                result_type = result_proto.type
            end

            -- Use the result's localisation, if available.
            if result_proto.localised_name ~= nil then
                return result_proto.localised_name

            elseif result_proto.place_result ~= nil then
                result_type = "entity"
                result_name = result_proto.place_result

                -- Use the entity's localisation, if available.
                local entity_proto = find_proto("entity", result_proto.place_result)
                if entity_proto ~= nil and entity_proto.localised_name ~= nil then
                    return entity_proto.localised_name
                end
            end
        end

        -- If the type is still nil then default it to "item"
        if result_type == nil then
            result_type = "item"
        end

        return { result_type .. "-name." .. result_name }
    end

    return { "recipe-name." .. recipe.name }
end

function get_recipe_order(recipe)
    if recipe.order then
        return recipe.order
    end

    -- Not supporting main_product for single result since I'm not clear on how to use it.
    if not recipe_has_multiple_results(recipe) then
        local result_type, result_name = get_recipe_main_result(recipe)

        -- Abort if a result was not found.
        if not result_name then
            return nil
        end

        local result_proto = nil
        if result_type == nil then
            result_proto = find_item_proto(result_name)
        else
            result_proto = find_proto(result_type, result_name)
        end

        if result_proto ~= nil and result_proto.order ~= nil then
            return result_proto.order
        end
    end

    return nil
end

function get_recipe_icons(recipe)
    local recipe_icons = get_proto_icons(recipe)
    if (recipe_icons ~= nil) then
        return recipe_icons
    end

    -- Not supporting main_product for single result since I'm not clear on how to use it.
    if not recipe_has_multiple_results(recipe) then
        local result_type, result_name = get_recipe_main_result(recipe)

        -- Abort if a result was not found.
        if not result_name then
            return nil
        end

        local result_proto = nil
        if result_type == nil then
            result_proto = find_item_proto(result_name)
        else
            result_proto = find_proto(result_type, result_name)
        end

        if result_proto ~= nil then
            -- Use the recipe result's icons, if available.
            local result_icons = get_proto_icons(result_proto)
            if (result_icons ~= nil) then
                return result_icons
            end

           if result_proto.place_result ~= nil then
                -- Use the entity's icons, if available.
                local entity_proto = find_proto("entity", result_proto.place_result)
                if entity_proto ~= nil then
                    local entity_icons = get_proto_icons(entity_proto)
                    if (entity_icons ~= nil) then
                        return entity_icons
                    end
                end
            end
        end

        if (result_proto ~= nil) then
            return get_proto_icons(result_proto)
        end
    end

    return nil
end

function get_recipe_subgroup(recipe)
    if recipe.subgroup ~= nil then
        return recipe.subgroup
    end

    if not recipe_has_multiple_results(recipe) then
        local result_type, result_name = get_recipe_main_result(recipe)

        -- Abort if a result was not found.
        if not result_name then
            return nil
        end

        local result_proto = nil
        if result_type == nil then
            result_proto = find_item_proto(result_name)
        else
            result_proto = find_proto(result_type, result_name)
        end

        if result_proto ~= nil then
            return result_proto.subgroup or nil
        end
    end

    return nil
end
