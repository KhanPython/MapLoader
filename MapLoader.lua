local MapLoader = {}

local MAX_INCREMENT: number = 40
local RESUME_TIME: number = 0.1

-- Loads the map (Recursively) in incremental chunks
function MapLoader.LoadMap(model: Instance): Instance
	assert(model ~= nil and typeof(model) == "Instance", "Map undefined or of incorrect type")

	local parent = Instance.new(model.ClassName)
	parent.Name = model.Name

	for _, obj in pairs(model:GetChildren()) do
		if #obj:GetDescendants() > MAX_INCREMENT then
			task.wait(RESUME_TIME)
			MapLoader.LoadMap(obj).Parent = parent
		else
			print("loading object")
			local objClone = obj:Clone()
			objClone.Parent = parent
		end
	end

	return parent
end

return MapLoader
