--!strict

local MapLoader = {}

local MAX_INCREMENT: number = 40
local RESUME_TIME: number = 0.1

-- Loads the map (Recursively) in incremental chunks
function MapLoader.LoadMap(map: Instance): Instance
	-- Ensure the provided map is either a Model or Folder
	assert(typeof(map) == "Instance" and (map:IsA("Model") or map:IsA("Folder")), "Expected a Model or a Folder")

	local parent = Instance.new(map.ClassName)
	parent.Name = map.Name

	for _, obj in pairs(map:GetChildren()) do
		-- Recursively load objects with many descendants in chunks
		if #obj:GetDescendants() > MAX_INCREMENT then
			task.wait(RESUME_TIME)
			MapLoader.LoadMap(obj).Parent = parent
		else
			-- Clone and parent the object directly
			local objClone = obj:Clone()
			objClone.Parent = parent
		end
	end

	return parent
end

return MapLoader
