-- Wait for game to load
repeat wait() until game:IsLoaded()

local lobbyPlaceId = 116495829188952 -- Specify the lobby PlaceId
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- Only execute if the current PlaceId matches the lobbyPlaceId
if game.PlaceId == lobbyPlaceId then
    local CreateParty = ReplicatedStorage.Shared.Network.RemoteEvent.CreateParty

    -- Repeatedly find a "Waiting for players..." PartyZone, teleport to it, and create a party
    local function findAndCreatePartyLoop()
        while true do
            local HRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not HRP then
                player.CharacterAdded:Wait()
                HRP = player.Character:WaitForChild("HumanoidRootPart")
            end

            local FoundLobby = false

            for _, v in pairs(workspace.PartyZones:GetChildren()) do
                if v.Name:match("PartyZone") and v:FindFirstChild("BillboardGui")
                    and v.BillboardGui:FindFirstChild("StatusLabel")
                    and v.BillboardGui.StatusLabel.Text == "Waiting for players..." then

                    print("Lobby Found!")
                    HRP.CFrame = v:FindFirstChild("Hitbox").CFrame
                    FoundLobby = true
                    task.wait(0.1)

                    local args = {
                        {
                            isPrivate = true,
                            maxMembers = 1,
                            trainId = "default",
                            gameMode = "Normal"
                        }
                    }
                    CreateParty:FireServer(unpack(args))
                    break
                end
            end

            -- Wait ~7 seconds before trying again
            task.wait(3)
        end
    end

    -- Function to check if the player has been teleported
    local function hasBeenTeleported()
        return game.PlaceId ~= lobbyPlaceId
    end

    -- Function to get a low-player server
    local function getLowPlayerServer(cursor)
        local apiUrl = "https://games.roblox.com/v1/games/" .. lobbyPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local url = apiUrl .. ((cursor and "&cursor=" .. cursor) or "")
        local success, response = pcall(function()
            return game:HttpGet(url)
        end)

        if success then
            local data = HttpService:JSONDecode(response)
            for _, server in pairs(data.data) do
                if server.playing < 3 and server.id ~= game.JobId then
                    return server.id
                end
            end
            return data.nextPageCursor
        end

        warn("Failed to fetch server list.")
        return nil
    end

    -- Delayed teleportation check for server hopping
    task.spawn(function()
        wait(25)
        if game.PlaceId == lobbyPlaceId then
            local serverId, cursor = nil, nil
            repeat
                cursor = getLowPlayerServer(cursor)
                if cursor and not serverId then
                    serverId = cursor
                end
            until serverId or not cursor

            if serverId then
                print("Teleporting to a low-player server...")
                TeleportService:TeleportToPlaceInstance(lobbyPlaceId, serverId, player)
            else
                warn("No suitable server found.")
            end
        else
            print("Not in the lobby, skipping server hop.")
        end
    end)

    -- Start the party-finding/creation loop in parallel
    task.spawn(findAndCreatePartyLoop)
else
    print("Not in the local lobby. Script will not run.")
end
