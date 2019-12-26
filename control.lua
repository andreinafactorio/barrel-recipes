local recipe_prefix = "barreled-recipe-"

function makeSureRecipesEnabled()
	for _, force in pairs(game.forces) do
		for _, technology in pairs(force.technologies) do
			if technology.researched then
				for _, effect in pairs(technology.effects) do
					if effect.type == "unlock-recipe" and string.sub(effect.recipe, 1, string.len(recipe_prefix)) == recipe_prefix then
						force.recipes[effect.recipe].enabled = true
					end
				end
			end
		end
    end
end

script.on_init(makeSureRecipesEnabled)
script.on_configuration_changed(makeSureRecipesEnabled)
