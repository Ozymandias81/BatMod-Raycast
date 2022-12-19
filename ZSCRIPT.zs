Version "4.3"

// Actor that does the bare minumum of ticking
// Use for static, non-interactive actors
//
// Derived from bits and pieces of p_mobj.cpp
class SimpleActor : Actor
{
	Vector2 floorxy;
	Vector3 oldpos;

	override void Tick()
	{
		if (IsFrozen()) { return; }

		Vector2 curfloorxy = (curSector.GetXOffset(sector.floor), curSector.GetYOffset(sector.floor)); // Hacky scroll check because MF8_INSCROLLSEC not externalized to ZScript?
		bool dotick = (curfloorxy != floorxy) || curSector.flags & sector.SECF_PUSH || (pos != oldpos);

		if (dotick) // Only run a full Tick once; or if we are on a carrying floor, pushers are enabled in the sector (wind), or if we moved by some external force
		{
			oldpos = pos;
			Super.Tick();
			floorxy = curfloorxy;
			return;
		}

		if (vel != (0, 0, 0)) // Apply velocity as required
		{
			SetXYZ(Vec3Offset(vel.X, vel.Y, vel.Z)); // Vec3Offset is portal-aware; use instead of just pos + vel, which is not
		}

		// Tick through actor states as normal
		if (tics == -1) { return; }
		else if (--tics <= 0)
		{
			SetState(CurState.NextState);
		}
	}
}

class ParticleBase : SimpleActor // Use for non-interactive effects actors only!
{
	int checktimer;
	int flags;

	FlagDef CHECKPOSITION:flags, 0;

	States
	{
		Fade:
			"####" "#" 1 A_FadeOut(0.1, FTF_REMOVE);
			Loop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		// Set the initial check at a random tick so they don't all check at once...
		checktimer = Random(0, 35);
	}

	override void Tick()
	{
		Super.Tick();

		if (bCheckPosition && checktimer-- <= 0)
		{
			// If it's outside the level, remove it
			if (!level.IsPointInLevel(pos)) { Destroy(); return; }

			checktimer = 35; // Check once every second.
		}
	}
}

#include "zscript/BMOVE.zs"
#include "zscript/MENU.zs"
#include "zscript/bubbles.zs"
#include "zscript/heateffect.zs"
#include "zscript/splashes.zs"
#include "zscript/underwater.zs"

#include "zscript/BASE.zs"
#include "zscript/DEBRIS.zs"
#include "zscript/SFX.zs"