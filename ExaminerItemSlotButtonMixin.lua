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

    if (not Examiner.data or not self.link) then
        return;
    end

	if (IsModifiedClick("EXPANDITEM")) then
        if (Examiner.data.isSelf) then
            local itemLocation = ItemLocation:CreateFromEquipmentSlot(self:GetID());
            if C_Item.DoesItemExist(itemLocation) and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation) then
                OpenAzeriteEmpoweredItemUIFromItemLocation(itemLocation);
                return;
            end
        end
    
		if C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(self.link) then
			local azeritePowerIDs = C_PaperDollInfo.GetInspectAzeriteItemEmpoweredChoices(Examiner.data.unit, self:GetID());
			OpenAzeriteEmpoweredItemUIFromLink(self.link, Examiner.data.classID, azeritePowerIDs);
			return;
		end

        SocketInventoryItem(self:GetID());
		return;
	end

	if (HandleModifiedItemClick(self.link)) then
		return;
	end

	self:OnDrag();
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

    local quality = GetInventoryItemQuality(unit, id);
    SetItemButtonQuality(self, quality, GetInventoryItemID(unit, id), self.HasPaperDollAzeriteItemOverlay);

    if self.HasPaperDollAzeriteItemOverlay then
        self:SetAzeriteItem(self.hasItem and ItemLocation:CreateFromEquipmentSlot(self:GetID()) or nil);
    end

	if ( GameTooltip:IsOwned(self) ) then
		GameTooltip:Hide();
	end
end
