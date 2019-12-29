local recipe_prefix = "barreled-recipe-"

local function check_barreled_recipes()
	local found_barreled_recipes = {}
	local found_barreled_recipes_count = 0

	for _, force in pairs(game.forces) do
		for _, technology in pairs(force.technologies) do
			for _, effect in pairs(technology.effects) do

				if effect.type == "unlock-recipe" and string.sub(effect.recipe, 1, string.len(recipe_prefix)) == recipe_prefix then
					if not found_barreled_recipes[effect.recipe] then
						found_barreled_recipes[effect.recipe] = true
						found_barreled_recipes_count = found_barreled_recipes_count + 1
					end

					if technology.researched then
						force.recipes[effect.recipe].enabled = true
					end
				end

			end
		end
	end

	return found_barreled_recipes_count
end

local function on_init()
	global.barrel_recipes_init = 1

	local found_barreled_recipes = check_barreled_recipes()
	game.print({ "barrel-recipes.on_init", found_barreled_recipes })
end

local function on_configuration_changed()
	global.barrel_recipes_init = (global.barrel_recipes_init or 1) + 1

	if global.barrel_recipes_init > 2 then
		local found_barreled_recipes = check_barreled_recipes()
		game.print({ "barrel-recipes.on_configuration_changed", found_barreled_recipes })
	end
end

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
