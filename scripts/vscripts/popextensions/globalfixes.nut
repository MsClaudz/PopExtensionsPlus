const SCOUT_MONEY_COLLECTION_RADIUS = 288
const HUNTSMAN_DAMAGE_FIX_MOD       = 1.263157

local GlobalFixesEntity = FindByName(null, "popext_globalfixes_ent")
if (GlobalFixesEntity == null) GlobalFixesEntity = SpawnEntityFromTable("info_teleport_destination", { targetname = "popext_globalfixes_ent" })

::GlobalFixes <- {
	InitWaveTable = {}
	TakeDamageTable = {

		function YERDisguiseFix(params) {
			local victim   = params.const_entity
			local attacker = params.inflictor

			if ( victim.IsPlayer() && params.damage_custom == TF_DMG_CUSTOM_BACKSTAB && attacker != null && !attacker.IsBotOfType(1337) ) {
				attacker.GetScriptScope().stabvictim <- victim
				EntFireByHandle(attacker, "RunScriptCode", "PopExtUtil.SilentDisguise(self, stabvictim)", -1, null, null)
			}
		}

		/*
		function LooseCannonFix(params) {
			local wep   = params.weapon
			local index = PopExtUtil.GetItemIndex(wep)
			if (index != 996 || params.damage_custom != TF_DMG_CUSTOM_CANNONBALL_PUSH) return

			params.damage *= wep.GetAttribute("damage bonus", 1.0)
		}
		*/

		// Quick hacky non-GetAttribute version
		function HuntsmanDamageBonusFix(params) {
			local wep       = params.weapon
			local classname = GetPropString(wep, "m_iClassname")
			if (classname != "tf_weapon_compound_bow") return

			if ((params.damage_custom == TF_DMG_CUSTOM_HEADSHOT && params.damage > 360.0) || params.damage > 120.0)
				params.damage *= HUNTSMAN_DAMAGE_FIX_MOD
		}
		/*
		function HuntsmanDamageBonusFix(params) {
			local wep       = params.weapon
			local classname = GetPropString(wep, "m_iClassname")
			if (classname != "tf_weapon_compound_bow") return

			local mod = wep.GetAttribute("damage bonus", 1.0)
			if (mod != 1.0)
				params.damage *= HUNTSMAN_DAMAGE_FIX_MOD
		}
		*/

		function HolidayPunchFix(params) {
			local wep   = params.weapon
			local index = PopExtUtil.GetItemIndex(wep)
			if (index != 656 || !(params.damage_type & DMG_ACID)) return

			local victim = params.const_entity
			if (victim != null && victim.IsBotOfType(1337)) {
				victim.Taunt(TAUNT_MISC_ITEM, 92)

				local tfclass      = victim.GetPlayerClass()
				local class_string = PopExtUtil.Classes[tfclass]
				local botmodel     = format("models/bots/%s/bot_%s.mdl", class_string, class_string)

				victim.SetCustomModelWithClassAnimations(format("models/player/%s.mdl", class_string))

				victim.ValidateScriptScope()
				local scope = victim.GetScriptScope()

				local wearable = CreateByClassname("tf_wearable")

				SetPropString(wearable, "m_iName", "__bot_bonemerge_model")
				SetPropInt(wearable, "m_nModelIndex", PrecacheModel(botmodel))
				SetPropBool(wearable, "m_bValidatedAttachedEntity", true)
				SetPropBool(wearable, STRING_NETPROP_ITEMDEF, true)
				SetPropEntity(wearable, "m_hOwnerEntity", victim) // TODO: is this needed? we set owner below

				wearable.SetTeam(victim.GetTeam())
				wearable.SetOwner(victim)

				wearable.DispatchSpawn()

				EntFireByHandle(wearable, "SetParent", "!activator", -1, victim, victim)
				SetPropInt(wearable, "m_fEffects", 129)

				SetPropInt(victim, "m_nRenderMode", 1)
				SetPropInt(victim, "m_clrRender", 0)

				scope.Think <-  function() {
					if (Time() > victim.GetTauntRemoveTime()) {
						if (wearable != null) wearable.Destroy()

						SetPropInt(self, "m_clrRender", 0xFFFFFF)
						SetPropInt(self, "m_nRenderMode", 0)
						self.SetCustomModelWithClassAnimations(botmodel)

						SetPropString(self, "m_iszScriptThinkFunction", "")
					}

					return -1
				}
				AddThinkToEnt(victim, "Think")
			}
		}
	}

	DisconnectTable = {}

	ThinkTable = {
		function DragonsFuryFix() {
			for (local fireball; fireball = FindByClassname(fireball, "tf_projectile_balloffire");)
				fireball.RemoveFlag(FL_GRENADE)
		}
	}

	DeathHookTable = {
		function NoCreditVelocity(params) {

			local player = GetPlayerFromUserID(params.userid)
			if (!player.IsBotOfType(1337)) return

			for (local money; money = FindByClassname(money, "item_currencypack*");)
				money.SetAbsVelocity(Vector())
		}
	}
	SpawnHookTable = {

		function ScoutBetterMoneyCollection(params) {

			local player = GetPlayerFromUserID(params.userid)
			if (player.IsBotOfType(1337) || player.GetPlayerClass() != TF_CLASS_SCOUT) return

			function MoneyThink() {
				if (player.GetPlayerClass() != TF_CLASS_SCOUT) {
					delete player.GetScriptScope().PlayerThinkTable.MoneyThink
					return
				}
				for (local money; money = FindByClassnameWithin(money, "item_currencypack*", player.GetOrigin(), SCOUT_MONEY_COLLECTION_RADIUS);)
					money.SetOrigin(player.GetOrigin())
			}
			player.GetScriptScope().PlayerThinkTable.MoneyThink <- MoneyThink
		}

		function RemoveYERAttribute(params) {

			local player = GetPlayerFromUserID(params.userid)
			if (player.IsBotOfType(1337)) return

			local wep   = PopExtUtil.GetItemInSlot(player, SLOT_MELEE)
			local index = PopExtUtil.GetItemIndex(wep)

			if (index == ITEMINDEX_YOUR_ETERNAL_REWARD || index == ITEMINDEX_THE_WANGA_PRICK)
				wep.RemoveAttribute("disguise on backstab")
		}

		function HoldFireUntilFullReloadFix(params) {
			
			local player = GetPlayerFromUserID(params.userid)

			// printl(player.HasBotAttribute(HOLD_FIRE_UNTIL_FULL_RELOAD))
			
			// if (!player.IsBotOfType(1337) || !player.HasBotAttribute(HOLD_FIRE_UNTIL_FULL_RELOAD)) return
			if (!player.IsBotOfType(1337)) return

			local scope = player.GetScriptScope()
			scope.holdingfire <- false
			function HoldFireThink() {
				
				if (!player.HasBotAttribute(HOLD_FIRE_UNTIL_FULL_RELOAD)) return

				local activegun = player.GetActiveWeapon()

				if (activegun.Clip1() == 0)
				{
					// SetPropFloat(activegun, "m_flNextPrimaryAttack", PopExtUtil.Global_Time + FLT_MAX)
					// activegun.AddAttribute("auto fires when full", 1, -1)
					// activegun.AddAttribute("auto fires full clip", 1, -1)
					activegun.AddAttribute("no_attack" 1, 1, -1)
					activegun.ReapplyProvision()
					// printl(activegun.Clip1())
					scope.holdingfire = true
					return -1 
				}

				else if (activegun.Clip1() == activegun.GetMaxClip1() && scope.holdingfire)
				{
					// SetPropFloat(activegun, "m_flNextPrimaryAttack", PopExtUtil.Global_Time)
					activegun.RemoveAttribute("no_attack" 1)
					activegun.ReapplyProvision()
					scope.holdingfire = false
					return -1
				}
			}

			player.GetScriptScope().PlayerThinkTable.HoldFireThink <- HoldFireThink
		}
	}

	Events = {

		function OnScriptHook_OnTakeDamage(params) { foreach(_, func in GlobalFixes.TakeDamageTable) func(params) }
		// function OnGameEvent_player_spawn(params) { foreach (_, func in GlobalFixes.SpawnHookTable) func(params) }
		function OnGameEvent_player_death(params) { foreach(_, func in GlobalFixes.DeathHookTable) func(params) }
		function OnGameEvent_player_disconnect(params) { foreach(_, func in GlobalFixes.DisconnectTable) func(params) }

		function OnGameEvent_post_inventory_application(params) {
			local player = GetPlayerFromUserID(params.userid)

			player.ValidateScriptScope()
			local scope = player.GetScriptScope()

			if (!("PlayerThinkTable" in scope)) scope.PlayerThinkTable <- {}

			function PlayerThinks() {
				foreach(_, func in scope.PlayerThinkTable) func()
				return -1
			}
			scope.PlayerThinks <- PlayerThinks
			AddThinkToEnt(player, "PlayerThinks")

			foreach(_, func in GlobalFixes.SpawnHookTable) func(params)
		}
		// Hook all wave inits to reset parsing error counter.

		function OnGameEvent_recalculate_holidays(params) {
			if (GetRoundState() != 3) return

			foreach(_, func in GlobalFixes.InitWaveTable) func(params)
		}

		function GameEvent_mvm_wave_complete(params) { delete GlobalFixes }
	}
}
__CollectGameEventCallbacks(GlobalFixes.Events)

function GlobalFixesThink() {
	foreach(_, func in GlobalFixes.ThinkTable) func()
	return -1
}

GlobalFixesEntity.ValidateScriptScope()
GlobalFixesEntity.GetScriptScope().GlobalFixesThink <- GlobalFixesThink
AddThinkToEnt(GlobalFixesEntity, "GlobalFixesThink")
