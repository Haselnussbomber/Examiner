ExaminerAzeriteItemOverlayMixin = {};

function ExaminerAzeriteItemOverlayMixin:SetAzeriteItem()
	self.AzeriteTexture:SetShown(self.isAzeriteItem or self.isAzeriteEmpoweredItem);
	self.RankFrame:SetShown(self.isAzeriteItem);
	self.AvailableTraitFrame:SetShown(self.isAzeriteEmpoweredItem);
	self:ResetAzeriteTextures();

	if (self.isAzeriteItem) then
		self:DisplayAsAzeriteItem();
	elseif (self.isAzeriteEmpoweredItem) then
		self:DisplayAsAzeriteEmpoweredItem();
	else
		self:ResetAzeriteItem();
	end
end

function ExaminerAzeriteItemOverlayMixin:DisplayAsAzeriteItem()
	self.AzeriteTexture:SetAtlas("AzeriteArmor-CharacterInfo-Neck", true);
	self.AzeriteTexture:SetSize(50, 44);
	self.AzeriteTexture:SetDrawLayer("OVERLAY", 1);

	local ATLAS_NAME = "AzeriteArmor-CharacterInfo-NeckHighlight";
	self:SetHighlightAtlas(ATLAS_NAME, "ADD");
	local highlightTexture = self:GetHighlightTexture();
	highlightTexture:ClearAllPoints();
	highlightTexture:SetPoint("CENTER");

	local _, width, height = GetAtlasInfo(ATLAS_NAME);
	local SCALAR = .55;
	highlightTexture:SetSize(width * SCALAR, height * SCALAR);

	self:UpdateAzeriteRank();
end

function ExaminerAzeriteItemOverlayMixin:UpdateAzeriteRank()
	if (self.azeritePowerLevel) then
		self.RankFrame.Label:SetText(self.azeritePowerLevel);
	else
		self.RankFrame:Hide();
	end
end

function ExaminerAzeriteItemOverlayMixin:DisplayAsAzeriteEmpoweredItem()
	self.AzeriteTexture:SetAtlas("AzeriteArmor-CharacterInfo-Border", true);
	self.AzeriteTexture:SetSize(57, 46);
	self.AzeriteTexture:SetDrawLayer("BORDER", -1);

	if (self.hasAnyUnselectedPowers) then
		self.AvailableTraitFrame:Show();
		self.AvailableTraitFrame.AvailableAnim:Play();
		self.AvailableTraitFrame.AvailableAnimGlow:Play();
	else
		self.AvailableTraitFrame:Hide();
		self.AvailableTraitFrame.AvailableAnim:Finish();
		self.AvailableTraitFrame.AvailableAnimGlow:Finish();
	end
end

function ExaminerAzeriteItemOverlayMixin:ResetAzeriteItem()
	self.AzeriteTexture:Hide();
	self.RankFrame:Hide();
	self.AvailableTraitFrame:Hide();

	self:ResetAzeriteTextures();
end

function ExaminerAzeriteItemOverlayMixin:ResetAzeriteTextures()
	self:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD");
	local highlightTexture = self:GetHighlightTexture();
	highlightTexture:SetAllPoints(self);
end
