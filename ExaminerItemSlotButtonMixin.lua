local LibItemUpgradeInfo = LibStub("LibItemUpgradeInfo-1.0");

ExaminerItemSlotButtonMixin = {}

function ExaminerItemSlotButtonMixin:OnLoad()
    self.slotName = strsub(self:GetName(), 9);
	local id, texture = GetInventorySlotInfo(self.slotName);
	self:SetID(id);
	self.icon:SetTexture(texture);
	self.backgroundTextureName = texture;
end

function ExaminerItemSlotButtonMixin:OnClick(button)
	if (CursorHasItem()) then
		self:OnDrag();
		return;
	end

	if (not self.link) then
		return;
	end

	local editBox = ChatEdit_GetActiveWindow();
	if (IsModifiedClick("DRESSUP")) then
		DressUpItemLink(self.link);
	elseif (IsModifiedClick("CHATLINK") and editBox and editBox:IsVisible()) then
		ChatEdit_InsertLink(self.link);
	else
		self:OnDrag();
	end
end

function ExaminerItemSlotButtonMixin:OnUpdate()
    CursorOnUpdate(self);
end

function ExaminerItemSlotButtonMixin:OnEnter()
    local data = Examiner.data;

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

    if (data and data.unit and GameTooltip:SetInventoryItem(data.unit, self:GetID())) then
	    CursorUpdate(self);
        return;
	end

    if (self.link and GameTooltip:SetHyperlink(self.link)) then
	    CursorUpdate(self);
        return;
    end

    GameTooltip:SetText(_G[strupper(self.slotName)]);
	CursorUpdate(self);
end

function ExaminerItemSlotButtonMixin:OnLeave()
    GameTooltip:Hide();
    ResetCursor();
end

function ExaminerItemSlotButtonMixin:OnDrag()
    local data = Examiner.data;

	if (data and data.isSelf) then
		PickupInventoryItem(self:GetID());
	end
end

function ExaminerItemSlotButtonMixin:Update()
    local data = Examiner.data;
    if (not data or not data.unit) then
        return;
    end

    local unit = data.unit;
    local id = self:GetID();

    local textureName = GetInventoryItemTexture(unit, id);
    if (textureName) then
        SetItemButtonTexture(self, textureName);
        SetItemButtonCount(self, GetInventoryItemCount(unit, id));
        self.hasItem = true;

        local quality = GetInventoryItemQuality(unit, id);
        SetItemButtonQuality(self, quality, GetInventoryItemID(unit, id));

        self.link = GetInventoryItemLink(unit, id);
        self.level:SetText(LibItemUpgradeInfo:GetUpgradedItemLevel(self.link));
    else
        SetItemButtonTexture(self, self.backgroundTextureName);
        SetItemButtonCount(self, 0);
        self.IconBorder:Hide();
        self.hasItem = nil;
        self.link = nil;
        self.level:SetText("");
    end
end
