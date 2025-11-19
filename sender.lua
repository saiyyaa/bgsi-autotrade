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

    -- Only attempt teleport once; avoid repeating and avoid teleporting if already in the target server.
    local hasAttemptedTeleport = false

    local function normalizeId(s)
        if not s then return "" end
        s = tostring(s)
        -- Remove whitespace and common surrounding characters to avoid formatting mismatches.
        s = s:gsub("%s+", "")
        s = s:gsub("^\"(.*)\"$", "%1")
        s = s:gsub("^'(.*)'$", "%1")
        return s
    end

    if #JOB_IDS > 0 then
        local jobId = JOB_IDS[1]
        task.spawn(function()
            task.wait(1)
            if jobId and jobId ~= "" and not hasAttemptedTeleport then
                local cur = normalizeId(game.JobId or "")
                local targ = normalizeId(jobId)
                print("[autotrade] current JobId:", cur, " target JobId:", targ)

                local same = false
                if cur ~= "" and targ ~= "" then
                    -- direct equality or substring match to handle slight formatting differences
                    if cur == targ or cur:find(targ, 1, true) or targ:find(cur, 1, true) then
                        same = true
                    end
                end

                if same then
                    print("[autotrade] teleport skipped — already in target job.")
                else
                    hasAttemptedTeleport = true
                    print("[autotrade] teleporting to jobId:", jobId)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId)
                end
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
