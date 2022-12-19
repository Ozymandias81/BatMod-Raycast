/*
 * Copyright (c) 2018-2020 AFADoomer
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
**/

//Shaders related
class EnhWaterHandler : StaticEventHandler
{
	override void RenderOverlay(RenderEvent e)
	{
		// set the player's timer up correctly (more-than-1-tick precision)
		PlayerInfo p = players[consoleplayer];
		Shader.SetUniform1f(p, "watershader", "timer", gametic + e.FracTic);

		if (p.mo.waterlevel >= 3)
		{
			Shader.SetEnabled(p, "watershader", true);
			Shader.SetEnabled(p, "waterzoomshader", true);
			double effectSize = CVar.GetCVar("enh_uweffectsize", p).GetFloat();
			Shader.SetUniform1f(p, "watershader", "waterFactor", effectSize);
			Shader.SetUniform1f(p, "waterzoomshader", "zoomFactor", 1 - (effectSize * 2));
		}
		else
		{
			Shader.SetEnabled(p, "watershader", false);
			Shader.SetEnabled(p, "waterzoomshader", false);
		}
	}
}

//Player related
class BatUnderwater : CustomInventory
{
	int underwatertimer;
	int oldwaterlevel;

	Default
	{
		Inventory.MaxAmount 1;
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.AUTOACTIVATE
	}

	void DoWaterEffects()
	{
		if (underwatertimer > 0) { underwatertimer--; }

		// Spawn bubbles
		if (level.time % 7 == 0)
		{
			if(owner.waterlevel >= 3) //check also stored cvar for custom tweaks
			{
				Actor bubble = Spawn("PlayerBubble", owner.pos + (Random(4, 8), 0, Random(48, 52)));
				if (bubble) { bubble.angle = Random(0, 359); }
			}
		}

		// Play water exit splash sound if you just got out of the water
		if (owner.waterlevel == 0 && oldwaterlevel >= 1) { owner.A_StartSound("water/exit", CHAN_AUTO, 0, 0.025 * owner.vel.z, ATTN_NORM); }

		if (owner is "PlayerPawn")
		{
			// Play underwater sound effect, and stop the sound when the player leaves the water
			if (owner.waterlevel >= 3 && underwatertimer == 0)
			{
				//  Note:  Should really just be a local sound, but local sounds apparently can't be stopped with A_StopSound,
				//  so the "underwtr" sound is set up with a 8-16 unit log attenuation in SNDINFO to get a similar effect...
				owner.A_StartSound("underwtr", 10, CHANF_LOOP, 0.25, ATTN_NORM);
				underwatertimer = Random(90, 127);
			}
			else if (owner.waterlevel < 3 && oldwaterlevel >= 3)
			{
				owner.A_StopSound(10);
				underwatertimer = 0;
			}
		}

		oldwaterlevel = owner.waterlevel;
	}

	override void Tick(void)
	{
		if (Owner && level.time % 5 == 0) // This doesn't need to run every tick...
		{
			DoWaterEffects();
		}

		Super.Tick();
	}

	States
	{
		Use:
			TNT1 A 0;
			Fail;
		Pickup:
			TNT1 A 0
			{
				return true;
			}
			Stop;
	}
}

//Props related
Class UnderwaterPlant1 : Actor
{
	Default
	{
		//$Category New Flora (BatMod)
		//$Title Underwater Seaweed (long)
		//$Color 10
		Radius 8;
		Height 96;
	}
	
	States
	{
	Spawn:
		UWPL A -1;
		Stop;
	}
}

Class UnderwaterPlant2 : UnderwaterPlant1
{
	Default
	{
		//$Title Underwater Seaweed (small)
		Height 32;
	}
	States
	{
	Spawn:
		UWPL B -1;
		Stop;
	}
}

Class UnderwaterPlant3 : UnderwaterPlant2
{
	Default
	{
		//$Title Underwater Seaweed (thin)
	}
	States
	{
	Spawn:
		UWPL C -1;
		Stop;
	}
}

Class UnderwaterPlant4 : UnderwaterPlant1
{
	Default
	{
		//$Title Underwater Seaweed (random)
	}
	States
	{
	Spawn:
		DWPL A 0 NoDelay A_Jump(256,1,2,3,4,5,6,7,8,9,10,11);
		DWPL A -1;
		DWPL B -1;
		DWPL C -1;
		DWPL D -1;
		DWPL E -1;
		DWPL F -1;
		DWPL G -1;
		DWPL H -1;
		DWPL I -1;
		DWPL J -1;
		DWPL K -1;
		Stop;
	}
}

Class UnderwaterPlant5 : UnderwaterPlant1
{
	Default
	{
		//$Title Underwater Decoration (random)
	}
	States
	{
	Spawn:
		KPLA A 0 NoDelay A_Jump(256,1,2,3,"Animated");
		KPLA A -1;
		KPLA B -1;
		KPLA C -1;
		Stop;
	Animated:
		KPLA DE 4;
		Loop;
	}
}

Class UnderwaterPlant6 : UnderwaterPlant1
{
	Default
	{
		//$Title Underwater Column
		Height 64;
		+SOLID
	}
	States
	{
	Spawn:
		KPLA FGH 6;
		Loop;
	}
}