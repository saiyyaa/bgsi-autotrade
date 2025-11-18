local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local network = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local player = Players.LocalPlayer

local processingTrade = false
local lastUpdate = 0
local rotationStarted = false

----------------------------------------------------------
-- GUI: JobID Copy
----------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JobIDCopyGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Button = Instance.new("TextButton")
Button.Size = UDim2.new(0, 180, 0, 40)
Button.Position = UDim2.new(1, -200, 0, 20)
Button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.Text = "Copy Job ID"
Button.Font = Enum.Font.SourceSansBold
Button.TextSize = 20
Button.Parent = ScreenGui

Button.MouseButton1Click:Connect(function()
    local jobId = game.JobId or TeleportService:GetServerInstanceId()
    if setclipboard then setclipboard(jobId) end
    Button.Text = "Copied!"
    task.wait(1)
    Button.Text = "Copy Job ID"
end)

----------------------------------------------------------
-- ROTATION FALLBACK (only if sender stalls)
----------------------------------------------------------
local function startFallbackRotation()
    if rotationStarted then return end
    rotationStarted = true
    
    task.spawn(function()
        while processingTrade do
            network:FireServer("TradeAccept")
            task.wait(2)
            network:FireServer("TradeConfirm")
            task.wait(2)
        end
        rotationStarted = false
    end)
end

----------------------------------------------------------
-- MAIN TRADE LISTENER
----------------------------------------------------------
network.OnClientEvent:Connect(function(action, fromPlayer)
    ------------------------------------------------------
    -- 1. Sender sends REQUEST → receiver accepts instantly
    ------------------------------------------------------
    if action == "TradeRequest" then
        processingTrade = true
        rotationStarted = false
        lastUpdate = os.clock()

        print("Incoming trade request → AcceptRequest")
        network:FireServer("TradeAcceptRequest", fromPlayer)

        -- If sender dies/stalls for 25s → rotate
        task.delay(25, function()
            if processingTrade and not rotationStarted then
                print("Fallback: Sender stalled → rotating")
                startFallbackRotation()
            end
        end)

        return
    end

    ------------------------------------------------------
    -- 2. TradeUpdated = sender added pets / accepted
    -- Receiver should accept a few seconds AFTER sender
    ------------------------------------------------------
    if action == "TradeUpdated" and processingTrade then
        lastUpdate = os.clock()
        
        task.spawn(function()
            task.wait(3) -- synced delay, receiver accepts 3s after sender
            if processingTrade then
                print("Synced Accept (after sender)")
                network:FireServer("TradeAccept")
            end
        end)

        return
    end

    ------------------------------------------------------
    -- 3. When sender confirms → receiver confirms 2s after
    ------------------------------------------------------
    if action == "TradeAccepted" and processingTrade then
        -- sender hit "Accept", receiver should confirm slightly later
        task.spawn(function()
            task.wait(2)
            if processingTrade then
                print("Synced Confirm (after sender)")
                network:FireServer("TradeConfirm")
            end
        end)
        return
    end

    ------------------------------------------------------
    -- 4. If trade ends → reset
    ------------------------------------------------------
    if action == "TradeEnded" then
        processingTrade = false
        rotationStarted = false
        lastUpdate = 0
        print("Trade completed or cancelled → reset")
        return
    end
end)
