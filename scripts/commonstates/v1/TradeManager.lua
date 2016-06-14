TradeManagerState = { }
TradeManagerState.__index = TradeManagerState
TradeManagerState.Name = "TradeManager"

setmetatable(TradeManagerState, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
} )

function TradeManagerState.new()
    local self = setmetatable( { }, TradeManagerState)
    self.Settings = {DoTradeGame = false, NpcName = "", NpcPosition = { X = 0, Y = 0, Z = 0 }, SellAll = true, TradeManagerOnInventoryFull = true, IgnoreItemsNamed = { }, SecondsBetweenTries = 300, PlayerRun = true }

    self.State = 0
    -- 0 = Nothing, 1 = Moving, 2 = Arrived
    self.Forced = false

    self.LastTradeUseTimer = nil
    self.SleepTimer = nil
    self.CurrentSellList = { }
    self.ItemCheckFunction = nil
    self.CallWhenCompleted = nil
    self.CallWhileMoving = nil
	self.BargainState = 0
	self.BargainCount = 0
	self.BargainDice = 0

    return self
end

function TradeManagerState:NeedToRun()

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
    
    if self.Forced and not Navigator.CanMoveTo(self:GetPosition()) then
    self.Forced = false
        return false
    elseif self.Forced == true then
        return true
    end



    if self.LastTradeUseTimer ~= nil and not self.LastTradeUseTimer:Expired() then
        return false
    end


    if self.Settings.TradeManagerOnInventoryFull and
        selfPlayer.Inventory.FreeSlots <= 2 and
        table.length(self:GetItems()) > 0 and
        Navigator.CanMoveTo(self:GetPosition()) then
        self.Forced = true
        return true
    end

    return false
end

function TradeManagerState:Reset()
    self.State = 0
    self.LastTradeUseTimer = nil
    self.SleepTimer = nil
    self.Forced = false
end

function TradeManagerState:Exit()
    if self.State > 1 then
        if TradeMarket.IsTrading then
            TradeMarket.Close()
        end

        if Dialog.IsTalking then
            Dialog.ClickExit()
        end
        self.State = 0
        self.LastTradeUseTimer = PyxTimer:New(self.Settings.SecondsBetweenTries)
        self.LastTradeUseTimer:Start()
        self.SleepTimer = nil
        self.Forced = false

    end

end




function TradeManagerState:Run()

    local selfPlayer = GetSelfPlayer()
    local TradeManagerPosition = self:GetPosition()

    if TradeManagerPosition.Distance3DFromMe > 200 then
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

        Navigator.MoveTo(TradeManagerPosition,false,self.Settings.PlayerRun)
        if self.State > 1 then
            self:Exit()
            return
        end
        self.State = 1
        return
    end

    ::close_enough::
    Navigator.Stop()

    if self.SleepTimer ~= nil and self.SleepTimer:IsRunning() and self.SleepTimer:Expired() == false then
        return
    end

        if string.find(selfPlayer.CurrentActionName, "WAIT", 1) == nil then
        self.SleepTimer = PyxTimer:New(2)
        return
    end

    local npcs = GetNpcs()

    if table.length(npcs) < 1 then
        print("TradeManager could not find any NPC's")
        self:Exit()
        return
    end

    table.sort(npcs, function(a, b) return a.Position:GetDistance3D(TradeManagerPosition) < b.Position:GetDistance3D(TradeManagerPosition) end)
    local npc = npcs[1]
    if self.State == 1 then
        self.SleepTimer = PyxTimer:New(3)
        self.SleepTimer:Start()
        self.State = 2
    end

    if self.State == 2 then
        npc:InteractNpc()
        self.SleepTimer = PyxTimer:New(2)
        self.SleepTimer:Start()
        self.State = 3
        return
    end


    if self.State == 3 then
        if not Dialog.IsTalking then
            print("TradeManager Error Dialog didn't open")
            self:Exit()
            return
        end
        -- BDOLua.Execute("npcShop_requestList()")
		BDOLua.Execute("HandleClickedFuncButton(getDialogButtonIndexByType(CppEnums.ContentsType.Contents_Shop))") -- yes. Contents_Shop is correct.
        self.SleepTimer = PyxTimer:New(2)
        self.SleepTimer:Start()
        self.State = 4
        self.CurrentSellList = self:GetItems()
        return
    end

	if self.State == 4 then
		if self.Settings.DoBargainGame == true then
			if self.BargainState == 0 then
				local energy = tonumber(BDOLua.Execute("return getSelfPlayer():getWp()"))
				if energy >= 5 then
					BDOLua.Execute("click_TradeGameStart()")
					BDOLua.Execute("messageBox_YesButtonUp()")
					self.BargainCount = 0
					if math.random(2) == 2 then
						self.BargainDice = 0
					else
						self.BargainDice = 1
					end
					self.SleepTimer = PyxTimer:New(2)
					self.SleepTimer:Start()
					self.BargainState = 1
				else
					print("Not enought energy. Skipping trade minigame")
					self.SleepTimer = PyxTimer:New(2)
					self.SleepTimer:Start()
					self.BargainState = 0
					self.State = 5
				end
			elseif self.BargainState == 1 then
				if BDOLua.Execute("return isTradeGameSuccess()") == true then
					BDOLua.Execute("Fglobal_TradeGame_Close()")
					self.SleepTimer = PyxTimer:New(2)
					self.SleepTimer:Start()
					self.BargainState = 0
					self.State = 5
					self.CurrentSellList = self:GetItems()
				elseif self.BargainCount >= 3 then
					BDOLua.Execute("Fglobal_TradeGame_Close()")
					self.SleepTimer = PyxTimer:New(2)
					self.SleepTimer:Start()
					self.BargainState = 0
				else
					if self.BargainDice == 0 then
						-- print("[" .. os.date(Bot.UsedTimezone) .. "] Low dice")
						BDOLua.Execute("tradeGame_LowDice()")
						self.BargainDice = 1
					else
						-- print("[" .. os.date(Bot.UsedTimezone) .. "] High dice")
						BDOLua.Execute("tradeGame_HighDice()")
						self.BargainDice = 0
					end
					self.SleepTimer = PyxTimer:New(2)
					self.SleepTimer:Start()
					self.BargainCount = self.BargainCount + 1
				end
			end
		else
			self.State = 5
		end
		return
	end
	
    if self.State == 5 then
		if self.Settings.DoTradeGame then
		BDOLua.Execute("FromClient_TradeGameResult(true)")
        print("We Won!")
		self.SleepTimer = PyxTimer:New(1)
        self.SleepTimer:Start()
        end
    self.State = 6
    end

    if self.State == 6 then

        if table.length(self.CurrentSellList) < 1 then
            print("TradeManager done list")
            self:Exit()
            return
        end
        -- Currently only sell All supported
        TradeMarket.SellAll()
        self.SleepTimer = PyxTimer:New(2)
        self.SleepTimer:Start()
        self.State = 7
        return
    end

    if self.State == 7 then
        if TradeMarket.IsTrading then
            TradeMarket.Close()
        end
        self.SleepTimer = PyxTimer:New(1)
        self.SleepTimer:Start()
        self.State = 8
        return
    end

    if self.State == 8 then
        if self.CallWhenCompleted then
            self.CallWhenCompleted(self)
        end
        self:Exit()
        return
    end


    self:Exit()

end


function TradeManagerState:GetItems()
    local items = { }
    local selfPlayer = GetSelfPlayer()
    if selfPlayer then
        for k, v in pairs(selfPlayer.Inventory.Items) do
            if v.ItemEnchantStaticStatus.IsTradeAble == true then
                if self.ItemCheckFunction then
                    if self.ItemCheckFunction(v) then
                        table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                    end
                else
                    if not table.find(self.Settings.IgnoreItemsNamed, v.ItemEnchantStaticStatus.Name) then
                        table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                    end

                end
            end
        end
    end
    return items
end



function TradeManagerState:HasNpc()
    return string.len(self.Settings.NpcName) > 0
end

function TradeManagerState:GetPosition()
    return Vector3(self.Settings.NpcPosition.X, self.Settings.NpcPosition.Y, self.Settings.NpcPosition.Z)
end
