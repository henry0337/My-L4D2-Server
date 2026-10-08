::Shared.Players <-
{
    IsValid = function (player)
    {
        return player != null && player.IsPlayerEntityValid();
    },

    GetByUserId = function (userId)
    {
        if (userId == null || userId == 0) return null;

        local player = ::VSLib.Utils.GetPlayerFromUserID(userId);
        return ::Shared.Players.IsValid(player) ? player : null;
    },

    GetHeldItem = function (player, slot)
    {
        if (!::Shared.Players.IsValid(player)) return null;

        local items = player.GetHeldItems();
        if (items == null || !(slot in items)) return null;

        local item = items[slot];
        return (item != null && item.IsEntityValid()) ? item : null;
    },

    GetPrimary = function (player)
    {
        return ::Shared.Players.GetHeldItem(player, SLOT_PRIMARY);
    },

    GetHeldItemOfClass = function (player, slot, className)
    {
        local item = ::Shared.Players.GetHeldItem(player, slot);
        return (item != null && item.GetClassname() == className) ? item : null;
    },

    IsSelfRevived = function (player)
    {
        local owner = player.GetNetPropEntity(NETPROP_REVIVE_OWNER);
        return owner != null && owner.IsEntityValid() && owner.GetIndex() == player.GetIndex();
    },

    IsRevivedByOther = function (player)
    {
        local owner = player.GetNetPropEntity(NETPROP_REVIVE_OWNER);
        return owner != null && owner.IsEntityValid() && owner.GetIndex() != player.GetIndex();
    },

    GetLanguage = function (player)
    {
        return player.GetClientConvarValue("cl_language");
    }
};
