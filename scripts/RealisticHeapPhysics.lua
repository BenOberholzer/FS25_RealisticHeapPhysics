RealisticHeapPhysics = {}
RealisticHeapPhysics.SMOOTH_RADIUS_FACTOR = 1.3
RealisticHeapPhysics.SIDE_SPILL_DISTANCE = 0.25
RealisticHeapPhysics.DROP_OUTER_RADIUS = 2

function RealisticHeapPhysics.canWidenDrop(self, node, halfWidth)
    if self.spec_leveler.ignoreFarmlandState then
        return true
    end

    local ownerFarmId = self:getOwnerFarmId()
    local radius = RealisticHeapPhysics.DROP_OUTER_RADIUS
    for _, x in ipairs({-halfWidth - radius, 0, halfWidth + radius}) do
        for _, z in ipairs({node.zOffset - radius, node.zOffset, node.zOffset + radius}) do
            local worldX, _, worldZ = localToWorld(node.node, x, node.yOffset, z)
            if not g_farmlandManager:getCanAccessLandAtWorldPosition(ownerFarmId, worldX, worldZ) then
                return false
            end
        end
    end
    return true
end

function RealisticHeapPhysics.onLevelerUpdate(self, superFunc, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local changedNodes = {}
    local spec = self.spec_leveler

    if self.isServer and self.movingDirection == spec.pickUpDirection then
        for _, node in pairs(spec.nodes) do
            if node.allowsSmoothing then
                local x0, y0, z0 = localToWorld(node.node, -node.halfWidth, node.yOffset, node.maxDropDirOffset)
                local x1, y1, z1 = localToWorld(node.node, node.halfWidth, node.yOffset, node.maxDropDirOffset)
                local fillType = DensityMapHeightUtil.getFillTypeAtLine(x0, y0, z0, x1, y1, z1, 0.5 * node.maxDropDirOffset)

                if fillType == FillType.WOODCHIPS or fillType == FillType.CHAFF or fillType == FillType.SILAGE then
                    local entry = {
                        node = node,
                        direction = node.smoothDirection,
                        radius = node.smoothGroundRadius,
                        adjustedRadius = node.smoothGroundRadius * RealisticHeapPhysics.SMOOTH_RADIUS_FACTOR
                    }
                    changedNodes[#changedNodes + 1] = entry
                    node.smoothDirection = 0
                    node.smoothGroundRadius = entry.adjustedRadius

                    local unitType = self:getFillUnitFillType(node.fillUnitIndex)
                    local unitLevel = self:getFillUnitFillLevel(node.fillUnitIndex)
                    local canUseMaterial = unitType == fillType
                        or ((unitType == FillType.UNKNOWN
                            or unitLevel < g_densityMapHeightManager:getMinValidLiterValue(unitType) + 0.001)
                            and self:getFillUnitSupportsFillType(node.fillUnitIndex, fillType))

                    if self.lastSpeed > 0.0001 and self:getIsLevelerPickupNodeActive(node) and canUseMaterial then
                        entry.heightChecks = node.numHeightLimitChecks
                        node.numHeightLimitChecks = 0

                        local spillWidth = node.halfWidth + RealisticHeapPhysics.SIDE_SPILL_DISTANCE
                        local minWidth = math.max(node.halfMinDropWidth, spillWidth)
                        local maxWidth = math.max(node.halfMaxDropWidth, spillWidth)
                        if RealisticHeapPhysics.canWidenDrop(self, node, math.max(minWidth, maxWidth)) then
                            entry.minDropWidth = node.halfMinDropWidth
                            entry.maxDropWidth = node.halfMaxDropWidth
                            entry.adjustedMinDropWidth = minWidth
                            entry.adjustedMaxDropWidth = maxWidth
                            node.halfMinDropWidth = minWidth
                            node.halfMaxDropWidth = maxWidth
                        end
                    end
                end
            end
        end
    end

    if #changedNodes == 0 then
        return superFunc(self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    end

    local success, result = pcall(superFunc, self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

    for _, entry in ipairs(changedNodes) do
        if entry.node.smoothDirection == 0 then
            entry.node.smoothDirection = entry.direction
        end
        if entry.node.smoothGroundRadius == entry.adjustedRadius then
            entry.node.smoothGroundRadius = entry.radius
        end
        if entry.heightChecks ~= nil and entry.node.numHeightLimitChecks == 0 then
            entry.node.numHeightLimitChecks = entry.heightChecks
        end
        if entry.minDropWidth ~= nil and entry.node.halfMinDropWidth == entry.adjustedMinDropWidth then
            entry.node.halfMinDropWidth = entry.minDropWidth
        end
        if entry.maxDropWidth ~= nil and entry.node.halfMaxDropWidth == entry.adjustedMaxDropWidth then
            entry.node.halfMaxDropWidth = entry.maxDropWidth
        end
    end

    if not success then
        error(result, 0)
    end
    return result
end

Leveler.onUpdate = Utils.overwrittenFunction(Leveler.onUpdate, RealisticHeapPhysics.onLevelerUpdate)
