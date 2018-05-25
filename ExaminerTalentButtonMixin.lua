ExaminerTalentButtonMixin = {}

function ExaminerTalentButtonMixin:OnEnter()
	local data = Examiner.data;

	if (not data or not data.specGroup) then
		return;
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");	
	GameTooltip:SetTalent(self:GetID(), true, data.specGroup, data.unit, data.classID);
end

function ExaminerTalentButtonMixin:OnClick()
	if (IsModifiedClick("CHATLINK")) then
		ChatEdit_InsertLink(GetTalentLink(self:GetID()));
	end
end
