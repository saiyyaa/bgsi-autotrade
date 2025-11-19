return function(CONFIG)

    repeat task.wait() until CONFIG ~= nil

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = Players.LocalPlayer
    local Network = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

    local TARGET_PLAYER = CONFIG.TARGET_PLAYER
    local ADD_PETS = CONFIG.ADD_PETS
    local ACCEPT_DELAY = CONFIG.ACCEPT_DELAY or 15
    local CONFIRM_DELAY = CONFIG.CONFIRM_DELAY or 10
    local POST_TRADE_DELAY = CONFIG.POST_TRADE_DELAY or 15
    local MAX_PETS = CONFIG.MAX_PETS or 10
    local JOB_IDS = CONFIG.JOB_IDS or {}

    if #JOB_IDS > 0 then
        local jobId = JOB_IDS[1]
        task.spawn(function()
            task.wait(1)
            -- Only teleport if the configured jobId is non-empty and different from the current server's job id.
            -- This prevents rejoining the same server when you're already in the correct job.
            if jobId and jobId ~= "" and tostring(game.JobId) ~= tostring(jobId) then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId)
            end
        end)
    end

    task.wait(2)

    Network:FireServer("TradeRequest", TARGET_PLAYER)

    Network.OnClientEvent:Connect(function(action, fromPlayer)
        if action == "TradeAcceptRequest" and fromPlayer == TARGET_PLAYER then
            task.wait(ACCEPT_DELAY)
            Network:FireServer("TradeAccept")

            task.wait(CONFIRM_DELAY)
            Network:FireServer("TradeConfirm")

            task.wait(POST_TRADE_DELAY)
            LocalPlayer:Kick("Trade complete.")
        end
    end)
end
