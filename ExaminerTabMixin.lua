ExaminerTabMixin = {}

function ExaminerTabMixin:OnClick()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB);
	Examiner:SwitchTabs(self:GetID());
end

function ExaminerTabMixin:OnLeave()
	GameTooltip_Hide(self);
end
