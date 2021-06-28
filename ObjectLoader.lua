--  ObjectLoader
--  P.S This module has a few type errors and the doc is mostly pseudo-based.

--[[

    Object loader implementation aimed at loading large-scale maps, which prevents the agents from experiencing
    lag spikes of any kind, while compensating load times. Depending on the size of the Object, it may take
    anywhere from a few nanoseconds to minutes for the load to return the "cloned" Object.


    Methods:

        ObjectLoader:Load(ObjectToLoad: Instance):Instance

            Clones the contents of the "ObjectToLoad" and waits for "ResumeTime" seconds every "Interval"
            and returns the Loaded Instance

    ------------------------------------------------------------------------------------------------------------

    A few rules:

        * Initial holder WILL have its PrimaryPart synced

        * Models with PrimaryPart set will all be cloned at once, meaning Models with
          PrimaryPart will JUST be cloned & NOT loaded; so as to avoid messing with CollectionService signals in
          the game:

            Imagine a scenario: a map with trees that have a CS Tag of "Foliage". Now imagine you have
            a signal for any new instance created under "Foliage" tag. If we were to set PrimaryParts without
            ignoring there may be occassions when not all children are not yet available in the parent model,
            which may cause errors in our "Foliage" handler.

        * Preferably pass ONLY Models for "ObjectToLoad" argument in the method :Load(...)

        * Avoid adding children on anything else besides models/folders as properties are likely to be out of
          sync

        * Properties of Models such as: "LevelOfDetail" are disregarded, hence do not expect them to be synced

    ------------------------------------------------------------------------------------------------------------

    Example usage:

        local ObjectLoader = require(directory to the module)
        local Map = game.ServerStorage["Forest"]

        local NewMap = ObjectLoader:Load(Map)
        NewMap.Parent = workspace

    ------------------------------------------------------------------------------------------------------------
--]]





--//Services
local RunService          = game:GetService("RunService")

--//Constants
local Interval: number    = 50
local ResumeTime: number  = .1



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
        if #ChildObject:GetChildren() > 0 then
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


--//Get index of the Object in Parent
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


--//Load the object recursively
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
            if #Object:GetChildren() > 0 then
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



local ObjectLoader = {}


    function ObjectLoader:Load(ObjectToLoad: Instance): Instance

        assert(ObjectToLoad ~= nil and typeof(ObjectToLoad) == "Instance", "Passed argument is nil!")

        --//ClassName checking; look at Rule #2
        if ObjectToLoad:IsA("Model") then
            if not ObjectToLoad.PrimaryPart then
                return Load(ObjectToLoad)
            else
                --//Sync PrimaryParts; we are doing this only to the main holder to allow us move the model freely once loaded; look at Rule #1
                local LoadedObject = Load(ObjectToLoad)
                if not SyncPrimaryPartWith(ObjectToLoad, LoadedObject) then
                    warn("Unable to sync the PrimaryParts!" ..debug.traceback())
                end
                return LoadedObject
            end
        else
            warn(ObjectToLoad.Name .." is not a Model")
            return Load(ObjectToLoad)
        end

    end


return ObjectLoader