ExaminerPvpTalentButtonMixin = {}

function ExaminerPvpTalentButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetPvpTalent(self:GetID(), true);
end

function ExaminerPvpTalentButtonMixin:OnClick()
	if (IsModifiedClick("CHATLINK")) then
		local link = GetPvpTalentLink(self:GetID());
		if (link) then
			ChatEdit_InsertLink(link);
		end
	end
end
