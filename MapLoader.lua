
--[[

    Map loader implementation aimed to load large-scale maps & preventing the agents from experiencing
    lag spikes of any kind.


    Methods:

        MapLoader:Load(MapToLoad: Instance, Parent):Instance

            Replicates the contents of the "MapToLoad" and waits for "ResumeTime" seconds every "Interval"
            after which it returns the Loaded Instance.

    ------------------------------------------------------------------------------------------------------------

    A few rules:

        * Parent object WILL have its PrimaryPart synced.

        * Models with PrimaryPart set will all be cloned at once, meaning Models with
          PrimaryPart will JUST be cloned & NOT loaded; so as to avoid messing with CollectionService signals in
          the game:

            Imagine a scenario: a map with trees which inherit CollectionService Tag - "Foliage". Now imagine you
            have a signal for any new instance created under that same tag. It is typical that these models will
            also have a PrimaryPart set and the signal handler is likely to expect them to spawn at once with all of
            its children, meaning that if we yield the signal handler may not register the model, which is not ideal.

        * Preferably pass Models for the :Load(...) method

        * Properties of Models or Folders such as "LevelOfDetail" will NOT be synced

    ------------------------------------------------------------------------------------------------------------

    Example usage:

        local MapLoader = require(directory to the module)
        local Map = game.ServerStorage["Forest"]

        local NewMap = MapLoader:Load(Map, workspace)
        wait(200)
        NewMap:Destroy()

    ------------------------------------------------------------------------------------------------------------

--]]





--//Services
local RunService = game:GetService("RunService")

--//Constants
local Interval: number = 50
local ResumeTime: number = .1



--//Roblox's default wait is unreliable, hence we will be utilizing a custom wait
function CustomWait(Seconds: number): number
    Seconds = math.max(Seconds or 0.03, 0.029)
    local TimeRemaining = Seconds

    while TimeRemaining > 0 do
        TimeRemaining -= RunService.Heartbeat:Wait()
    end

    return Seconds - TimeRemaining
end


--//Clone function that will also wait if the interval is complimented
function Clone(ObjectToClone: Instance, ObjectInterval: number): Instance
    if ObjectInterval%Interval == 0 then
        CustomWait(ResumeTime)
    end

    return ObjectToClone:Clone()
end


--//Get object size based on our rules
function GetObjectSize(Object: Instance, Size: number?): number
    Size = Size or 0

    for Index = 1, #Object:GetChildren() do
        local ChildObject = Object:GetChildren()[Index]
        if #ChildObject:GetChildren() > 0 and not ChildObject:IsA("BasePart") then
            if ChildObject:IsA("Model") and ChildObject.PrimaryPart then
                Size += 1
            elseif (ChildObject:IsA("Model") and not ChildObject.PrimaryPart) or (not ChildObject:IsA("Model")) then
                Size = GetObjectSize(ChildObject, Size)
            end
        else
            Size += 1
        end
    end

    return Size
end


--//Get index of the Object under its Parent
function GetIndexOf(Object: Instance, Parent: Instance): number?
    if Object == nil or Parent == nil then warn("Missing arguments!" ..debug.traceback()) return end
    if not Object:IsDescendantOf(Parent) then warn(Object.Name .." not a Descendant of" ..Parent.Name ..debug.traceback()) return end

    for Index = 1, #Parent:GetDescendants() do
        local Descendant = Parent:GetDescendants()[Index]
        if Descendant == Object then
            return Index
        end
    end
end


--//Get the PrimaryPart of the Object and replicate to Object2; WE ARE ASSUMING THAT OBJECT:OBJECT2 == 1
function SyncPrimaryPartWith(Object: Instance, Object2: Instance): boolean?
    if Object == nil or Object2 == nil then warn("Missing arguments!" ..debug.traceback()) return end
    if #Object:GetDescendants() ~= #Object2:GetDescendants() then warn(Object.Name .. " does not have the same amount of descendants as ".. Object2.Name) return end

    local Index = GetIndexOf(Object.PrimaryPart, Object)
    Object2.PrimaryPart = Object2:GetDescendants()[Index]

    return true
end


--//Recursively loading the objects
function Load(CloneObject: Instance, Parent: any?, SearchDepth: number?, IsRecursive: boolean?):Instance
    assert(CloneObject ~= nil, "Incorrect argument passed!")

    local SearchAmount  = SearchDepth or 0
    local Holder

        Holder = Instance.new(CloneObject.ClassName)
        Holder.Name = CloneObject.Name

        if Parent ~= nil then
            Holder.Parent = Parent
        end

        for Index = 1, #CloneObject:GetChildren() do
            local Object = CloneObject:GetChildren()[Index]
            if #Object:GetChildren() > 0 and not Object:IsA("BasePart") then
                if Object:IsA("Model") and Object.PrimaryPart then
                    SearchAmount += 1
                    Clone(Object, SearchAmount).Parent = Holder
                elseif (Object:IsA("Model") and not Object.PrimaryPart) or (not Object:IsA("Model")) then
                    SearchAmount = Load(Object, Holder, SearchAmount, true)
                end
            else
                SearchAmount += 1
                Clone(Object, SearchAmount).Parent = Holder
            end
        end

    if IsRecursive then
        return SearchAmount
    else
        assert(GetObjectSize(CloneObject) == SearchAmount, "GetObjectSize() does not follow the same set of rules as Load(). Look back into the ".. script.Name .." module!")
        warn("Finished loading!")
        return Holder
    end
end



local MapLoader = {}


    function MapLoader:Load(MapToLoad: Instance, Parent): Instance

        assert(MapToLoad ~= nil and typeof(MapToLoad) == "Instance", "Passed argument is either nil or of incorrect type!")

        --//ClassName checking; look at Rule #2
        if MapToLoad:IsA("Model") then
            if not MapToLoad.PrimaryPart then
                return Load(MapToLoad, Parent)
            else
                --//Sync PrimaryParts; we are doing this only to the main holder for flexibility purposes; look at Rule #1
                local LoadedMap = Load(MapToLoad, Parent)
                if not SyncPrimaryPartWith(MapToLoad, LoadedMap) then
                    warn("Unable to sync the PrimaryParts!" ..debug.traceback())
                end
                return LoadedMap
            end
        else
            return Load(MapToLoad, Parent)
        end

    end


return MapLoader
