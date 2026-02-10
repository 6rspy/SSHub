-- ANTI VOID OTTIMIZZATO
-- Controlla altezza SOLO quando in caduta per >1 secondo
-- Usa loop con task.wait per minimizzare lag (no Heartbeat costante)
-- Esegue il remote Teleport UNA SOLA VOLTA quando Y <= -30
-- Azzera velocità per 0.8 secondi

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local VOID_Y = -30
local FALL_DETECTION_TIME = 1.0     -- Tempo minimo di caduta prima di attivare controlli
local CHECK_INTERVAL = 0.2          -- Intervallo di check durante la caduta (200ms, basso impatto su FPS)
local VELOCITY_RESET_DURATION = 0.8
local VELOCITY_RESET_INTERVAL = 0.1

local function antiVoid(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if not humanoid or not hrp then return end

    local fallStartTime = nil
    local hasTriggeredVoid = false
    local isChecking = false

    -- Listener per stati del Humanoid (basso costo, event-based)
    local stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Freefall then
            fallStartTime = tick()
            -- Avvia monitoraggio caduta dopo 1s
            task.delay(FALL_DETECTION_TIME, function()
                if humanoid:GetState() == Enum.HumanoidStateType.Freefall and not isChecking then
                    isChecking = true
                    task.spawn(function()  -- Loop di check isolato durante la caduta
                        while humanoid:GetState() == Enum.HumanoidStateType.Freefall do
                            if not hrp or not hrp.Parent then break end

                            local y = hrp.Position.Y

                            if y <= VOID_Y then
                                if not hasTriggeredVoid then
                                    hasTriggeredVoid = true
                                    hrp.Anchored = true

                                    -- Azzera velocità per 0.8 secondi
                                    local steps = math.floor(VELOCITY_RESET_DURATION / VELOCITY_RESET_INTERVAL)
                                    for _ = 1, steps do
                                        if hrp and hrp.Parent then
                                            hrp.Velocity = Vector3.zero
                                            hrp.AssemblyLinearVelocity = Vector3.zero
                                        end
                                        task.wait(VELOCITY_RESET_INTERVAL)
                                    end

                                    -- Esegui il remote SOLO UNA VOLTA
                                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                                    if remotes then
                                        local teleportRemote = remotes:FindFirstChild("Teleport")
                                        if teleportRemote then
                                            teleportRemote:FireServer("floatingisland")
                                        end
                                    end

                                    -- Piccola attesa di sicurezza + sblocco
                                    task.wait(0.3)
                                    if hrp and hrp.Parent then
                                        hrp.Anchored = false
                                    end

                                    -- Resetta lo stato dopo essere tornati sopra
                                    task.spawn(function()
                                        while hrp and hrp.Parent and hrp.Position.Y <= VOID_Y + 5 do
                                            task.wait(0.4)
                                        end
                                        hasTriggeredVoid = false
                                    end)
                                end
                            else
                                if hasTriggeredVoid and y > VOID_Y + 10 then
                                    hasTriggeredVoid = false
                                end
                            end

                            task.wait(CHECK_INTERVAL)
                        end
                        isChecking = false
                    end)
                end
            end)
        elseif oldState == Enum.HumanoidStateType.Freefall then
            fallStartTime = nil
        end
    end)

    -- Pulizia alla rimozione del character
    character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            stateConnection:Disconnect()
        end
    end)
end

-- Avvio
if player.Character then
    antiVoid(player.Character)
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.8)  -- Tempo per spawn
    antiVoid(char)
end)
