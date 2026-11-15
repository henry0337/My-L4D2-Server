IncludeScript("src/Shared/shared");
IncludeScript("src/WeaponCustomizer/guard");

const SA_PILE_CLASS = "weapon_ammo_spawn";
const SA_HINT_ICON = "icon_interact";
const SA_HINT_CAPTION = "#L4D_Instructor_explain_ammo_resupply_get";
const SA_HINT_RANGE = 360;
const SA_DENIED_ICON = "icon_tip";
const SA_DENIED_CAPTION = "#L4D2_Instructor_explain_ammo_pile_failure";
const SA_DENIED_SECONDS = 4.0;
const SA_PICKUP_EVENT = "ammo_pickup";
const SA_PICKUP_SOUND = "BaseCombatCharacter.AmmoPickup";
const SA_TICK_SECONDS = 0.1;
const SA_BUMP_CHECK_SECONDS = 0.03;
const SA_BLOCK_SECONDS = 0.4;
const SA_EMPTY_BLOCK_SECONDS = 0.3;
const SA_RELOAD_MARGIN_SECONDS = 0.5;
const SA_NATIVE_MIN_SECONDS = 0.5;
const SA_NETPROP_NEXT_ATTACK = "m_flNextPrimaryAttack";

if (!("SpecialAmmo" in getroottable()))
{
    PrecacheSound(SA_PICKUP_SOUND);

    ::SpecialAmmo <-
    {
        Create = function (config)
        {
            local guardEmpty = ("guardEmpty" in config) ? config.guardEmpty : false;
            local animationSeconds = ("animationSeconds" in config) ? config.animationSeconds : null;
            local verbose = ("verbose" in config) ? config.verbose : false;
            local clipSize = config.clip;
            local totalMax = clipSize + config.reserveMax;
            local prefix = "SA_" + config.name;

            local self =
            {
                verbose = verbose,
                hints = {},
                pileUsed = {},
                deniedAt = {},
                guard = {},
                blocked = {},
                reloadUntil = {}
            };

            self.Log <- function (message)
            {
                if (!self.verbose) return;

                ::Shared.Chat.ChatBroadcast("[" + config.name + "] " + message);
            };

            self.FindHeld <- function (player)
            {
                local weapon = ::Shared.Players.GetPrimary(player);
                if (weapon == null || weapon.GetClassname() != config.className) return null;

                return weapon;
            };

            self.IsFull <- function (weapon)
            {
                return weapon.GetClip() + weapon.GetAmmo() >= totalMax;
            };

            self.ApplyConvar <- function ()
            {
                ::WeaponCustomizer.ApplyConvar(config.convar, config.reserveMax, config.defaultReserveMax);

                self.Log(config.convar + "=" + Convars.GetFloat(config.convar)
                    + " mode=" + Director.GetGameMode() + " disabled=" + ::WeaponCustomizer.IsDisabled());
            };

            self.Reset <- function ()
            {
                self.hints.clear();
                self.pileUsed.clear();
                self.deniedAt.clear();
                self.guard.clear();
                self.blocked.clear();
                self.reloadUntil.clear();
                self.ApplyConvar();
            };

            self.ReloadSeconds <- function (weapon)
            {
                if (animationSeconds == null) return config.reloadSeconds;

                local measured = weapon.GetNetPropFloat(SA_NETPROP_NEXT_ATTACK) - Time();
                return (measured > SA_NATIVE_MIN_SECONDS) ? measured : animationSeconds;
            };

            self.StartReload <- function (player, weapon)
            {
                if (weapon.GetClip() >= clipSize || weapon.GetAmmo() <= 0) return;

                local seconds = self.ReloadSeconds(weapon);
                self.reloadUntil[player.GetUserID()] <- Time() + seconds + SA_RELOAD_MARGIN_SECONDS;

                ::VSLib.Timers.AddTimerByName(
                    prefix + "_Reload_" + player.GetUserID(),
                    seconds,
                    false,
                    self.FinishReload,
                    { player = player, weaponIndex = weapon.GetIndex() }
                );

                self.Log("reload started, fill in " + seconds + "s, clip=" + weapon.GetClip() + " reserve=" + weapon.GetAmmo());
            };

            self.BeginEmptyReload <- function (player, weapon)
            {
                weapon.SetNetPropFloat(SA_NETPROP_NEXT_ATTACK, Time());
                weapon.Reload();

                self.StartReload(player, weapon);
            };

            self.FinishReload <- function (params)
            {
                local player = params.player;
                if (!::Shared.Players.IsValid(player)) return;

                local weapon = self.FindHeld(player);
                if (weapon == null || weapon.GetIndex() != params.weaponIndex) return;

                local needed = clipSize - weapon.GetClip();
                local reserve = weapon.GetAmmo();
                if (needed <= 0 || reserve <= 0) return;

                local taken = (reserve < needed) ? reserve : needed;
                weapon.SetClip(weapon.GetClip() + taken);
                weapon.SetAmmo(reserve - taken);

                self.Log("reloaded: clip=" + weapon.GetClip() + " reserve=" + weapon.GetAmmo());
            };

            self.OnReload <- function (player, manual, params)
            {
                if (::WeaponCustomizer.IsDisabled()) return;
                if (!::Shared.Players.IsValid(player) || player.GetTeam() != SURVIVORS) return;

                local weapon = self.FindHeld(player);
                if (weapon == null) return;

                local index = weapon.GetIndex();
                if ((index in self.guard) && self.guard[index] == "bumped")
                {
                    delete self.guard[index];
                    weapon.SetAmmo(weapon.GetAmmo() - 1);
                    self.Log("reload during guard: phantom bullet removed, reserve=" + weapon.GetAmmo());
                }

                local userId = player.GetUserID();
                if ((userId in self.reloadUntil) && Time() < self.reloadUntil[userId]) return;

                self.StartReload(player, weapon);
            };

            self.Finalize <- function (player, weapon)
            {
                local index = weapon.GetIndex();
                if (index in self.guard) delete self.guard[index];

                weapon.SetNetPropFloat(SA_NETPROP_NEXT_ATTACK, Time() + SA_BLOCK_SECONDS);

                if (weapon.GetClip() == 1)
                {
                    weapon.SetClip(0);
                }

                self.Log("final shot done, clip=" + weapon.GetClip() + " reserve=" + weapon.GetAmmo());
            };

            self.CheckBump <- function (params)
            {
                local weapon = params.weapon;
                if (!weapon.IsEntityValid()) return;

                local index = weapon.GetIndex();
                if (!(index in self.guard) || self.guard[index] != "bumped") return;

                if (weapon.GetClip() <= 1) self.Finalize(params.player, weapon);
            };

            self.HandleEmpty <- function (player)
            {
                local weapon = self.FindHeld(player);
                if (weapon == null) return;

                local index = weapon.GetIndex();

                if ((index in self.guard) && self.guard[index] == "bumped" && weapon.GetClip() <= 1)
                {
                    self.Finalize(player, weapon);
                }

                if (weapon.GetClip() > 0)
                {
                    if (index in self.blocked) delete self.blocked[index];
                    return;
                }

                local now = Time();
                local userId = player.GetUserID();
                local reloading = (userId in self.reloadUntil) && now < self.reloadUntil[userId];

                if (!reloading && weapon.GetAmmo() > 0)
                {
                    self.BeginEmptyReload(player, weapon);
                    self.Log("auto reload at empty clip, reserve=" + weapon.GetAmmo());
                }

                if (weapon.GetNetPropFloat(SA_NETPROP_NEXT_ATTACK) < now + SA_EMPTY_BLOCK_SECONDS)
                {
                    weapon.SetNetPropFloat(SA_NETPROP_NEXT_ATTACK, now + SA_EMPTY_BLOCK_SECONDS);
                }

                if (!(index in self.blocked))
                {
                    self.blocked[index] <- true;
                    self.Log("empty clip, reserve=" + weapon.GetAmmo());
                }
            };

            self.OnFire <- function (player, className, params)
            {
                if (className != config.className) return;
                if (!guardEmpty || ::WeaponCustomizer.IsDisabled()) return;
                if (!::Shared.Players.IsValid(player)) return;

                local weapon = self.FindHeld(player);
                if (weapon == null) return;

                local clip = weapon.GetClip();
                local index = weapon.GetIndex();
                local state = (index in self.guard) ? self.guard[index] : null;

                if (state == "bumped")
                {
                    if (clip <= 1) self.Finalize(player, weapon);
                    return;
                }

                if (state == null && clip == 1)
                {
                    weapon.SetClip(2);
                    weapon.SetNetPropFloat(SA_NETPROP_NEXT_ATTACK, Time() + SA_BLOCK_SECONDS);
                    self.guard[index] <- "bumped";
                    ::VSLib.Timers.AddTimer(SA_BUMP_CHECK_SECONDS, false, self.CheckBump, { player = player, weapon = weapon });

                    self.Log("last bullet guard: clip bumped to 2");
                }
            };

            self.OnAmmoCantUse <- function (player, params)
            {
                if (::WeaponCustomizer.IsDisabled()) return;
                if (!::Shared.Players.IsValid(player) || player.GetTeam() != SURVIVORS) return;

                local weapon = self.FindHeld(player);
                if (weapon == null || self.IsFull(weapon)) return;

                local userId = player.GetUserID();

                if (userId in self.pileUsed)
                {
                    self.ShowDenied(player);
                    return;
                }

                weapon.SetAmmo(totalMax - weapon.GetClip());
                self.pileUsed[userId] <- true;

                self.Log("pile refill: clip=" + weapon.GetClip() + " reserve=" + weapon.GetAmmo());

                self.HideHint(userId);
                self.ShowPickupPanel(player);
            };

            self.ShowPickupPanel <- function (player)
            {
                local proxy = ::VSLib.Utils.CreateEntity("info_game_event_proxy", player.GetLocation(), QAngle(0, 0, 0),
                {
                    event_name = SA_PICKUP_EVENT,
                    range = "0"
                });
                if (proxy == null) return;

                proxy.Input("GenerateGameEvent", "", 0, player);
                proxy.Input("Kill", "", 0.1);

                player.PlaySound(SA_PICKUP_SOUND);
            };

            self.ShowDenied <- function (player)
            {
                local userId = player.GetUserID();
                local now = Time();

                if ((userId in self.deniedAt) && now - self.deniedAt[userId] < SA_DENIED_SECONDS) return;

                self.deniedAt[userId] <- now;
                player.ShowHint(SA_DENIED_CAPTION, SA_DENIED_SECONDS, SA_DENIED_ICON);
            };

            self.FindNearestPile <- function (player)
            {
                local origin = player.GetLocation();
                local nearest = null;
                local nearestDistance = SA_HINT_RANGE + 1.0;
                local pile = null;

                while ((pile = Entities.FindByClassnameWithin(pile, SA_PILE_CLASS, origin, SA_HINT_RANGE)) != null)
                {
                    local distance = (pile.GetOrigin() - origin).Length();
                    if (distance < nearestDistance)
                    {
                        nearest = pile;
                        nearestDistance = distance;
                    }
                }

                return nearest;
            };

            self.ShowHint <- function (player, pile)
            {
                if (pile.GetName() == "")
                {
                    pile.__KeyValueFromString("targetname", "vslib_sa_pile_" + pile.GetEntityIndex());
                }

                local hint = ::VSLib.Utils.CreateEntity("env_instructor_hint", pile.GetOrigin(), QAngle(0, 0, 0),
                {
                    hint_allow_nodraw_target = "1",
                    hint_alphaoption = "0",
                    hint_auto_start = "0",
                    hint_binding = "",
                    hint_caption = SA_HINT_CAPTION,
                    hint_color = "255 255 255",
                    hint_forcecaption = "0",
                    hint_icon_offscreen = SA_HINT_ICON,
                    hint_icon_offset = "8",
                    hint_icon_onscreen = SA_HINT_ICON,
                    hint_instance_type = "2",
                    hint_nooffscreen = "0",
                    hint_pulseoption = "0",
                    hint_range = "" + SA_HINT_RANGE,
                    hint_shakeoption = "0",
                    hint_static = "0",
                    hint_target = pile.GetName(),
                    hint_timeout = "0",
                    targetname = "vslib_sa_hint_" + UniqueString()
                });
                if (hint == null) return;

                hint.Input("ShowHint", "", 0, player);
                self.hints[player.GetUserID()] <- { hint = hint, pileIndex = pile.GetEntityIndex() };
            };

            self.HideHint <- function (userId)
            {
                if (!(userId in self.hints)) return;

                local entry = self.hints[userId];
                delete self.hints[userId];

                if (!entry.hint.IsEntityValid()) return;

                entry.hint.Input("EndHint");
                entry.hint.Input("Kill", "", 0.1);
            };

            self.Tick <- function (params)
            {
                local seen = {};

                if (!::WeaponCustomizer.IsDisabled())
                {
                    foreach (player in ::VSLib.EasyLogic.Players.AllSurvivors())
                    {
                        if (!::Shared.Players.IsValid(player)) continue;
                        if (guardEmpty) self.HandleEmpty(player);
                        if (player.IsBot()) continue;

                        local userId = player.GetUserID();
                        local weapon = self.FindHeld(player);
                        if (weapon == null || !player.IsAlive() || (userId in self.pileUsed) || self.IsFull(weapon)) continue;

                        local pile = self.FindNearestPile(player);
                        if (pile == null) continue;

                        seen[userId] <- true;

                        local current = (userId in self.hints) ? self.hints[userId] : null;
                        if (current != null && current.pileIndex == pile.GetEntityIndex()) continue;

                        self.HideHint(userId);
                        self.ShowHint(player, pile);
                    }
                }

                foreach (userId, entry in clone self.hints)
                {
                    if (!(userId in seen))
                    {
                        self.HideHint(userId);
                    }
                }
            };

            ::VSLib.EasyLogic.Notifications.OnWeaponFire[prefix] <- function (player, className, params)
            {
                self.OnFire(player, className, params);
            };

            ::VSLib.EasyLogic.Notifications.OnWeaponReload[prefix] <- function (player, manual, params)
            {
                self.OnReload(player, manual, params);
            };

            ::VSLib.EasyLogic.Notifications.OnAmmoCantUse[prefix] <- function (player, params)
            {
                self.OnAmmoCantUse(player, params);
            };

            ::VSLib.EasyLogic.Notifications.OnRoundStart[prefix] <- function ()
            {
                self.Reset();
            };

            ::VSLib.Timers.AddTimerByName(prefix + "_Tick", SA_TICK_SECONDS, true, self.Tick);

            self.ApplyConvar();

            return self;
        }
    };
}
