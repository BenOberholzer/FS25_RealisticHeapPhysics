FillType = {UNKNOWN = 0, WOODCHIPS = 1, CHAFF = 2, SILAGE = 3, WHEAT = 4}

local material = FillType.UNKNOWN
local sampled = 0
local observedDirection
local observedRadius
local observedHeightChecks
local observedMinWidth
local observedMaxWidth
local raiseError = false
local accessAllowed = true
local active = true
local unitType = FillType.UNKNOWN
local unitLevel = 0
local supportsMaterial = true
local accessChecks = 0
local modifyDuringUpdate = false

function localToWorld(node, x, y, z)
    return x, y, z
end

DensityMapHeightUtil = {
    getFillTypeAtLine = function()
        sampled = sampled + 1
        return material
    end
}

g_densityMapHeightManager = {
    getMinValidLiterValue = function()
        return 0.1
    end
}

g_farmlandManager = {
    getCanAccessLandAtWorldPosition = function(self, farmId, x, z)
        assert(farmId == 1)
        accessChecks = accessChecks + 1
        return accessAllowed
    end
}

Leveler = {
    onUpdate = function(self, dt, input, ignoreSelection, selected)
        assert(dt == 16 and input and not ignoreSelection and selected)
        observedDirection = self.spec_leveler.nodes[1].smoothDirection
        observedRadius = self.spec_leveler.nodes[1].smoothGroundRadius
        observedHeightChecks = self.spec_leveler.nodes[1].numHeightLimitChecks
        observedMinWidth = self.spec_leveler.nodes[1].halfMinDropWidth
        observedMaxWidth = self.spec_leveler.nodes[1].halfMaxDropWidth
        if modifyDuringUpdate then
            self.spec_leveler.nodes[1].numHeightLimitChecks = 3
            self.spec_leveler.nodes[1].halfMinDropWidth = 2
            self.spec_leveler.nodes[1].halfMaxDropWidth = 3
        end
        if raiseError then
            error("leveler failure")
        end
    end
}

Utils = {
    overwrittenFunction = function(original, replacement)
        return function(self, ...)
            return replacement(self, original, ...)
        end
    end
}

dofile("scripts/RealisticHeapPhysics.lua")

local node = {
    node = 1, halfWidth = 1, yOffset = 0, maxDropDirOffset = 1,
    zOffset = 0, fillUnitIndex = 1, numHeightLimitChecks = 6,
    halfMinDropWidth = 0.5, halfMaxDropWidth = 1,
    allowsSmoothing = true, smoothDirection = -1, smoothGroundRadius = 0.5
}
local vehicle = {
    isServer = true, movingDirection = 1, lastSpeed = 0.001,
    spec_leveler = {pickUpDirection = 1, nodes = {node}},
    getOwnerFarmId = function() return 1 end,
    getFillUnitFillType = function() return unitType end,
    getFillUnitFillLevel = function() return unitLevel end,
    getFillUnitSupportsFillType = function() return supportsMaterial end,
    getIsLevelerPickupNodeActive = function() return active end
}

local function update(fillType, expected, expectedRadius, expectedHeightChecks, expectedMinWidth, expectedMaxWidth)
    material = fillType
    observedDirection = nil
    Leveler.onUpdate(vehicle, 16, true, false, true)
    assert(observedDirection == expected)
    assert(math.abs(observedRadius - expectedRadius) < 0.000001)
    assert(observedHeightChecks == (expectedHeightChecks or 6))
    assert(observedMinWidth == (expectedMinWidth or 0.5))
    assert(observedMaxWidth == (expectedMaxWidth or 1))
    assert(node.smoothDirection == -1)
    assert(node.smoothGroundRadius == 0.5)
    assert(node.numHeightLimitChecks == 6)
    assert(node.halfMinDropWidth == 0.5 and node.halfMaxDropWidth == 1)
end

update(FillType.WOODCHIPS, 0, 0.65, 0, 1.25, 1.25)
assert(accessChecks == 9)
update(FillType.CHAFF, 0, 0.65, 0, 1.25, 1.25)
update(FillType.SILAGE, 0, 0.65, 0, 1.25, 1.25)
update(FillType.WHEAT, -1, 0.5)
update(FillType.UNKNOWN, -1, 0.5)

accessAllowed = false
update(FillType.CHAFF, 0, 0.65, 0)
vehicle.spec_leveler.ignoreFarmlandState = true
update(FillType.CHAFF, 0, 0.65, 0, 1.25, 1.25)
vehicle.spec_leveler.ignoreFarmlandState = false
accessAllowed = true

active = false
update(FillType.CHAFF, 0, 0.65)
active = true
vehicle.lastSpeed = 0
update(FillType.CHAFF, 0, 0.65)
vehicle.lastSpeed = 0.001

supportsMaterial = false
update(FillType.CHAFF, 0, 0.65)
supportsMaterial = true
unitType = FillType.WHEAT
unitLevel = 10
update(FillType.CHAFF, 0, 0.65)
unitLevel = 0.01
update(FillType.CHAFF, 0, 0.65, 0, 1.25, 1.25)
unitType = FillType.CHAFF
unitLevel = 10
update(FillType.CHAFF, 0, 0.65, 0, 1.25, 1.25)
unitType = FillType.UNKNOWN
unitLevel = 0

node.halfMinDropWidth = 1.5
node.halfMaxDropWidth = 2
material = FillType.CHAFF
Leveler.onUpdate(vehicle, 16, true, false, true)
assert(observedMinWidth == 1.5 and observedMaxWidth == 2)
assert(node.halfMinDropWidth == 1.5 and node.halfMaxDropWidth == 2)
node.halfMinDropWidth = 0.5
node.halfMaxDropWidth = 1

modifyDuringUpdate = true
Leveler.onUpdate(vehicle, 16, true, false, true)
assert(node.numHeightLimitChecks == 3)
assert(node.halfMinDropWidth == 2 and node.halfMaxDropWidth == 3)
modifyDuringUpdate = false
node.numHeightLimitChecks = 6
node.halfMinDropWidth = 0.5
node.halfMaxDropWidth = 1

node.allowsSmoothing = false
update(FillType.CHAFF, -1, 0.5)
node.allowsSmoothing = true

vehicle.movingDirection = -1
update(FillType.CHAFF, -1, 0.5)
vehicle.movingDirection = 1

vehicle.isServer = false
local previousSamples = sampled
update(FillType.CHAFF, -1, 0.5)
assert(sampled == previousSamples)

vehicle.isServer = true
node.smoothDirection = 0
material = FillType.WOODCHIPS
Leveler.onUpdate(vehicle, 16, true, false, true)
assert(observedDirection == 0 and math.abs(observedRadius - 0.65) < 0.000001)
assert(node.smoothDirection == 0 and node.smoothGroundRadius == 0.5)
node.smoothDirection = -1

vehicle.isServer = true
material = FillType.CHAFF
raiseError = true
local ok, message = pcall(Leveler.onUpdate, vehicle, 16, true, false, true)
assert(not ok and string.find(message, "leveler failure", 1, true))
assert(node.smoothDirection == -1 and node.smoothGroundRadius == 0.5)
assert(node.numHeightLimitChecks == 6)
assert(node.halfMinDropWidth == 0.5 and node.halfMaxDropWidth == 1)

print("RealisticHeapPhysics tests passed")
