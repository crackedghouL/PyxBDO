RepairState = { }
RepairState.__index = RepairState
RepairState.Name = "Repair"

setmetatable(RepairState, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
} )

function RepairState.new()
    local self = setmetatable( { }, RepairState)
    self.State = 0
    self.Settings = { Enabled = true, NpcName = "", NpcPosition = { X = 0, Y = 0, Z = 0 }, SecondsBetweenTries = 300, RepairInventory = true, RepairEquipped = true, PlayerRun = true, UseWarehouseMoney = false }

    self.Forced = false
    self.LastUseTimer = nil
    self.SleepTimer = nil

    self.CallWhenCompleted = nil
    self.CallWhileMoving = nil
    self.RepairCheck = nil
    self.ItemCheckFunction = nil
    self.Items = { }

    return self
end

function RepairState:NeedToRun()

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

    if self.Forced == true and not Navigator.CanMoveTo(self:GetPosition()) then
        print("Repair: Was forced but can not find path cancelling")

        self.Forced = false
        return false
    elseif self.Forced == true then
        return true
    end

    if self.RepairCheck ~= nil then
        if self.RepairCheck() == true then
            print("Repair: RepairCheck function returned true head to repair")
            self.Forced = true
            return true
        end
        return false
    end

    if self.LastUseTimer ~= nil and not self.LastUseTimer:Expired() then
        return false
    end

    for k, v in pairs(selfPlayer.EquippedItems) do
        if v.HasEndurance and v.EndurancePercent <= 20 then
            if Navigator.CanMoveTo(self:GetPosition()) then
                self.Forced = true
                print("Repair: an Item is below 20% Name:" .. v.ItemEnchantStaticStatus.Name .. " " .. v.EndurancePercent .. "% has: " .. v.Endurance .. " of " .. v.MaxEndurance)

                return true
            else
                print("Need to Repair! Can not find path to NPC: " .. self.Settings.NpcName)
                return false
            end

        end
    end

    return false
end

function RepairState:HasNpc()
    return string.len(self.Settings.NpcName) > 0
end
function RepairState:GetPosition()
    return Vector3(self.Settings.NpcPosition.X, self.Settings.NpcPosition.Y, self.Settings.NpcPosition.Z)
end

function RepairState:Reset()
    self.State = 0
    self.LastUseTimer = nil
    self.SleepTimer = nil
    self.Forced = false
    self.RepairList = { }
end

function RepairState:Exit()
    if Dialog.IsTalking then
        Dialog.ClickExit()
    end
    if self.State > 0 then
        self.State = 0
        self.LastUseTimer = PyxTimer:New(self.Settings.SecondsBetweenTries)
        self.LastUseTimer:Start()
        self.SleepTimer = nil
        self.Forced = false
        self.RepairList = { }
    end

end

function RepairState:Run()
    local selfPlayer = GetSelfPlayer()
    local vendorPosition = self:GetPosition()
	local flushdialog = [[
	MessageBox.keyProcessEscape()
	]]
	local confirm = [[
	MessageBox.keyProcessEnter()
	]]
	local equippedwarehouse = [[
	UI.getChildControl( Panel_Equipment, "RadioButton_Icon_Money2"):SetCheck(true)
	UI.getChildControl(Panel_Equipment,"RadioButton_Icon_Money"):SetCheck(false)
	RepairAllEquippedItemBtn_LUp()
	]]
	local invenwarehouse = [[
	UI.getChildControl( Panel_Equipment, "RadioButton_Icon_Money2"):SetCheck(true)
	UI.getChildControl(Panel_Equipment,"RadioButton_Icon_Money"):SetCheck(false)
	RepairAllInvenItemBtn_LUp()
	]]

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
        print("Repair could not find any NPC's")
        self:Exit()
        return
    end
    table.sort(npcs, function(a, b) return a.Position:GetDistance3D(vendorPosition) < b.Position:GetDistance3D(vendorPosition) end)

    local npc = npcs[1]

    if self.State == 1 then
        npc:InteractNpc()
        self.SleepTimer = PyxTimer:New(2)
        self.SleepTimer:Start()
        self.State = 2
        return true
    end

    if self.State == 2 then
        self.State = 3
        BDOLua.Execute(flushdialog)
        -- BDOLua.Execute("Repair_OpenPanel( true)")
		BDOLua.Execute("HandleClickedFuncButton(getDialogButtonIndexByType(CppEnums.ContentsType.Contents_Repair))")
        self.SleepTimer = PyxTimer:New(2)
        self.SleepTimer:Start()
        return
    end

    if self.State == 3 then
        self.State = 3.5
        
        if self.Settings.RepairEquipped == true then
		if self.Settings.UseWarehouseMoney then
				print("Warehouse Money true")
			end
			print(tonumber(BDOLua.Execute("return Int64toInt32(warehouse_moneyFromNpcShop_s64())")))
            if self.Settings.UseWarehouseMoney and tonumber(BDOLua.Execute("return Int64toInt32(warehouse_moneyFromNpcShop_s64())")) > 100 then
				BDOLua.Execute(equippedwarehouse)
					else
 					selfPlayer:RepairAllEquippedItems(npc)
 				end
            self.SleepTimer = PyxTimer:New(1)
            self.SleepTimer:Start()
        end
        return
    end
    
    if self.State == 3.5 then
		self.State = 3.9
		BDOLua.Execute(confirm)
		self.SleepTimer = PyxTimer:New(1)
		self.SleepTimer:Start()
		return
	end
	if self.State == 3.9 then
		self.State = 4
		BDOLua.Execute(flushdialog)
		self.SleepTimer = PyxTimer:New(1)
		self.SleepTimer:Start()
		return
	end
	
    if self.State == 4 then
        self.State = 4.5
        if self.Settings.RepairInventory == true then
			if self.Settings.UseWarehouseMoney then
				print("Warehouse Money true")
			end
			print(tonumber(BDOLua.Execute("return Int64toInt32(warehouse_moneyFromNpcShop_s64())")))
            if self.Settings.UseWarehouseMoney and tonumber(BDOLua.Execute("return Int64toInt32(warehouse_moneyFromNpcShop_s64())")) > 100 then 
			print("invenwarehouse")
				BDOLua.Execute(invenwarehouse)
					else
					selfPlayer:RepairAllInventoryItems(npc)
			end
            self.SleepTimer = PyxTimer:New(2)
            self.SleepTimer:Start()
        end
        return
    end
    
    if self.State == 4.5 then
		self.State = 4.9
		BDOLua.Execute(confirm)
		self.SleepTimer = PyxTimer:New(1)
		self.SleepTimer:Start()
		return
	end
	
    if self.State == 4.9 then
		self.State = 5
		BDOLua.Execute(flushdialog)
		self.SleepTimer = PyxTimer:New(1)
		self.SleepTimer:Start()
		return
    end

    if self.State == 5 then
        self.State = 6
        print("Repair Done")
        BDOLua.Execute(flushdialog)
        BDOLua.Execute("Repair_OpenPanel( false)\r\nFixEquip_Close()")
        self.SleepTimer = PyxTimer:New(1.5)
        self.SleepTimer:Start()
        Dialog.ClickExit()
        return
    end

    self:Exit()


end

function RepairState:GetItems()
    local items = { }
    local selfPlayer = GetSelfPlayer()
    if selfPlayer then
        for k, v in pairs(selfPlayer.EquippedItems) do
            if self.ItemCheckFunction then
                if self.ItemCheckFunction(v) then
                    table.insert(items, { item = v, slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                end
            else
                if v.HasEndurance and v.EndurancePercent < 100 then
                    table.insert(items, { item = v, slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                end
            end
        end
        for k, v in pairs(selfPlayer.Inventory.Items) do
            if self.ItemCheckFunction then
                if self.ItemCheckFunction(v) then
                    table.insert(items, { item = v, slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                end
            else
                if v.HasEndurance and v.EndurancePercent < 100 then
                    table.insert(items, { item = v, slot = v.InventoryIndex, name = v.ItemEnchantStaticStatus.Name, count = v.Count })
                end
            end
        end
    end

    return items
end

