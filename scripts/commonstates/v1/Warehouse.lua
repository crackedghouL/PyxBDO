
WarehouseState = { }
WarehouseState.__index = WarehouseState
WarehouseState.Name = "Warehouse"
-- WarehouseState.DefaultSettings = { NpcName = "", NpcPosition = { X = 0, Y = 0, Z = 0 }, DepositItems = true, DepositMoney = true, MoneyToKeep = 10000, IgnoreItemsNamed = { }, SecondsBetweenTries = 3000}

setmetatable(WarehouseState, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
} )

function WarehouseState.new()
    local self = setmetatable( { }, WarehouseState)

    self.Settings = { Enabled = true, PlayerRun = true, NpcName = "", NpcPosition = { X = 0, Y = 0, Z = 0 }, DepositItems = true, ExchangeGold = false, DepositMoney = true, MoneyToKeep = 10000, IgnoreItemsNamed = { }, SecondsBetweenTries = 300 }

    self.State = 0
    -- 0 = Nothing, 1 = Moving, 2 = Arrived
    self.DepositList = nil

    self.LastUseTimer = nil
    self.SleepTimer = nil
    self.CurrentDepositList = { }
    self.DepositedMoney = false
    self.ExchangedGold = false
    self.GoldIndex = nil
    self.Forced = false

    -- Overideable functions
    self.ItemCheckFunction = nil
    self.CallWhenCompleted = nil
    self.CallWhileMoving = nil

    return self
end

function WarehouseState:NeedToRun()

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

    if self.Forced and not Navigator.CanMoveTo(self:GetPosition()) then
        self.Forced = false
        print("Warehouse: Was forced but can not find path cancelling")
        return false
    elseif self.Forced == true then
        return true
    end

    if self.LastUseTimer ~= nil and not self.LastUseTimer:Expired() then
        return false
    end

    if self.Settings.DepositItems and selfPlayer.Inventory.FreeSlots <= 2 and
        table.length(self:GetItems()) > 0 and
        Navigator.CanMoveTo(self:GetPosition()) then
        self.Forced = true
        print("WareHouse: My inventory is almost full")
        return true
    end

    if selfPlayer.WeightPercent >= 95 and
        table.length(self:GetItems()) > 0 and
        Navigator.CanMoveTo(self:GetPosition()) then
        print("WareHouse: My I am too heavy")
        self.Forced = true
        return true
    end

    return false
end

function WarehouseState:Reset()
    self.State = 0
    self.LastUseTimer = nil
    self.SleepTimer = nil
    self.Forced = false
    self.ExchangedGold = false
    self.GoldIndex = nil
    self.DepositedMoney = false

end


function WarehouseState:Exit()

    if self.State > 1 then
        if Dialog.IsTalking then
            Dialog.ClickExit()
        end
        self.State = 0
        self.LastUseTimer = PyxTimer:New(self.Settings.SecondsBetweenTries)
        self.LastUseTimer:Start()
        self.SleepTimer = nil
        self.Forced = false
        self.ExchangedGold = false
        self.GoldIndex = nil
        self.DepositedMoney = false

    end

end

function WarehouseState:Run()
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

    if self.SleepTimer ~= nil and self.SleepTimer:IsRunning() and not self.SleepTimer:Expired() then
        return
    end

        if string.find(selfPlayer.CurrentActionName, "WAIT", 1) == nil then
        self.SleepTimer = PyxTimer:New(2)
        return
    end

    local npcs = GetNpcs()

    if table.length(npcs) < 1 then
        print("Warehouse could not find any NPC's")
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
        if not Dialog.IsTalking then
            print("Warehouse Error Dialog didn't open")
        self.SleepTimer = PyxTimer:New(1)
        self.SleepTimer:Start()
            self.State = 10
            return
        end
        BDOLua.Execute("Warehouse_OpenPanelFromDialog()")
        self.SleepTimer = PyxTimer:New(1)
        self.SleepTimer:Start()
        self.State = 3
        self.CurrentDepositList = self:GetItems()
        return
    end

    if self.State == 3 then
        if self.ExchangedGold == false and self.Settings.ExchangeGold == true then
            local shopOpen = BDOLua.Execute("return Panel_Window_NpcShop:GetShow()")
            if not shopOpen then
                BDOLua.Execute("npcShop_requestList()")
                self.SleepTimer = PyxTimer:New(0.5)
                self.SleepTimer:Start()
                return
            end
            if self:BarAmount() and shopOpen then
                BDOLua.Execute("npcShop_doBuy(".. self.GoldIndex ..", 1, 0, 0)")
                self.SleepTimer = PyxTimer:New(0.5)
                self.SleepTimer:Start()
                return
            end
            self.ExchangedGold = true
        end
        if self.DepositedMoney == false and self.Settings.DepositMoney == true then
            local toDeposit = selfPlayer.Inventory.Money - self.Settings.MoneyToKeep
            if toDeposit > 0 then
                selfPlayer:WarehousePushMoney(npc, toDeposit)
                self.DepositedMoney = true
                self.SleepTimer = PyxTimer:New(0.5)
                self.SleepTimer:Start()
                return
            end
            self.DepositedMoney = true
        end

        if table.length(self.CurrentDepositList) < 1 then
            print("Warehouse done list")
            self.State = 4
                self.SleepTimer = PyxTimer:New(1)
                self.SleepTimer:Start()
            return
        end

        local item = self.CurrentDepositList[1]
        local itemPtr = selfPlayer.Inventory:GetItemByName(item.name)
        if itemPtr ~= nil then
            print(itemPtr.InventoryIndex .. " Deposit item : " .. itemPtr.ItemEnchantStaticStatus.Name)
            itemPtr:PushToWarehouse(npc)
            self.SleepTimer = PyxTimer:New(0.5)
            self.SleepTimer:Start()
        end
        table.remove(self.CurrentDepositList, 1)
        return
    end

    if self.State == 4 then
            Dialog.ClickExit()
            if self.CallWhenCompleted then
                self.CallWhenCompleted(self)
            end
                self.SleepTimer = PyxTimer:New(1)
                self.SleepTimer:Start()
                self.State = 5
                return
    end
    self:Exit()

end

function WarehouseState:GetItems()
    local items = { }
    local selfPlayer = GetSelfPlayer()
    if selfPlayer then
        for k, v in pairs(selfPlayer.Inventory.Items) do
            if self.ItemCheckFunction ~= nil then
                if self.ItemCheckFunction(v) == true then
                    table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                end
            else
                if not table.find(self.Settings.IgnoreItemsNamed, v.ItemEnchantStaticStatus.Name) then
                    table.insert(items, { slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                end

            end
        end
    end
    return items
end

function WarehouseState:BarAmount()
    local selfPlayer = GetSelfPlayer()
    local playerMoney = selfPlayer.Inventory.Money
    if selfPlayer then
        if (playerMoney / 1001000) >= 1 then
            self.GoldIndex = 1
            return true
        elseif (playerMoney / 100100) >= 1 then
            self.GoldIndex = 0
            return true
        else
            return false
        end
    end
    return false
end

function WarehouseState:HasNpc()
    return string.len(self.Settings.NpcName) > 0
end

function WarehouseState:GetPosition()
    return Vector3(self.Settings.NpcPosition.X, self.Settings.NpcPosition.Y, self.Settings.NpcPosition.Z)
end
