ADDON.name = "Butchering System"
ADDON.description = ""
ADDON.author = "KarmaLN"

ADDON.corpses = {
    ["models/antlion.mdl"] = {
        butcheringTime = 12,
        slicingSound = {
            "ambient/machines/slicer2.wav",
            "ambient/machines/slicer3.wav"
        },
        items = {
            ["cooking_raw_meat"] = 3,
        },
        tool = {"tool_knife"}
    },
    ["models/headcrabclassic.mdl"] = {
        butcheringTime = 5,
        slicingSound = {
            "ambient/machines/slicer2.wav",
            "ambient/machines/slicer3.wav"
        },
        items = {
            ["cooking_raw_meat"] = 1,
        }
    },
    ["models/headcrab.mdl"] = {
        butcheringTime = 5,
        slicingSound = {
            "ambient/machines/slicer2.wav",
            "ambient/machines/slicer3.wav"
        },
        items = {
            ["cooking_raw_meat"] = 1,
        }
    },
    ["models/headcrabblack.mdl"] = {
        butcheringTime = 5,
        slicingSound = {
            "ambient/machines/slicer2.wav",
            "ambient/machines/slicer3.wav"
        },
        items = {
            ["cooking_raw_meat"] = 1,
        }
    }
}

if SERVER then
    local cuttingTargets = {}

    local function releaseTarget(target)
        cuttingTargets[target] = nil

        if IsValid(target) then
            target:SetNWBool("cutting", false)
        end
    end

    function ADDON:PlayerDisconnected(client)
        for target, butcher in pairs(cuttingTargets) do
            if butcher == client then
                releaseTarget(target)
            end
        end
    end

    function ADDON:OnNPCKilled(npc, attacker, inflictor)
        if not IsValid(npc) then return end

        local corpseData = self.corpses[npc:GetModel()]
        if not corpseData then return end

        local ragdoll = ents.Create("prop_ragdoll")
        if not IsValid(ragdoll) then return end

        ragdoll:SetPos(npc:GetPos())
        ragdoll:SetAngles(npc:EyeAngles())
        ragdoll:SetModel(npc:GetModel())
        ragdoll:Spawn()
        ragdoll:SetSkin(npc:GetSkin())

        for i = 0, npc:GetNumBodyGroups() - 1 do
            ragdoll:SetBodygroup(i, npc:GetBodygroup(i))
        end

        ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        ragdoll:Activate()

        npc:Remove()

        timer.Simple(120, function()
            if IsValid(ragdoll) then
                ragdoll:Remove()
            end
        end)
    end

    function ADDON:KeyPress(client, key)
        if key ~= IN_USE then return end

        local character = client:GetCharacter()
        if not character or not client:Alive() then return end

        local trace = client:GetEyeTraceNoCursor()
        local target = trace.Entity

        if not IsValid(target) or not target:IsRagdoll() then return end
        if client:EyePos():DistToSqr(trace.HitPos) > 96 ^ 2 then return end

        local corpseData = self.corpses[target:GetModel()]
        if not corpseData then return end

        if target:GetNWBool("cutting", false) then return end
        if hook.Run("CanButchEntity", client, target) == false then return end
        if corpseData.tool and not character:HasItem(corpseData.tool[1]) then return end

        target:SetNWBool("cutting", true)
        cuttingTargets[target] = client

        local sounds = corpseData.slicingSound or {}

        local id = marauth.interaction:Begin(client, {
            duration = corpseData.butcheringTime or 2,
            label = "Butchering...",
            color = MARAUTH_COLOR_GRAY,
            cancelOnMovement = true,
            ctx = { target = target },

            onCheck = function(butcher, ctx)
                if not IsValid(ctx.target) or not butcher:Alive() then return false end
                if butcher:GetCharacter() ~= character then return false end
                if hook.Run("CanButchEntity", butcher, ctx.target) == false then return false end
                if corpseData.tool and not character:HasItem(corpseData.tool[1]) then return false end

                local aimed = butcher:GetEyeTraceNoCursor()

                return aimed.Entity == ctx.target
                    and butcher:EyePos():DistToSqr(aimed.HitPos) <= 96 ^ 2
            end,

            onComplete = function(butcher, ctx)
                releaseTarget(ctx.target)
                if not IsValid(ctx.target) then return end

                local items = ctx.target.butcheringRemaining or corpseData.items or {}
                local remaining = {}

                for itemID, amount in pairs(items) do
                    local success, _, code = butcher:GiveItem(itemID, amount)

                    if not success then
                        remaining[itemID] = amount

                        butcher:Notify(
                            "Could not receive " .. itemID .. ": " .. tostring(code),
                            MARAUTH_TYPE_ALERT
                        )
                    end
                end

                if next(remaining) then
                    ctx.target.butcheringRemaining = remaining
                    return
                end

                sound.Play(
                    sounds[2] or "ambient/machines/slicer4.wav",
                    ctx.target:GetPos()
                )

                hook.Run("OnButchered", butcher, ctx.target)
                ctx.target:Remove()
            end,

            onCancel = function(butcher, reason, ctx)
                releaseTarget(ctx.target)
            end
        })

        if not id then
            releaseTarget(target)
        elseif IsValid(target) and cuttingTargets[target] == client then
            target:EmitSound(sounds[1] or "ambient/machines/slicer1.wav")
        end
    end
end
