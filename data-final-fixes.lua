require("lib.util")
require("lib.proto")
require("lib.recipe")

local empty_barrel_name = "empty-barrel"
local max_recipe_factor = 10
local no_empty_barrels = settings.startup["no-empty-barrels"] ~= nil and settings.startup["no-empty-barrels"].value == true
local keep_fluid_water = settings.startup["keep-fluid-water"] ~= nil and settings.startup["keep-fluid-water"].value == true

local function is_barrel_recipe(recipe)
    return recipe.subgroup == "fill-barrel" or recipe.subgroup == "empty-barrel"
end

-- Get the fluid name, fluid amount produced by an "empty" barrel recipe, and the ingredient name used by the recipe.
local function get_barrel_recipe_fluid(recipe)

    -- not necessary to check recipe.result since we are looking for fluids.
    if not recipe.results then
        log_mod("Recipe " .. recipe .. " missing results")
        return nil
    end

    local found_fluid = false
    local found_empty_barrel = false
    local fluid_name = nil
    local fluid_amount = nil
    local ingredient_name = nil

    for _, result in pairs(recipe.results) do
        local result_type = result.type or "item"
        local result_name = result.name or result[1]
        local result_amount = result.amount or result[2] or 1

        if result_type == "fluid" then
            if found_fluid then
                log_mod("Found unexpected additional result fluid " .. result_name .. " for recipe " .. recipe.name)
                return nil
            elseif not result_amount or result_amount <= 0 then
                log_mod("Invalid or missing result fluid " .. result_name .. " amount for recipe " .. recipe.name)
                return nil
            else
                found_fluid = true
                fluid_name = result_name
                fluid_amount = result_amount
            end
        elseif result_type == "item" then
            if found_empty_barrel or result_name ~= empty_barrel_name then
                log_mod("Found unexpected result item " .. result_name .. " for recipe " .. recipe.name)
                return nil
            elseif result_amount ~= 1 then
                log_mod("Invalid or missing result item " .. result_name .. " amount for recipe " .. recipe.name)
                return nil
            else
                found_empty_barrel = true
            end
        else
            log_mod("Unexpected result type " .. result_type .. " for recipe " .. recipe.name)
            return nil
        end
    end

    for key, ingredient in pairs(recipe.ingredients) do
        if key ~= 1 then
            log_mod("Unexpected additional ingredient for recipe " .. recipe.name)
            return nil
        elseif ingredient.type ~= nil and ingredient.type ~= "item" then
            log_mod("Unexpected ingredient type " .. ingredient.type .. " for recipe " .. recipe.name)
            return nil
        elseif not (ingredient[2] == nil or ingredient[2] == 1 or ingredient.amount == 1) then
            log_mod("Unexpected ingredient amount for recipe " .. recipe.name)
            return nil
        else
            ingredient_name = ingredient[1] or ingredient.name
        end
    end

    if not ingredient_name then
        log_mod("Missing ingredients for recipe " .. recipe.name)
        return nil
    end

    return fluid_name, fluid_amount, ingredient_name
end

local function is_valid_barrelable_recipe(recipe)
    if recipe.category == "oil-processing" then
        return false
    end

    -- Allow recipes to opt-out, similar to the "auto_barrel" property for fluids.
    if recipe.allow_barreled == false then
        return false
    end

    return true
end

local function is_valid_fluid_ingredient(ingredient)
    return ingredient.type == "fluid" and ingredient.temperature == nil and ingredient.minimum_temperature == nil and
        ingredient.maximum_temperature == nil and not (ingredient.name == "water" and keep_fluid_water)
end

local function get_recipe_factor(recipe, barreled_fluids)
    -- Do no process barrel recipes again
    if is_barrel_recipe(recipe) then
        return nil
    end

    local ingredients = get_recipe_ingredients(recipe)

    -- Skip if no ingredients
    if not ingredients then
        return nil
    end

    local recipe_factor = nil

    for _, ingredient in pairs(ingredients) do
        if is_valid_fluid_ingredient(ingredient) then
            local barreled_fluid = barreled_fluids[ingredient.name]

            if barreled_fluid ~= nil then
                -- Determine the LCM for the barrel and ingredient.
                local fluid_factor = lcm(ingredient.amount, barreled_fluid.amount) / ingredient.amount

                -- Determine the LCM for the fluid's factor and the existing recipe factor.
                -- For example, if a recipe takes 10 water (50 per barrel) and 25 oil (50 per barrel)
                -- then the factor for water is 5 and oil is 2, so the LCM for the recipe will be 10.
                recipe_factor = lcm(recipe_factor or 1, fluid_factor)

                if recipe_factor % 1 ~= 0 or recipe_factor > max_recipe_factor then
                    log_mod("Recipe " .. recipe.name .. " cannot be scaled up for barrels")
                    return nil
                end
            end
        end
    end

    return recipe_factor or nil
end

local function create_barrel_recipe(recipe, factor, barreled_fluids)
    local barrel_recipe = create_normalized_recipe(recipe)

    barrel_recipe.enabled = false
    barrel_recipe.name = "barreled-recipe-" .. barrel_recipe.name
    barrel_recipe.energy_required = (barrel_recipe.energy_required or 0.5) * factor
    barrel_recipe.hide_from_player_crafting = true
    barrel_recipe.always_show_products = true
    barrel_recipe.show_amount_in_title = false

    barrel_recipe.localised_name = {
        "recipe-name.barrelled",
        get_recipe_localised_name(recipe)
    }

    barrel_recipe.icons = get_recipe_icons(recipe)
    if not barrel_recipe.icons then
        log_mod("Skipping since could not determine icons for recipe " .. recipe.name)
        return nil
    end

    -- Deep copy the icons (in case they are from a different prototype)
    -- and add the barrel icon to it.
    barrel_recipe.icons = util.table.deepcopy(barrel_recipe.icons)
    table.insert(
        barrel_recipe.icons,
        {
            icon = "__base__/graphics/icons/fluid/barreling/empty-barrel.png",
            icon_size = 32,
            scale = 0.6,
            shift = { -6, -6 },
        }
    )

    barrel_recipe.subgroup = get_recipe_subgroup(recipe)
    if not barrel_recipe.subgroup then
        log_mod("Skipping since could not determine subgroup for recipe " .. recipe.name)
        return nil
    end

    barrel_recipe.order = get_recipe_order(recipe)
    if barrel_recipe.order ~= nil then
        barrel_recipe.order = barrel_recipe.order .. "-a[barreled-recipe]"
    else
        log_mod("No order found for recipe " .. recipe.name)
    end

    -- Track how many empty barrels will be in the results.
    local empty_barrel_results = 0

    for key, ingredient in pairs(barrel_recipe.ingredients) do

        if ingredient.amount ~= nil then
            ingredient.amount = ingredient.amount * factor
        else
            ingredient[2] = (ingredient[2] or 1) * factor
        end

        if is_valid_fluid_ingredient(ingredient) then
            local barreled_fluid = barreled_fluids[ingredient.name]

            if barreled_fluid ~= nil and ingredient.amount % barreled_fluid.amount == 0 then
                ingredient = {
                    type = "item",
                    name = barreled_fluid.item,
                    amount = (ingredient.amount or ingredient[2]) / barreled_fluid.amount
                }

                empty_barrel_results = empty_barrel_results + ingredient.amount
            end
        end

        barrel_recipe.ingredients[key] = ingredient
    end

    for _, result in pairs(barrel_recipe.results) do

        -- Skip recipe if it has a fluid output.
        if result.type == "fluid" then
            log_mod("Skipping since fluid " .. result.name .. " is a result for recipe " .. recipe.name)
            return nil
        end

        if result.type then
            result.amount = result.amount * factor
        else
            result[2] = (result[2] or 1) * factor
        end
    end

    if empty_barrel_results > 0 and not no_empty_barrels then
        table.insert(
            barrel_recipe.results,
            {
                type = "item",
                name = empty_barrel_name,
                amount = empty_barrel_results
            }
        )
    end

    return barrel_recipe
end

local function is_empty_barrel_recipe(recipe)
    return recipe.subgroup == "empty-barrel"
end

local function get_barreled_fluids(recipes)
    local barreled_fluids = {}
    local invalid_fluids = {}

    for name, recipe in pairs(recipes) do
        if is_empty_barrel_recipe(recipe) then
            local fluid_name, fluid_amount, ingredient_name = get_barrel_recipe_fluid(recipe)

            if not fluid_name then
                log_mod("Fluid not found for recipe " .. recipe.name)

            elseif not find_proto("fluid", fluid_name) then
                log_mod("Fluid " .. fluid_name .. " does not exist for recipe " .. recipe.name)

            elseif fluid_name and fluid_amount > 0 and not invalid_fluids[fluid_name] then
                if (barreled_fluids[fluid_name] ~= nil) then
                    if barreled_fluids[fluid_name].amount ~= fluid_amount then
                        barreled_fluids[fluid_name] = nil
                        invalid_fluids[fluid_name] = true
                    end
                else
                    barreled_fluids[fluid_name] = {
                        amount = fluid_amount,
                        item = ingredient_name
                    }

                    log_mod("Found empty barrel recipe " .. recipe.name .. " for fluid " .. fluid_name .. " x " .. fluid_amount)
                end
            end
        end
    end

    return barreled_fluids
end

local function process_barrel_recipes()
    local barreled_fluids = get_barreled_fluids(data.raw["recipe"])
    local barreled_recipes = {}
    local recipe_to_barreled = {}

    for name, recipe in pairs(data.raw["recipe"]) do
        if is_valid_barrelable_recipe(recipe) then
            local recipe_factor = get_recipe_factor(recipe, barreled_fluids)
            if recipe_factor ~= nil then
                local barrel_recipe = create_barrel_recipe(recipe, recipe_factor, barreled_fluids)
                if barrel_recipe ~= nil then
                    log_mod("Created barreled recipe for " .. recipe.name .. " (x" .. recipe_factor .. ")")
                    recipe_to_barreled[recipe.name] = barrel_recipe.name
                    table.insert(barreled_recipes, barrel_recipe)
                end
            end
        end
    end

    return barreled_recipes, recipe_to_barreled
end

local function add_recipes_to_technology(recipe_to_barreled)
    -- Add new recipes to technologies.
    for _, technology in pairs(data.raw["technology"]) do
        if technology.effects ~= nil then
            local new_effects = {}

            for _, effect in pairs(technology.effects) do
                if effect.type == "unlock-recipe" and recipe_to_barreled[effect.recipe] ~= nil then
                    table.insert(new_effects, { type = "unlock-recipe", recipe = recipe_to_barreled[effect.recipe] })
                    log_mod("Adding barreled recipe " .. recipe_to_barreled[effect.recipe] .. " to technology " .. technology.name)
                end
            end

            for _, effect in pairs(new_effects) do
                table.insert(technology.effects, effect)
            end
        end
    end
end

local function remove_empty_barrels_from_recipes()
    for _, recipe in pairs(data.raw["recipe"]) do
        if is_barrel_recipe(recipe) and recipe.results ~= nil then

            local has_ingredient = false
            local has_result = false

            -- Remove empty barrels from ingredients
            local new_ingredients = {}
            for _, ingredient in pairs(recipe.ingredients) do
                if (ingredient[1] or ingredient.name) ~= empty_barrel_name then
                    table.insert(new_ingredients, ingredient)
                    has_ingredient = true
                end
            end

            -- Remove empty barrels from results
            local new_results = {}
            for _, result in pairs(recipe.results) do
                if (result[1] or result.name) ~= empty_barrel_name then
                    table.insert(new_results, result)
                    has_result = true
                end
            end

            if not has_ingredient then
                log_mod("Skipping removing barrels from recipe " .. recipe.name .. " since it would have no ingredients")
            elseif not has_result then
                log_mod("Skipping removing barrels from recipe " .. recipe.name .. " since it would have no results")
            else
                recipe.always_show_products = true
                recipe.show_amount_in_title = false
                recipe.ingredients = new_ingredients
                recipe.results = new_results
            end

        end
    end
end

local function main()
    local barreled_recipes, recipe_to_barreled = process_barrel_recipes()

    if #barreled_recipes ~= 0 then
        data:extend(barreled_recipes)
        add_recipes_to_technology(recipe_to_barreled)
    end

    if no_empty_barrels == true then
        remove_empty_barrels_from_recipes()
    end
end

main()