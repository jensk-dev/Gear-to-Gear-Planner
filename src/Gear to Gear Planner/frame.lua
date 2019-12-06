local ADDON_NAME, ADDON_TABLE = ...;

GTGP_CLOSE_BUTTON:SetScript('OnClick', function(self, button, down)
    if (button == "LeftButton") then
        GTGP_FRAME:Hide();
        GTGP_URL:SetText('');
        collectgarbage();
    end
end)

GTGP_URL:SetScript("OnEscapePressed", function(self)
    self:GetParent():Hide();
    GTGP_URL:SetText('');
    collectgarbage();
end)