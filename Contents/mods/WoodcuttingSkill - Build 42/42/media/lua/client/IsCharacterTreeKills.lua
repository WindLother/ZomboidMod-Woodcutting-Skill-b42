

if getActivatedMods():contains("KillCount")
or getActivatedMods():contains("KillCountRU")
or getActivatedMods():contains("KillCountFR")
or getActivatedMods():contains("KillCountES") then
    
    require "IsCharacterKills"
    ISCharacterKills = ISCharacterKills or {}

    -- copy pasta of Kill Count's render function, with added Trees and Bushes kill count.
    function ISCharacterKills:render()
        if not self.char:getModData() then self:clearStencilRect(); return end
        local killCountModData = self.char:getModData().KillCount
        if not killCountModData or not killCountModData.WeaponCategory then self:clearStencilRect(); return end
        ------------------------------------
        


        local textX = self.categoryXOffset
        local fontHeight = getTextManager():getFontHeight(UIFont.Small)
        local textY = fontHeight
        local maxTextWidth = 0
        local iterCategories = 0

        
        self:drawText(getText("IGUI_char_Zombies_Killed").." :", textX, textY, 1, 1, 1, 1, UIFont.Small)
        textY = textY + fontHeight

        for category,struct in pairs(killCountModData.WeaponCategory) do
            iterCategories = iterCategories + 1;
            local displayCategoryWeapons = self:displayCategoryWeapons(iterCategories)
            local expandChar = "+ "
            local xButtonOffset = 7
            if displayCategoryWeapons then expandChar = "- "; xButtonOffset = 5 end
            local catText = expandChar .. KillCountWeaponType.getWpnCategoryDisplayName(category) .. " " .. struct.count
            local button = self:getCategoryButton(iterCategories);--potentially instanciate
            button:setX(textX-xButtonOffset);
            button:setY(textY);
            button:setWidthToTitle();
            button:setTitle(catText)
            button.enable = true;
            button:setVisible(true);
            local textWidth = getTextManager():MeasureStringX(UIFont.Small, catText);
            if textWidth > maxTextWidth then maxTextWidth = textWidth end
            textY = textY + fontHeight
            if displayCategoryWeapons then--todo use buttons for categories
                for weaponType,count in pairs(struct.WeaponType) do
                    local wpnText = "-  ".. KillCountWeaponType.getWpnTypeDisplayName(weaponType) .. " " .. count
                    self:drawText(wpnText, textX, textY, 0.7, 0.7, 0.7, 1, UIFont.Small)
                    local wpnWidth = getTextManager():MeasureStringX(UIFont.Small, wpnText);
                    if wpnWidth > maxTextWidth then maxTextWidth = wpnWidth end
                    textY = textY + fontHeight
                end
            end
        end
        
        if self.char:getModData().AKCModData then
            --add car kills
            if self.char:getModData().AKCModData.ck and self.char:getModData().AKCModData.ck > 0 then
                local catText = "- ".. KillCountWeaponType.getWpnCategoryDisplayName("Vehicles") .. " " .. self.char:getModData().AKCModData.ck;
                self:drawText(catText, textX, textY, 1, 1, 1, 1, UIFont.Small)
                local wpnWidth = getTextManager():MeasureStringX(UIFont.Small, catText);
                if wpnWidth > maxTextWidth then maxTextWidth = wpnWidth end
                textY = textY + fontHeight
            end

            --add fire kills
            if self.char:getModData().AKCModData.fk and self.char:getModData().AKCModData.fk > 0 then
                local catText = "- ".. KillCountWeaponType.getWpnCategoryDisplayName("Fire") .. " " .. self.char:getModData().AKCModData.fk;
                self:drawText(catText, textX, textY, 1, 1, 1, 1, UIFont.Small)
                local wpnWidth = getTextManager():MeasureStringX(UIFont.Small, catText);
                if wpnWidth > maxTextWidth then maxTextWidth = wpnWidth end
                textY = textY + fontHeight
            end

            --add explosives kills
            if self.char:getModData().AKCModData.ek and self.char:getModData().AKCModData.ek > 0 then
                local catText = "- ".. KillCountWeaponType.getWpnCategoryDisplayName("Explosives") .. " " .. self.char:getModData().AKCModData.ek;
                self:drawText(catText, textX, textY, 1, 1, 1, 1, UIFont.Small)
                local wpnWidth = getTextManager():MeasureStringX(UIFont.Small, catText);
                if wpnWidth > maxTextWidth then maxTextWidth = wpnWidth end
                textY = textY + fontHeight
            end

            
        end
        textY = textY + fontHeight--more satisfying with an empty line


        -- WOODCUTTING !
        if self.char:getModData().treekills and self.char:getModData().treekills > 0 or self.char:getModData().bushkills and self.char:getModData().bushkills > 0 then
            self:drawText(getText("IGUI_perks_Woodcutting").." :", textX, textY, 1, 1, 1, 1, UIFont.Small)
            textY = textY + fontHeight
        end
        -- trees
        if self.char:getModData().treekills and self.char:getModData().treekills > 0 then
            local catText = "- ".. getText("IGUI_trees") .. " " .. self.char:getModData().treekills;
            self:drawText(catText, textX, textY, 1, 1, 1, 1, UIFont.Small)
            local wpnWidth = getTextManager():MeasureStringX(UIFont.Small, catText);
            if wpnWidth > maxTextWidth then maxTextWidth = wpnWidth end
            textY = textY + fontHeight
        end
        -- bushes
        if self.char:getModData().bushkills and self.char:getModData().bushkills > 0 then
            local catText = "- ".. getText("IGUI_bushes") .. " " .. self.char:getModData().bushkills;
            self:drawText(catText, textX, textY, 1, 1, 1, 1, UIFont.Small)
            local wpnWidth = getTextManager():MeasureStringX(UIFont.Small, catText);
            if wpnWidth > maxTextWidth then maxTextWidth = wpnWidth end
            textY = textY + fontHeight
        end



        textY = textY + fontHeight--more satisfying with an empty line
    
        local widthRequired = textX * 2 + maxTextWidth
        if widthRequired > self:getWidth() then
            self:setWidthAndParentWidth(widthRequired);
        end
        local tabHeight = self.y
        local maxHeight = getCore():getScreenHeight() - tabHeight - 20
        if ISWindow and ISWindow.TitleBarHeight then maxHeight = maxHeight - ISWindow.TitleBarHeight end
        
        self:setHeightAndParentHeight(math.min(textY, maxHeight));
        self:setScrollHeight(textY)
        
        self:clearStencilRect()
    end

end