repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lobbyPlaceId = 116495829188952
local TRAIN_ID = "all"
local TARGET_ZONE_NAME = nil
local MAX_MEMBERS = 1
local IS_PRIVATE = true
local GAME_MODE = "Normal"

local TRAIN_IDS = {
    "yeat",
    "frost",
    "armored",
    "golden",
    "christmas_event_2025",
    "passenger",
    "oddthings_promo",
    "default",
    "wooden",
    "dracula",
    "presidential",
    "locomotive",
    "ghost",
    "cattle",
    "developer"
}

local player = Players.LocalPlayer

assert(player, "LocalPlayer is nil. Run this from a LocalScript.")

if game.PlaceId ~= lobbyPlaceId then
    warn("Wrong place. Current PlaceId:", game.PlaceId)
    return
end

local function getRequiredChild(parent, name)
    local child = parent:WaitForChild(name, 15)

    if not child then
        error(("Missing %q inside %s"):format(name, parent:GetFullName()))
    end

    return child
end

local Shared = getRequiredChild(ReplicatedStorage, "Shared")
local Universe = getRequiredChild(Shared, "Universe")
local Network = getRequiredChild(Universe, "Network")
local RemoteEventFolder = getRequiredChild(Network, "RemoteEvent")

local CreateParty = getRequiredChild(RemoteEventFolder, "CreateParty")
local PartyZoneReserved = getRequiredChild(RemoteEventFolder, "PartyZoneReserved")

assert(CreateParty:IsA("RemoteEvent"), "CreateParty is not a RemoteEvent")
assert(PartyZoneReserved:IsA("RemoteEvent"), "PartyZoneReserved is not a RemoteEvent")

if TRAIN_ID ~= "all" and not table.find(TRAIN_IDS, TRAIN_ID) then
    error("Invalid TRAIN_ID: " .. tostring(TRAIN_ID))
end

local function getTrainId()
    if TRAIN_ID ~= "all" then
        return TRAIN_ID
    end

    local random = Random.new()
    return TRAIN_IDS[random:NextInteger(1, #TRAIN_IDS)]
end

local function getHumanoidRootPart()
    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart", 15)
end

local function isWaitingZone(zone)
    local statusLabel = zone:FindFirstChild("StatusLabel", true)

    if not statusLabel or not statusLabel:IsA("TextLabel") then
        return false
    end

    return statusLabel.Text:find("Waiting for players", 1, true) ~= nil
end

local function createPartyAtZone(zone)
    local hitbox = zone:FindFirstChild("Hitbox", true)

    if not hitbox or not hitbox:IsA("BasePart") then
        warn("No valid Hitbox found in:", zone:GetFullName())
        return false
    end

    local rootPart = getHumanoidRootPart()

    if not rootPart then
        warn("HumanoidRootPart was not found")
        return false
    end

    local reserved = false
    local created = false

    local reservationConnection = PartyZoneReserved.OnClientEvent:Connect(function()
        reserved = true
    end)

    local createConnection = CreateParty.OnClientEvent:Connect(function()
        created = true
    end)

    rootPart.CFrame = hitbox.CFrame + Vector3.new(0, 3, 0)

    local reservationTimeout = os.clock() + 5

    while not reserved and os.clock() < reservationTimeout do
        task.wait(0.1)
    end

    reservationConnection:Disconnect()

    if not reserved then
        createConnection:Disconnect()
        warn("Party zone was not reserved")
        return false
    end

    task.wait(0.15)

    local partySettings = {
        isPrivate = IS_PRIVATE,
        trainId = getTrainId(),
        maxMembers = MAX_MEMBERS,
        gameMode = GAME_MODE
    }

    local success, errorMessage = pcall(function()
        CreateParty:FireServer(partySettings)
    end)

    if not success then
        createConnection:Disconnect()
        warn("CreateParty failed:", errorMessage)
        return false
    end

    local createTimeout = os.clock() + 5

    while not created and os.clock() < createTimeout do
        task.wait(0.1)
    end

    createConnection:Disconnect()

    if not created then
        warn("No party confirmation was received")
        return false
    end

    return true
end

local PartyZones = workspace:WaitForChild("PartyZones", 15)

assert(PartyZones, "workspace.PartyZones was not found")

local candidates = {}

for _, zone in ipairs(PartyZones:GetChildren()) do
    if isWaitingZone(zone) then
        if not TARGET_ZONE_NAME or zone.Name == TARGET_ZONE_NAME then
            table.insert(candidates, zone)
        end
    end
end

if #candidates == 0 then
    warn("No matching waiting party zone was found")
    return
end

if #candidates > 1 and not TARGET_ZONE_NAME then
    warn("Multiple waiting party zones were found. Set TARGET_ZONE_NAME before continuing.")
    return
end

local selectedZone = candidates[1]

if not createPartyAtZone(selectedZone) then
    warn("The selected party zone was not reserved")
end
