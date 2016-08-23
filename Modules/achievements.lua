local mod = Examiner:CreateModule(ACHIEVEMENTS, ACHIEVEMENTS);
mod:HasButton(true);

local unit = nil;

local function CanCompare()
	return UnitExists(unit) and UnitIsPlayer(unit);
end

function mod:OnInspect(_unit)
	unit = _unit;
	self:HasData(CanCompare());
end

function mod:OnInspectReady(_unit)
	unit = _unit;
	self:HasData(CanCompare());
end

function mod:OnTargetChanged()
	unit = Examiner.unit;
	self:HasData(CanCompare());
end

function mod:OnButtonClick(frame, button)
	if CanCompare() then
		AchievementFrame_LoadUI();
		AchievementFrame_DisplayComparison(unit);
	end
end
