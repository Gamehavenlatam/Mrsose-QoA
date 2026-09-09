-- ------------------------------------------------------------------------------ --
--  Mrsose QoA - external, update-proof fixes for the TSM 3.3.5a backport         --
--                                                                                  --
--  This addon does NOT modify any TSM files. Instead it reaches into TSM's own    --
--  exposed tables (_G.TSMAddon) at runtime and patches the specific functions     --
--  that are buggy, plus does an independent mailbox cleanup pass. Because it      --
--  only touches TSM's live tables (not its files on disk), these fixes keep       --
--  working even after TSM updates overwrite its own Lua files - as long as the    --
--  function/module names below don't change.                                     --
-- ------------------------------------------------------------------------------ --

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Simple delayed-call helper (this client doesn't have C_Timer.After)
local function After(seconds, func)
	local ticker = CreateFrame("Frame")
	local elapsed = 0
	ticker:SetScript("OnUpdate", function(self, delta)
		elapsed = elapsed + delta
		if elapsed >= seconds then
			self:SetScript("OnUpdate", nil)
			func()
		end
	end)
end



-- TSM's module tables are "sealed" (they assert on being given brand-new keys
-- to catch typos), so we can't stash our own __patched flags on them. Track
-- what we've already patched in our own local table instead.
local patched = {}

-- ============================================================================
-- Fix 1: Item.IsClassDisenchantable used a broken Enum.ItemClass table
-- Real WoW classId values: Armor=4, Weapon=2, Profession=19
-- ============================================================================
local function ApplyItemClassFix()
	if patched.itemClass then
		return
	end
	local ok, Item = pcall(function() return _G.TSMAddon.LibTSMWoW:Include("API.Item") end)
	if not ok or not Item then
		return
	end
	Item.IsClassDisenchantable = function(classId)
		return classId == 4 or classId == 2 or classId == 19
	end
	patched.itemClass = true
end



-- ============================================================================
-- Fix 2: on login/reload, TSM's BagTracking often only sees bag 0 (backpack)
-- until something else forces a rescan. Force one ourselves after entering
-- the world, giving item data (classId/quality/itemLevel) a few seconds to
-- load first.
-- ============================================================================
local function ApplyBagRescanFix()
	local ok, BagTracking = pcall(function() return _G.TSMAddon.LibTSMService:Include("Inventory.BagTracking") end)
	if ok and BagTracking and BagTracking.RescanAllBags then
		BagTracking.RescanAllBags()
	end
end



-- ============================================================================
-- Fix 3: ChatThrottleLib:SendAddonMessage throws a hard Lua error when
-- another addon (e.g. LibGroupTalents) sends an oversized addon message,
-- instead of just failing to send it. Wrap it so it silently drops the
-- oversized message instead of erroring. This patches whichever addon's
-- copy of ChatThrottleLib became the shared _G instance, not just TSM's.
-- ============================================================================
local function ApplyChatThrottleFix()
	if patched.chatThrottle or not _G.ChatThrottleLib then
		return
	end
	local orig = _G.ChatThrottleLib.SendAddonMessage
	if not orig then
		return
	end
	_G.ChatThrottleLib.SendAddonMessage = function(self, prio, prefix, text, chattype, target, ...)
		if prefix and text and (#prefix + 1 + #text) > 254 then
			-- silently drop instead of erroring
			return
		end
		return orig(self, prio, prefix, text, chattype, target, ...)
	end
	patched.chatThrottle = true
end



-- ============================================================================
-- Fix 4: TSM Mailing's "Open Mail" doesn't reliably delete emptied mail
-- (relies on a textCreated flag that's inconsistent on some private servers).
-- Rather than touching TSM_Mailing's internal (unreachable) private
-- functions, we wrap the public entry point Open.StartOpening() to run our
-- own independent sweep of the mailbox afterwards, using only the plain
-- Blizzard mail API - so it works regardless of what TSM's internals do.
-- ============================================================================
local function SweepEmptyMail()
	local numItems = GetInboxNumItems()
	for i = numItems, 1, -1 do
		local _, _, _, _, money, _, _, hasItem = GetInboxHeaderInfo(i)
		local hasAnyItem = hasItem and true or false
		if not hasAnyItem then
			-- double check across all attachment slots in case hasItem is unreliable
			for attachIndex = 1, ATTACHMENTS_MAX_RECEIVE or 12 do
				if GetInboxItem(i, attachIndex) then
					hasAnyItem = true
					break
				end
			end
		end
		if not hasAnyItem and (not money or money == 0) then
			DeleteInboxItem(i)
		end
	end
end

local function ApplyMailingFix()
	if patched.mailing then
		return
	end
	local ok, Open = pcall(function() return _G.TSMAddon.Mailing.Open end)
	if not ok or not Open then
		return
	end
	local origStartOpening = Open.StartOpening
	if not origStartOpening then
		return
	end
	Open.StartOpening = function(callback, autoRefresh, keepMoney, filterText, filterType)
		local wrappedCallback = function(...)
			if callback then
				callback(...)
			end
			-- give the client a moment to finish processing the last loot/delete
			-- before we do our own independent empty-mail sweep
			After(1.5, SweepEmptyMail)
		end
		return origStartOpening(wrappedCallback, autoRefresh, keepMoney, filterText, filterType)
	end
	patched.mailing = true
end



-- ============================================================================
-- Fix 5: with TSM Crafting handling profession windows, the native Blizzard
-- TradeSkillFrame may never get created. Other addons that assume it always
-- exists (e.g. AckisRecipeList's ElvUI_AddOnSkins skin module) then error
-- with "attempt to index global 'TradeSkillFrame' (a nil value)" when a
-- profession is opened. We can't patch those addons directly (not part of
-- TSM), so just make sure a harmless placeholder frame exists under that
-- name so indexing it doesn't throw - it won't restore their skinning, but
-- it stops the error.
-- ============================================================================
local function ApplyTradeSkillFrameGuard()
	if patched.tradeSkillFrameGuard or _G.TradeSkillFrame then
		return
	end
	local dummy = CreateFrame("Frame", "TradeSkillFrame", UIParent)
	-- Never let this placeholder actually become visible - some game/addon code
	-- may try to ShowUIPanel()/:Show() whatever is named "TradeSkillFrame" when a
	-- profession is opened, which would otherwise pop up an empty gray box now
	-- that the global isn't nil anymore.
	dummy:Hide()
	dummy.Show = function() end
	_G.TradeSkillFrame = dummy
	patched.tradeSkillFrameGuard = true
end



-- ============================================================================
-- Event handling
-- ============================================================================
frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" then
		if addonName == "TradeSkillMaster" then
			ApplyItemClassFix()
		elseif addonName == "TradeSkillMaster_Mailing" then
			ApplyMailingFix()
		end
		ApplyChatThrottleFix()
		ApplyTradeSkillFrameGuard()
	elseif event == "PLAYER_ENTERING_WORLD" then
		ApplyItemClassFix()
		ApplyChatThrottleFix()
		ApplyMailingFix()
		ApplyTradeSkillFrameGuard()
		-- give item/profession data time to load before rescanning bags
		After(5, ApplyBagRescanFix)
	end
end)
