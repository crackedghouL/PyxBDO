SecurityState = { }
SecurityState.__index = SecurityState
SecurityState.Name = "Security"


setmetatable(SecurityState, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
} )

function SecurityState.new()
    local self = setmetatable( { }, SecurityState)

    self.Settings = { PlayerDetection = false, PlayerRange = 2000, PlayerTimeAlarmSeconds = 4, PlayerRemoveAfterSeconds = 5, TeleportDetection = false, TeleportDistance = 500 }
    self.PlayerDetectedFunction = nil
    self.TeleportDetectedFunction = nil
    self.PlayerList = { }
    self.LastPosition = nil
    self.PausePlayerDetection = false
    self.PausePlayerDetectionTimer = nil
    self.PauseTeleportDetectionTimer = nil
    return self
end

function SecurityState:NeedToRun()

    local selfPlayer = GetSelfPlayer()

    if not selfPlayer then
        return false
    end

    if self.PauseTeleportDetectionTimer ~= nil and self.PauseTeleportDetectionTimer:Expired() == false then
        self.LastPosition = selfPlayer.Position
    elseif self.Settings.TeleportDetection == true then
        local currentPosition = selfPlayer.Position
        if self.LastPosition ~= nil and self.LastPosition.Distance3DFromMe >= self.Settings.TeleportDistance then
            print("Security: Teleport Detected distance:" .. tostring(self.LastPosition.Distance3DFromMe))
            if self.TeleportDetectedFunction ~= nil then
                return self.TeleportDetectedFunction()
            end
        end
        self.LastPosition = currentPosition
    end

    if self.Settings.PlayerDetection == true and self.PausePlayerDetection == false and Helpers.IsSafeZone() == false
        and(self.PausePlayerDetectionTimer == nil or self.PausePlayerDetectionTimer:Expired() == true)
    then
        self:CleanPlayerList()
        local characters = GetActors();
        for k, v in pairs(characters) do

            if v.IsPlayer and v.Position.Distance3DFromMe <= self.Settings.PlayerRange and selfPlayer.Key ~= v.Key then
                self:UpdatePlayer(v)
                if self:CheckPlayer(v) == true and self.PlayerDetectedFunction ~= nil then

                    return self.PlayerDetectedFunction()
                end

            end
        end
    end

    return false
end

function SecurityState:UpdatePlayer(player)
    for k, v in pairs(self.PlayerList) do
        if player.Key == v.Key then
            v.LastSeen = os.clock()
            return
        end
    end

    print("Security: Added Player " .. tostring(player.Name))
    table.insert(self.PlayerList, { Name = player.Name, Key = player.Key, FirstSeen = os.clock(), LastSeen = os.clock() })
end

function SecurityState:CleanPlayerList()
    for k, v in pairs(self.PlayerList) do
        if os.clock() - v.LastSeen >= self.Settings.PlayerRemoveAfterSeconds then
            print("Security: Removed Player " .. tostring(v.Name))
            self.PlayerList[k] = nil
        end
    end
end

function SecurityState:CheckPlayer(player)
    for k, v in pairs(self.PlayerList) do
        if player.Key == v.Key then
            if os.clock() - v.FirstSeen >= self.Settings.PlayerTimeAlarmSeconds then
                print("Security: Alarm for Player " .. tostring(v.Name))
                return true
            end
        end
    end
    return false
end


function SecurityState:Run()

end

function SecurityState:Reset()
    self.PlayerList = { }
    self.PausePlayerDetectionTimer = nil
    self.PauseTeleportDetectionTimer = nil
    self.LastPosition = nil
end
