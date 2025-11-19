-- top-level cfg holder
_G.BGSI_CFG = nil

task.spawn(function()
    repeat task.wait() until _G.BGSI_CFG
    local cfg = _G.BGSI_CFG

    task.wait(20)
    setfpscap(15)

    local TARGET_PLAYER = cfg.TARGET_PLAYER or ""
    local ADD_PETS = cfg.ADD_PETS ~= false
    local ACCEPT_DELAY = cfg.ACCEPT_DELAY or 15
    local CONFIRM_DELAY = cfg.CONFIRM_DELAY or 10
    privateJobIds = cfg.JOB_IDS or {}
    local POST_TRADE_DELAY = cfg.POST_TRADE_DELAY or 15
    local MAX_PETS = cfg.MAX_PETS or 10

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService = game:GetService("TeleportService")

    local Network = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
    local LocalPlayer = Players.LocalPlayer
    local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
    local PetsModule = require(ReplicatedStorage.Shared.Data.Pets)

    for _, jobId in ipairs(privateJobIds) do
        if jobId ~= "" and jobId ~= game.JobId then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
            end)
            break
        end
    end

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
end)

return function(cfg)
    _G.BGSI_CFG = cfg
end
