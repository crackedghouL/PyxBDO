Navigator = { }
Navigator.Running = false
Navigator.Destination = Vector3(0, 0, 0)
Navigator.Waypoints = { }
Navigator.ApproachDistance = 190
Navigator.LastObstacleCheckTick = 0
Navigator.LastFindPathTick = 0
Navigator.LastStuckCheckTickcount = 0
Navigator.LastStuckTimer = PyxTimer:New(0.5)
Navigator.LastStuckCheckPosition = Vector3(0, 0, 0)
Navigator.LastMoveTo = Vector3(0, 0, 0)
Navigator.LastPosition = Vector3(0, 0, 0)
Navigator.LastWayPoint = false
Navigator.StuckCount = 0
Navigator.OnStuckCall = nil
Navigator.PlayerRun = false
Navigator.MeshConnects = { }
Navigator.MeshConnectEnabled = false
Navigator.PathingMode = 1 -- 1 = Pyx Meshing, 2 = Experimental BDO Pathing
Navigator.SentAutoPath = PyxTimer:New(1)
Navigator.MaxTriangles = 50
Navigator.MaxLines = 50


function Navigator.MeshConnectToVector3(meshConnect)
    local newpath = { }
    for key, value in pairs(meshConnect) do
        newpath[#newpath + 1] = Vector3(value.X, value.Y, value.Z)
    end

    return newpath
end

function Navigator.AppendPath(patha, pathb)
    local newpath = { }
    for key, value in pairs(patha) do
        newpath[#newpath + 1] = value
    end
    for key, value in pairs(pathb) do
        newpath[#newpath + 1] = value
    end
    return newpath
end

function Navigator.StartPathAtKey(key, path)
    local newpath = { }
    local tlength = table.length(path)

    for cnt = key, tlength do
        newpath[#newpath + 1] = path[cnt]
    end
    return newpath
end


function Navigator.ReversePath(path)
    local newpath = { }
    local tlength = table.length(path)

    for cnt = 1, tlength do
        newpath[#newpath + 1] = path[tlength - cnt + 1]
    end


    return newpath
end


function Navigator.FindClosestPoint(path, position)
    local tlength = table.length(path)
    local key = 0
    local lastlength = 0
    for cnt = 1, tlength do
        if key == 0 or lastlength >= path[cnt].Distance3DFromMe then
            key = cnt
            lastlength = path[cnt].Distance3DFromMe

        end

    end
    return key
end


function Navigator.GetPath(startPoint, endPoint)
    local selfPlayer = GetSelfPlayer()
    local waypoints = Navigation.FindPath(startPoint, endPoint)

    if table.length(waypoints) > 0 and waypoints[#waypoints]:GetDistance3D(endPoint) < 500 then
        return waypoints
    end
    -- no direct path lets check mesh connects
    --    print ("sp "..tostring(startPoint.IsOnMesh))
    --    print ("ep "..tostring(endPoint.IsOnMesh))

    if startPoint.IsOnMesh == true and endPoint.IsOnMesh == true then
        for key, value in pairs(Navigator.MeshConnects) do

            local canmesha = Navigation.FindPath(startPoint, Vector3(value[1].X, value[1].Y, value[1].Z))
            local canmeshb = Navigation.FindPath(Vector3(value[#value].X, value[#value].Y, value[#value].Z), endPoint)

            local canmeshc = Navigation.FindPath(startPoint, Vector3(value[#value].X, value[#value].Y, value[#value].Z))
            local canmeshd = Navigation.FindPath(Vector3(value[1].X, value[1].Y, value[1].Z), endPoint)

            if (table.length(canmesha) > 0 and canmesha[#canmesha]:GetDistance3D(Vector3(value[1].X, value[1].Y, value[1].Z)) < 500) and
                (table.length(canmeshb) > 0 and canmeshb[#canmeshb]:GetDistance3D(endPoint) < 500) then
                --                print("Forward Connect")
                return Navigator.AppendPath(Navigator.AppendPath(canmesha, Navigator.MeshConnectToVector3(value)), canmeshb)
            end
            if ((table.length(canmeshc) > 0 and canmeshc[#canmeshc]:GetDistance3D(Vector3(value[#value].X, value[#value].Y, value[#value].Z)) < 500)) and
                ((table.length(canmeshd) > 0 and canmeshd[#canmeshd]:GetDistance3D(endPoint) < 500)) then
                --                print("Reverse Connect")

                local testb = Navigator.MeshConnectToVector3(Navigator.ReversePath(value))
                -- return testb
                return Navigator.AppendPath(Navigator.AppendPath(canmeshc, testb), canmeshd)

            end
        end
    elseif endPoint.IsOnMesh == true then
        for key, value in pairs(Navigator.MeshConnects) do
            local canmesha = Navigation.FindPath(Vector3(value[#value].X, value[#value].Y, value[#value].Z), endPoint)
            local canmeshb = Navigation.FindPath(Vector3(value[1].X, value[1].Y, value[1].Z), endPoint)
            if (table.length(canmesha) > 0 and canmesha[#canmesha]:GetDistance3D(endPoint) < 500) then
                local point = Navigator.MeshConnectToVector3(value)
                local closestPoint = Navigator.FindClosestPoint(point)
                if (point[closestPoint].Distance3DFromMe < 500) then
                    return Navigator.StartPathAtKey(closestPoint, Navigator.AppendPath(point, canmesha))
                end
            end
            if (table.length(canmeshb) > 0 and canmeshb[#canmeshb]:GetDistance3D(endPoint) < 500) then
                local point = Navigator.ReversePath(Navigator.MeshConnectToVector3(value))
                local closestPoint = Navigator.FindClosestPoint(point)
                if (point[closestPoint].Distance3DFromMe < 500) then
                    return Navigator.StartPathAtKey(closestPoint, Navigator.AppendPath(point, canmeshb))
                end
            end
        end
    else
        --print("At least the endpoint must be on a mesh")
    end

    -- check MeshConnect here


    return nil
end

function Navigator.Reset()
Navigator.Destination = Vector3(0, 0, 0)
Navigator.Waypoints = { }
Navigator.LastObstacleCheckTick = 0
Navigator.LastFindPathTick = 0
Navigator.LastStuckCheckTickcount = 0
Navigator.LastStuckTimer = PyxTimer:New(0.5)
Navigator.LastStuckCheckPosition = Vector3(0, 0, 0)
Navigator.LastMoveTo = Vector3(0, 0, 0)
Navigator.LastPosition = Vector3(0, 0, 0)
Navigator.LastWayPoint = false
Navigator.StuckCount = 0

end

function Navigator.CanMoveTo(destination)
    local selfPlayer = GetSelfPlayer()

    if not selfPlayer then
        return false
    end

    local waypoints = Navigator.GetPath(selfPlayer.Position, destination)

    if waypoints == nil then
        return false
    end

    return true

end

function Navigator.MoveToStraight(destination)
--    local selfPlayer = GetSelfPlayer()
    Navigator.Waypoints = { }
    table.insert(Navigator.Waypoints, destination)
    Navigator.Destination = destination
    Navigator.PathingMode = 1
    Navigator.Running = true
    return true
end

function Navigator.MoveToUsingBDO(destination, playerRun)
    selfPlayer:ClearActionState()
    local myDistance = destination.Distance3DFromMe
    if myDistance < 2000 and destination.IsLineOfSight then
        selfPlayer:MoveTo(destination)

    else

        local code = string.format([[
                                                                                                ToClient_DeleteNaviGuideByGroup(0)
                                                                                                local target = float3(%f, %f, %f)
                                                                                                local repairNaviKey = ToClient_WorldMapNaviStart( target, NavigationGuideParam(), true, true )
                                                                                                local selfPlayer = getSelfPlayer():get()
                                                                                                selfPlayer:setNavigationMovePath(key)
                                                                                                selfPlayer:checkNaviPathUI(key)
                                                                                            ]], destination.X, destination.Y, destination.Z)
        BDOLua.Execute(code)
    end
    Navigator.SentAutoPath:Reset()
    Navigator.SentAutoPath:Start()
    Navigator.PathingMode = 2

    Navigator.LastFindPathTick = Pyx.Win32.GetTickCount()
    Navigator.Destination = destination
    Navigator.Running = true

end

function Navigator.MoveToUsingPyx(destination, forceRecalculate, playerRun)

    local selfPlayer = GetSelfPlayer()
    local currentPosition = selfPlayer.Position

    if not selfPlayer then
        return false
    end

    if playerRun == nil or playerRun == false then
        Navigator.PlayerRun = false
    else
        Navigator.PlayerRun = true
    end

    if (forceRecalculate == nil or forceRecalculate == false) and
        Navigator.Destination.X == destination.X and
        Navigator.Destination.Y == destination.Y and
        Navigator.Destination.Z == destination.Z and
        (table.length(Navigator.Waypoints) > 0 or Navigator.LastWayPoint == true) and
        Navigator.LastPosition.Distance2DFromMe < 150
    then
        Navigator.Running = true

        return true
    end

    local waypoints = Navigator.GetPath(selfPlayer.Position, destination)

    if waypoints == nil then
        print("Cannot find path !")
        Navigator.Running = false
        return false
    end


    if waypoints[#waypoints]:GetDistance3D(destination) > Navigator.ApproachDistance then
        table.insert(waypoints, destination)
    end

    while waypoints[1] and waypoints[1].Distance3DFromMe <= Navigator.ApproachDistance and table.length(waypoints) > 1 do
        table.remove(waypoints, 1)
    end
    Navigator.Waypoints = waypoints

    Navigator.LastFindPathTick = Pyx.Win32.GetTickCount()
    Navigator.Destination = destination
    Navigator.PathingMode = 1
    Navigator.Running = true
    return true

end
function Navigator.MoveTo(destination, forceRecalculate, playerRun, pathMode)

    if pathMode == nil or pathMode == 1 then
        return Navigator.MoveToUsingPyx(destination, forceRecalculate, playerRun)
    elseif pathMode ~= nil and pathMode == 2 then
        return Navigator.MoveToUsingBDO(destination, playerRun)
    end
    return false

end

function Navigator.Stop(shortStop)
    local selfPlayer = GetSelfPlayer()
    Navigator.Running = false
    Navigator.Waypoints = { }
    Navigator.Destination = Vector3(0, 0, 0)
    Navigator.LastWayPoint = false
    Navigator.StuckCount = 0
                Navigator.LastStuckTimer:Reset()
            Navigator.LastStuckTimer:Start()
            Navigator.LastStuckCheckPosition = selfPlayer.Position

--    selfPlayer:ClearActionState()

    if selfPlayer then
        selfPlayer:MoveTo(Vector3(0, 0, 0))
    end
    if shortStop ~= nil and shortStop == true then
--        GetSelfPlayer():DoAction("RUN_SHORTSTOP")
    end
end

function Navigator.OnPulse()

    local selfPlayer = GetSelfPlayer()
	
	if not selfPlayer then
		return
	end

    if selfPlayer ~= nil and (Navigator.Running == false and selfPlayer.IsSwimming == false) or(string.find(selfPlayer.CurrentActionName, "STANCE_CHANGE", 1) ~= nil) then
        Navigator.LastStuckTimer:Reset()
        Navigator.LastStuckTimer:Start()
        Navigator.LastStuckCheckPosition = selfPlayer.Position
    end

    if Navigator.Running == true and selfPlayer ~= nil then
        Navigator.LastPosition = selfPlayer.Position

        if Pyx.Win32.GetTickCount() - Navigator.LastObstacleCheckTick > 1000 then
            -- Navigation.UpdateObstacles()
            -- Do not use for now, it's coming :)
            Navigator.LastObstacleCheckTick = Pyx.Win32.GetTickCount()
        end


        if Navigator.LastStuckTimer:Expired() == true then
            if (Navigator.LastStuckCheckPosition.Distance2DFromMe < 35) then
--                print("I'm stuck")
                -- , jump forward !")
--                print(selfPlayer.CurrentActionName)
                if Navigator.StuckCount == 5 or Navigator.StuckCount == 7 or Navigator.StuckCount == 20 or Navigator.StuckCount == 30 then
                    print("Set Move Forward")
                    selfPlayer:SetActionState(ACTION_FLAG_MOVE_FORWARD, 1000)
                elseif Navigator.StuckCount == 6 or Navigator.StuckCount == 10 then
                    print("Jump Forward")
                    Keybindings.HoldByActionId(KEYBINDING_ACTION_JUMP, 500)
                elseif Navigator.StuckCount == 15  then
                    print("Move Right")
                    selfPlayer:SetActionState(ACTION_FLAG_MOVE_RIGHT, 1000)
                elseif Navigator.StuckCount == 25  then
                    print("Move Left")
                    selfPlayer:SetActionState(ACTION_FLAG_MOVE_LEFT, 1000)
                end
                Navigator.StuckCount = Navigator.StuckCount + 1
                if Navigator.StuckCount == 30 and Navigator.PathingMode == 1 then
                    print("Still stuck. lets try to re-generate path")
                    Navigator.MoveTo(Navigator.Destination, true)
                end
                if Navigator.OnStuckCall ~= nil then
                    Navigator.OnStuckCall()
                end
            else
                Navigator.StuckCount = 0
            end
            Navigator.LastStuckTimer:Reset()
            Navigator.LastStuckTimer:Start()
            Navigator.LastStuckCheckPosition = selfPlayer.Position
        end

        if Navigator.PathingMode == 2 then
            -- and(selfPlayer.CurrentActionName ~= "AUTO_RUN"
            --            and string.find(selfPlayer.CurrentActionName, "RUN_SPRINT_FAST", 1) == nil) then -- and Navigator.Destination.Distance3DFromMe > Navigator.ApproachDistance then
            local myDistance = Navigator.Destination.Distance3DFromMe
            if myDistance > 500 then
                if string.find(selfPlayer.CurrentActionName, "AUTO_RUN", 1) == nil
                    and string.find(selfPlayer.CurrentActionName, "RUN_SPRINT_FAST", 1) == nil
                    and(Navigator.SentAutoPath:IsRunning() == false or Navigator.SentAutoPath:Expired() == true) then
                    if Navigator.Destination.IsLineOfSight then
                        selfPlayer:MoveTo(Navigator.Destination)
                    else
                        print(Navigator.Destination.IsLineOfSight)
                        local code = string.format([[
                                                                                                                                                                        ToClient_DeleteNaviGuideByGroup(0)
                                                                                                                                                                        local target = float3(%f, %f, %f)
                                                                                                                                                                        local repairNaviKey = ToClient_WorldMapNaviStart( target, NavigationGuideParam(), true, true )
                                                                                                                                                                        local selfPlayer = getSelfPlayer():get()
                                                                                                                                                                        selfPlayer:setNavigationMovePath(key)
                                                                                                                                                                        selfPlayer:checkNaviPathUI(key)
                                                                                                                                                                    ]], Navigator.Destination.X, Navigator.Destination.Y, Navigator.Destination.Z)
                        BDOLua.Execute(code)

                    end
                end
                return
            end
            if myDistance > Navigator.ApproachDistance then
                selfPlayer:MoveTo(Navigator.Destination)
            else
                selfPlayer:ClearActionState()
            end

            return
        end

        if Navigator.PathingMode == 1 then
            local nextWaypoint = Navigator.Waypoints[1]
            if nextWaypoint then
                if nextWaypoint.Distance2DFromMe > Navigator.ApproachDistance then
                    selfPlayer:MoveTo(nextWaypoint)
                else
                    table.remove(Navigator.Waypoints, 1)
                    if table.length(Navigator.Waypoints) == 0 then
                        Navigator.LastWayPoint = true
                    else
                        Navigator.LastWayPoint = false
                    end
                end
            end
            --[[
            if Navigator.LastWayPoint == false and Navigator.PlayerRun == true and selfPlayer.StaminaPercent >= 100 and selfPlayer.IsSwimming == false and table.length(Navigator.Waypoints) > 6 then
                if selfPlayer.IsBattleMode == false then
                    selfPlayer:DoAction("RUN_SPRINT_FAST_ST")
                else
                    selfPlayer:DoAction("BT_RUN_SPRINT")
                end
            end
            --]]
        end

    end

end


function Navigator.OnRender3D()
    local selfPlayer = GetSelfPlayer()
    if selfPlayer then
        local linesList = { }
        local count = 0
        if Navigator.Waypoints ~= nil then
            for k, v in pairs(Navigator.Waypoints) do
                if count <= Navigator.MaxTriangles then
                    Renderer.Draw3DTrianglesList(GetInvertedTriangleList(v.X, v.Y + 20, v.Z, 10, 20, 0xFFFFFFFF, 0xFFFFFFFF))
                    count = count + 1
                end
            end
            local firstPoint = Navigator.Waypoints[1]
            if firstPoint then
                table.insert(linesList, { selfPlayer.Position.X, selfPlayer.Position.Y + 20, selfPlayer.Position.Z, 0xFFFFFFFF })
                table.insert(linesList, { firstPoint.X, firstPoint.Y + 20, firstPoint.Z, 0xFFFFFFFF })
            end
            count = 0
            for k, v in ipairs(Navigator.Waypoints) do
                if count <= Navigator.MaxLines then
                local nextPoint = Navigator.Waypoints[k + 1]
                    if nextPoint then
                        table.insert(linesList, { v.X, v.Y + 20, v.Z, 0xFFFFFFFF })
                        table.insert(linesList, { nextPoint.X, nextPoint.Y + 20, nextPoint.Z, 0xFFFFFFFF })
                        count = count + 1
                    end
                end
            end
            if table.length(linesList) > 0 then
                Renderer.Draw3DLinesList(linesList)
            end
        end
    end
end
