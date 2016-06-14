
TurninState = { }
TurninState.__index = TurninState
TurninState.Name = "Turnin"
-- TurninState.DefaultSettings = { NpcName = "", NpcPosition = { X = 0, Y = 0, Z = 0 }, DepositItems = true, DepositMoney = true, MoneyToKeep = 10000, IgnoreItemsNamed = { }, SecondsBetweenTries = 3000}

setmetatable(TurninState, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
} )

function TurninState.new()
    local self = setmetatable( { }, TurninState)

    self.Settings = { Enabled = true, PlayerRun = true, NpcName = "", NpcPosition = { X = 0, Y = 0, Z = 0 }, TurninItemsNamed = { }, TurninCount = 1000, SecondsBetweenTries = 5, VendorAfterTurnin = true, TurninOnWeight = true }

    self.State = 0
    -- 0 = Nothing, 1 = Moving, 2 = Arrived

    self.LastUseTimer = nil
    self.SleepTimer = nil
    self.Forced = false
    self.TurnedIn = false

    -- Overideable functions
    self.ItemCheckFunction = nil
    self.CallWhenCompleted = nil
    self.CallWhileMoving = nil

    return self
end

function TurninState:NeedToRun()

    local selfPlayer = GetSelfPlayer()

    if not selfPlayer then
        return false
    end

    if not selfPlayer.IsAlive then
        return false
    end

    if not self:HasNpc() then
        self.Forced = false
        return false
    end


    if not self.Settings.Enabled then
        self.Forced = false
        return false
    end

    if selfPlayer.WeightPercent >= 100 then
        self.Forced = false
        return false
    end

    if self.Forced and not Navigator.CanMoveTo(self:GetPosition()) then
        self.Forced = false
        return false
    elseif self.Forced == true then
        return true
    end


    if self.LastUseTimer ~= nil and not self.LastUseTimer:Expired() then
        return false
    end

    if table.length(self:ItemCheck()) > 0 and
        Navigator.CanMoveTo(self:GetPosition()) then
        self.Forced = true
        return true
    end

    if self.Settings.TurninOnWeight and
        selfPlayer.WeightPercent >= 95 and
        table.length(self:GetItems()) > 0 and
        Navigator.CanMoveTo(self:GetPosition()) then
        self.Forced = true
        return true
    end

    return false
end

function TurninState:Reset()
    self.State = 0
    self.LastUseTimer = nil
    self.SleepTimer = nil
    self.Forced = false
    self.TurnedIn = false
end


function TurninState:Exit()

    if self.State > 1 then
        if Dialog.IsTalking then
            Dialog.ClickExit()
        end
        self.State = 0
        self.LastUseTimer = PyxTimer:New(self.Settings.SecondsBetweenTries)
        self.LastUseTimer:Start()
        self.SleepTimer = nil
        self.Forced = false
        self.TurnedIn = false

    end

end

function TurninState:Run()
    local selfPlayer = GetSelfPlayer()
    local vendorPosition = self:GetPosition()


    if vendorPosition.Distance3DFromMe > 200 then
        if self.CallWhileMoving then
            self.CallWhileMoving(self)
        end

        if vendorPosition.Distance3DFromMe < 1000 then
            local npcs = GetNpcs()
            if table.length(npcs) < 1 then
                print("Warehouse could not find any NPC's")
                self:Exit()
                return
            end
            table.sort(npcs, function(a, b) return a.Position:GetDistance3D(vendorPosition) < b.Position:GetDistance3D(vendorPosition) end)
            local npc = npcs[1]
            if vendorPosition.Distance3DFromMe - npc.BodySize - selfPlayer.BodySize < 50 then
                goto close_enough
            end
        end

        Navigator.MoveTo(vendorPosition,nil,self.Settings.PlayerRun)
        if self.State > 1 then
            self:Exit()
            return
        end
        self.State = 1
        return
    end

    ::close_enough::
    Navigator.Stop()
    if string.find(selfPlayer.CurrentActionName, "WAIT", 1) == nil then
        return
    end

    if self.SleepTimer ~= nil and self.SleepTimer:IsRunning() and not self.SleepTimer:Expired() then
        return
    end


    local npcs = GetNpcs()

    if table.length(npcs) < 1 then
        print("Turnin could not find any NPC's")
        self:Exit()
        return
    end
    table.sort(npcs, function(a, b) return a.Position:GetDistance3D(vendorPosition) < b.Position:GetDistance3D(vendorPosition) end)

    local npc = npcs[1]

    if self.State == 1 then
        npc:InteractNpc()
        self.SleepTimer = PyxTimer:New(3)
        self.SleepTimer:Start()
        self.State = 2
        return
    end




    if self.State == 2 then
		if self.TurnedIn == false then 
			for i = 0, 2 do
			    if self.SleepTimer ~= nil and self.SleepTimer:IsRunning() and not self.SleepTimer:Expired() then
				return
				end
				for k, v in pairs(self:GetItems()) do
					for index = 0, 3 do
					    if self.SleepTimer ~= nil and self.SleepTimer:IsRunning() and not self.SleepTimer:Expired() then
						return
						end

						local ButtonText = BDOLua.Execute(string.format("return ToClient_GetCurrentDialogData():getDialogButtonAt(%s):getText()",index))
						local ItemId = BDOLua.Execute(string.format("return ToClient_GetCurrentDialogData():getDialogButtonAt(%s):getNeedItemKey()",index))
						if string.match(ButtonText,"Continue") then
							BDOLua.Execute("HandleClickedBackButton()")      
							self.SleepTimer = PyxTimer:New(1)
							self.SleepTimer:Start()
							return
						end
						if string.match(ItemId, v.key) then
							-- print(string.format("MATCHING ITEMS %s and %s, index %s in iteration %s",ItemId, v.key,index,i))
							local needItemCount = tonumber(BDOLua.Execute(string.format("return ToClient_GetCurrentDialogData():getDialogButtonAt(%i):getNeedItemCount()",index)))
							local exChangeCount = math.floor(v.count/needItemCount)
							if exChangeCount > 0 then 
							-- print(string.format("Exchange Count is %s because %s / %s", exChangeCount,v.count,needItemCount))
								BDOLua.Execute(string.format("ToClient_GetCurrentDialogData():setExchangeCount(%s)",exChangeCount))
								self.SleepTimer = PyxTimer:New(0.5)
								self.SleepTimer:Start()
								print(string.format("Turning in %s of %s", exChangeCount*needItemCount, v.name))
								BDOLua.Execute(string.format("Dialog_clickDialogButtonReq(%i)",index))
								self.SleepTimer = PyxTimer:New(0.5)
								self.SleepTimer:Start()
								BDOLua.Execute("HandleClickedBackButton()")
								index = 0
							end		
						end
					end	
				end
				self.TurnedIn = true
				-- print("done")
				self.SleepTimer = PyxTimer:New(0.2)
				self.SleepTimer:Start()
				self.TurnedIn = true
				self:Exit()
				return
			end
		end
            self.State = 10
            if self.CallWhenCompleted then
                self.CallWhenCompleted(self)
            end
                self.SleepTimer = PyxTimer:New(1)
                self.SleepTimer:Start()
            return
        end

	self:Exit()
        return
    

    

end


function TurninState:ItemCheck()
    local items = { }
    local selfPlayer = GetSelfPlayer()
    if selfPlayer then
        for k, v in pairs(selfPlayer.Inventory.Items) do
            if self.ItemCheckFunction ~= nil then
                if self.ItemCheckFunction(v) == true then
                    table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count, key = v.ItemEnchantStaticStatus.ItemId })
                end
            else
                if table.find(self.Settings.TurninItemsNamed, v.ItemEnchantStaticStatus.Name) and v.Count >= self.Settings.TurninCount then
                    table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count, key = v.ItemEnchantStaticStatus.ItemId })
                end

            end
        end
    end
    return items
end


function TurninState:GetItems()
    local items = { }
    local selfPlayer = GetSelfPlayer()
    if selfPlayer then
        for k, v in pairs(selfPlayer.Inventory.Items) do
            if self.ItemCheckFunction ~= nil then
                if self.ItemCheckFunction(v) == true then
                    table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count, key = v.ItemEnchantStaticStatus.ItemId })
                end
            else
                if table.find(self.Settings.TurninItemsNamed, v.ItemEnchantStaticStatus.Name) and v.Count >= 100 then
                    table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count, key = v.ItemEnchantStaticStatus.ItemId })
                end

            end
        end
    end
    return items
end


function TurninState:HasNpc()
    return string.len(self.Settings.NpcName) > 0
end

function TurninState:GetPosition()
    return Vector3(self.Settings.NpcPosition.X, self.Settings.NpcPosition.Y, self.Settings.NpcPosition.Z)
end
