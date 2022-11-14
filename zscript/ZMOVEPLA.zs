enum Bobbing
{
	Bob_Normal,
	Bob_Inverse,
	Bob_Alpha,
	Bob_InverseAlpha,
	Bob_Smooth,
	Bob_InverseSmooth,
	Bob_Build,
	Bob_Dusk,
	Bob_UT
}

Class BMovePlayer : PlayerPawn 
{
	//=========================
	//Common
	
	const BOB_MIN_REALIGN 	 = 0.25f;
	const GROUND_DASH_COOLER = 18;
	
	//Movement General
	bool	Pain;
	double	ViewAngleDelta;
	float	ActualSpeed;
	float	MaxAirSpeed;
	float 	MaxGroundSpeed;
	float	MoveFactor;
	int		AnimateJump;
	int		ForceVelocity;
	int		MoveType;
	int		OldFloorZ;
	playerinfo BMPlayer;
	vector2 OldVelXY;
	vector3	Acceleration;
	
	//////////////////
	
	//Jumping
	bool 	BlockJump;
	bool	Jumped;
	float	FloorAngle;
	int		DoubleJumpCooler;
	int		JumpSoundCooler;
	
	//Double Jump
	bool	BlockDoubleJump;
	bool	CanDoubleJump;
	
	//Elevator Jumps
	float	ElevatorJumpBoost;
	int		OldSecIndex;
	
	//////////////////
	
	//Double Tap
	int		FirstTapTime;
	int		FirstTapValue;
	int		OldTapValue;
	
	//Dashing
	float	WJumpSpeed;
	int		DashNumber;
	int		DashCooler;
	
	//Air Dashing
	float	ADashTargetSpeed;
	int		ADashCooler;
	int		ADashFrictionDelay;
	
	//WallJump
	int		CheckForWJump;
	
	//WallSlideMove
	bool	CanWSlide;
	int		CheckForWSlide;
	vector2	WSlideVelocity;
	
	//Crouch Slide
	bool	CanCSlide;
	float	MaximumSlideSpeed;
	float	QSlideDuration;
	int		CSlideStartTime;
	
	//Ledge Grabbing
	bool	LedgeGrabbed;
	float	LedgeAngle;
	int		LedgeHeight;
	int		LedgeTime;
	weapon	ReselectWeapon;
	
	//Grappling Hook
	actor	GrappledMonster;
	actor	HookFired;
	bool	Grappled;
	float	PendulumLength;
	vector3	GrappleVel;
	vector3 Rope;
	
	//////////////////
	
	//View Bobbing
	bool	PostLandingBob;
	float	ZMBob;
	
	//Weapon bobbing
	bool	DoBob;
	double	BobTime;
	double	HorizontalSway;
	double	BobRange;
	double 	OldTicFrac;
	double	VerticalOffset;
	
	//=========================
	//Build Engine Only
	
	//Movement
	bool	DeepWater;
	float	LandingVelZ;
	int		FVel;
	int		SVel;
	int		UVel;
	
	//Jumping
	int		BuildJumpDelay;
	
	Default
    {
		Player.DisplayName "Batman";
        PainChance 255;
    }
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////																						////
	//// Non-Movement Stuff																		////
	////																						////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	
	//Because GZDoom's Unit() returns NaN if a vector has no value
	vector3 SafeUnit3(Vector3 VecToUnit)
	{
		if(VecToUnit.Length()) { VecToUnit /= VecToUnit.Length(); }
		return VecToUnit;
	}
	
	vector2 SafeUnit2(Vector2 VecToUnit)
	{
		if(VecToUnit.Length()) { VecToUnit /= VecToUnit.Length(); }
		return VecToUnit;
	}
	
	Override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		
		//No voodoo dolls allowed past this point
		if(!self.player || self.player.mo != self) { return; }
		bNOFRICTION = True;
	}
	
	Override void PlayerThink()
	{
		//======================================
		//Store info needed in multiple places
		
		BMPlayer = self.player;
		ActualSpeed = Speed * GetPowerSpeed();
		MaxGroundSpeed = zm_maxgroundspeed * ActualSpeed;
		MoveFactor = ScaleMovement();
		MoveType = zm_movetype;
		Pain = InStateSequence(CurState, FindState("Pain"));
		BMPlayer.OnGround = Pos.Z <= FloorZ || bONMOBJ || bMBFBOUNCER || (BMPlayer.Cheats & CF_NOCLIP2);
		
		//======================================
		//Execute Player tic cycle
		
		CheckFOV();
		
		if(BMPlayer.inventorytics) { BMPlayer.inventorytics--; }
		CheckCheats();

		bool totallyfrozen = CheckFrozen();

		// Handle crouching
		CheckCrouch(totallyfrozen);
		CheckMusicChange();

		if(BMPlayer.playerstate == PST_DEAD)
		{
			DeathThink();
			return;
		}
		if(BMPlayer.morphTics && !(BMPlayer.cheats & CF_PREDICTING)) { MorphPlayerThink (); }

		CheckPitch();
		HandleMovement();
		CalcHeight();

		if(!(BMPlayer.cheats & CF_PREDICTING))
		{
			CheckEnvironment();
			// Note that after this point the PlayerPawn may have changed due to getting unmorphed or getting its skull popped so 'self' is no longer safe to use.
			// This also must not read mo into a local variable because several functions in this block can change the attached PlayerPawn.
			BMPlayer.mo.CheckUse();
			BMPlayer.mo.CheckUndoMorph();
			// Cycle psprites.
			BMPlayer.mo.TickPSprites();
			// Other Counters
			if(BMPlayer.damagecount) BMPlayer.damagecount--;
			if(BMPlayer.bonuscount) BMPlayer.bonuscount--;

			if(BMPlayer.hazardcount)
			{
				BMPlayer.hazardcount--;
				if(!(Level.maptime % BMPlayer.hazardinterval) && BMPlayer.hazardcount > 16*TICRATE)
					BMPlayer.mo.DamageMobj (NULL, NULL, 5, BMPlayer.hazardtype);
			}
			BMPlayer.mo.CheckPoison();
			BMPlayer.mo.CheckDegeneration();
			BMPlayer.mo.CheckAirSupply();
		}
		
		//Bob weapon stuff
		BobWeaponAuxiliary();
		
		//Old values for comparisons
		OldFloorZ = FloorZ;
		OldVelXY = Vel.XY;
	}
	
	float GetPowerSpeed()
	{
		float factor = 1.f;
		
		if(!BMPlayer.morphTics)
		{
			for(let it = Inv; it != null; it = it.Inv)
			{
				factor *= it.GetSpeedFactor();
			}
		}
		
		return factor;
	}
	
	Override void DeathThink()
	{
		bNOFRICTION = False;
		Gravity = zm_setgravity;
		
		Super.DeathThink();
	}
	
	Override void CalcHeight()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		double HeightAngle;
		double bob;
		bool still = false;

		if(!BMPlayer.OnGround || (BMPlayer.OnGround && ((cmd.buttons & BT_JUMP) && !BlockJump)) || BMPlayer.cheats & CF_NOCLIP2) //nobody walks in the air
		{
			ZMBob--;
			ZMBob = max(bNOGRAVITY ? 0.5f : 0.f, ZMBob);
			PostLandingBob = True;
		}
		else
		{
			if(PostLandingBob)
			{
				ZMBob += Vel.XY.Length() / (MaxGroundSpeed ? MaxGroundSpeed : 1.f);
				if(ZMBob >= Vel.XY.Length() * BMPlayer.GetMoveBob()) { PostLandingBob = False; }
			}
			else
			{
				ZMBob = Vel.XY.Length() * BMPlayer.GetMoveBob(); //this way all GetMoveBob() values are meaningful
			}
			
			if(!ZMBob)
				still = true;
			else
				ZMBob = min(MaxGroundSpeed, ZMBob);
		}

		double defaultviewheight = ViewHeight + BMPlayer.crouchviewdelta;

		if(BMPlayer.cheats & CF_NOVELOCITY)
		{
			BMPlayer.viewz = pos.Z + defaultviewheight;

			if(BMPlayer.viewz > ceilingz-4)
				BMPlayer.viewz = ceilingz-4;

			return;
		}

		if(still)
		{
			if(BMPlayer.health > 0)
				bob = 2 * BMPlayer.GetStillBob() * sin(2 * Level.maptime);
			else
				bob = 0;
		}
		else
		{
			HeightAngle = Level.maptime / 20. * 360.;
			bob = ZMBob * sin(HeightAngle) * (waterlevel > 2 ? 0.25f : 0.5f);
		}
		
		if(BMPlayer.morphTics) { bob = 0; }
		
		//=======================================
		// Customizable Landing
		
		if(zm_landing || MoveType == 1)
		{
			if(BMPlayer.playerstate == PST_LIVE)
			{
				if(!BMPlayer.OnGround)
				{
					if(Vel.Z >= 0)
					{
						BMPlayer.viewheight += BMPlayer.deltaviewheight;
						BMPlayer.deltaviewheight += zm_landingspeed * 2.f; //ensure a speedy recovery while in the air
						if(BMPlayer.viewheight >= defaultviewheight)
						{
							BMPlayer.deltaviewheight = 0;
							BMPlayer.viewheight = defaultviewheight;
						}
					}
					else
					{
						LandingVelZ = abs(Vel.Z);
						BMPlayer.deltaviewheight = Vel.Z / zm_landingsens;
						BMPlayer.viewheight = defaultviewheight;
					}
				}
				else
				{
					BMPlayer.viewheight += BMPlayer.deltaviewheight;

					if(BMPlayer.viewheight > defaultviewheight)
					{
						BMPlayer.viewheight = defaultviewheight;
						BMPlayer.deltaviewheight = 0;
					}
					else if(BMPlayer.viewheight < defaultviewheight * zm_minlanding && !BuildJumpDelay)
					{
						BMPlayer.viewheight = defaultviewheight * zm_minlanding;
						if(BMPlayer.deltaviewheight <= 0) { BMPlayer.deltaviewheight = 1 / 65536.f; }
					}
					
					if(BMPlayer.deltaviewheight)	
					{
						BMPlayer.deltaviewheight += zm_landingspeed;
						if(!BMPlayer.deltaviewheight) { BMPlayer.deltaviewheight = 1 / 65536.f; }
					}
				}
			}
		}
		else //regular Doom landing
		{
			if(BMPlayer.playerstate == PST_LIVE)
			{
				BMPlayer.viewheight += BMPlayer.deltaviewheight;
				
				if(BMPlayer.viewheight > defaultviewheight)
				{
					BMPlayer.viewheight = defaultviewheight;
					BMPlayer.deltaviewheight = 0;
				}
				else if(BMPlayer.viewheight < (defaultviewheight/2))
				{
					BMPlayer.viewheight = defaultviewheight/2;
					if(BMPlayer.deltaviewheight <= 0)
						BMPlayer.deltaviewheight = 1 / 65536.;
				}
				
				if(BMPlayer.deltaviewheight)	
				{
					BMPlayer.deltaviewheight += 0.25;
					if(!BMPlayer.deltaviewheight) { BMPlayer.deltaviewheight = 1/65536.; }
				}
			}
		}
			
		//Let's highlight the important stuff shall we?
		BMPlayer.viewz = pos.Z + BMPlayer.viewheight + (bob * clamp(ViewBob, 0., 1.5));
		
		if(Floorclip && BMPlayer.playerstate != PST_DEAD && pos.Z <= floorz) { BMPlayer.viewz -= Floorclip; }
		if(BMPlayer.viewz > ceilingz - 4) { BMPlayer.viewz = ceilingz - 4; }
		if(BMPlayer.viewz < FloorZ + 4) { BMPlayer.viewz = FloorZ + 4; }
	}
	
	Override void CheckPitch()
	{
		int clook = BMPlayer.cmd.pitch;
		if(clook != 0)
		{
			if(clook == -32768)
			{
				BMPlayer.centering = true;
			}
			else if(!BMPlayer.centering)
			{
				A_SetPitch(Pitch - clook * (360. / 65536.), SPF_INTERPOLATE);
			}
		}
		
		if(BMPlayer.centering)
		{
			if(abs(Pitch) > 2.)
			{
				Pitch *= (2. / 3.);
			}
			else
			{
				Pitch = 0.;
				BMPlayer.centering = false;
				if(PlayerNumber() == consoleplayer)
				{
					LocalViewPitch = 0;
				}
			}
		}
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////																						////
	//// Movement Stuff																			////
	////																						////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	
	Override void HandleMovement()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		// [RH] Check for fast turn around
		if(cmd.buttons & BT_TURN180 && !(BMPlayer.oldbuttons & BT_TURN180)) { BMPlayer.turnticks = TURN180_TICKS; }

		// Handle movement
		if(reactiontime)
		{ // Player is frozen
			reactiontime--;
		}
		else
		{	
			ViewAngleDelta = cmd.Yaw * (360.0 / 65536.0); //needed for two other things
			
			if(BMPlayer.TurnTicks) //moved here to save many doubled lines
			{
				BMPlayer.TurnTicks--;
				A_SetAngle(Angle + (180.0 / TURN180_TICKS), SPF_INTERPOLATE);
			}
			else
			{
				A_SetAngle(Angle + ViewAngleDelta, SPF_INTERPOLATE);
				if(LedgeGrabbed) { Angle = clamp(Angle, LedgeAngle - 20, LedgeAngle + 20); }
			}
			
			//========================================
			//Acrobatics triggers
			if(CVar.GetCVar("zm_doubletap", Player).GetBool()) { DoubleTapCheck(); }
			//Dashing parameters reset
			if(DashCooler)
			{
				if(DashCooler <= GROUND_DASH_COOLER || DashCooler > 100)
				{
					DashCooler--;
				}
				else if(BMPlayer.OnGround || WaterLevel >= 2 || bNOGRAVITY)
				{
					WJumpSpeed = DashNumber = 0;
					DashCooler = GROUND_DASH_COOLER;
				}
			}
			//Air Dash
			if(zm_airdash || zm_wjump)
			{
				if(ADashCooler) { ADashCooler--; }
				if(ADashTargetSpeed) { AirDashFriction(); }
			}
			//Wall Jumping
			if(CheckForWJump) { DashInitiator(); }
			//Wall Slide
			if(CheckForWSlide) { WallSlideInitiator(); }
			//Crouchsliding
			if(zm_crouchslide) { CSlideInitiator(); }
			
			//========================================
			//Gravity
			if(MoveType == 1)
				BuildGravity();
			
			else if(MoveType == 5)
				UTGravity();
			else
				DGravity();
			
			//========================================
			//Say no to wall friction
			QuakeWallFriction();
			
			//========================================
			//Actual Movement selection
			if(GrappleVel.Length())
			{
				GrapplingMove();
			}
			else if(CanWSlide)
			{
				WallSlideMove();
			}
			else if(LedgeGrabbed)
			{
				LedgeGrab();
			}
			else if(WaterLevel >= 2)
			{
				if(!MoveType)
					DoomWaterMove();
				else if(MoveType == 1)
					BuildWaterMove();
				else if(MoveType == 2)
					DuskWaterMove();
				else if(MoveType == 4)
					QuakeWaterMove();
				else if(MoveType == 5)
					UTWaterMove();
				
				if(zm_ledgegrab) { LedgeGrabInitiator(); }
			}
			else if(bNOGRAVITY)
			{
				if(!MoveType)
					DoomFlyMove();
				else if(MoveType == 1)
					BuildFlyMove();
				else if(MoveType == 2)
					DuskFlyMove();
				else if(MoveType == 4)
					QuakeFlyMove();
				else if(MoveType == 5)
					UTFlyMove();
			}
			else if(CanCSlide)
			{
				if(zm_crouchslide == 2)
					QSlideMove();
				else
					CSlideMove();
				
				if(MoveType == 1) { LandingVelZ = 0.f; }
			}
			else
			{
				if(!MoveType)
					DoomHandleMove();
				else if(MoveType == 1)
					BuildHandleMove();
				else if(MoveType == 2)
					DuskHandleMove();
				else if(MoveType == 4)
					QuakeHandleMove();
				else
					UTHandleMove();
			}
			
			//========================================
			//Jumping
			if(MoveType == 1)
				BuildJump();
			else if(MoveType == 5)
				UTJump();
			else
				CheckJump();
			
			//========================================
			//Misc
			if(BMPlayer.Cheats & CF_REVERTPLEASE != 0)
			{
				BMPlayer.Cheats &= ~CF_REVERTPLEASE;
			}
			
			CheckMoveUpDown();
		}
	}
	
	void QuakeWallFriction()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(ForceVelocity)
		{
			if(OldVelXY.Length() && Vel.XY.Length() && (cmd.forwardmove || cmd.sidemove))
			{
				Vector2 VelUnit = Vel.XY.Unit();
				Float VelDot = OldVelXY.Unit() dot VelUnit;
				if(VelDot > 0)
				{
				   if(VelDot > 0.75)
					  VelDot = 1.f;
				   else
					  VelDot /= 0.75;
				   
				   Vel.XY = VelDot * OldVelXY.Length() * VelUnit;
				}
				ForceVelocity--;
			}
			else
			{
				ForceVelocity = 0;
			}
		}
		if(!CheckMove(Pos.XY + Vel.XY)) { ForceVelocity = 2; }
	}
	
	//////////////////////////////////////////
	// Jumping								//
	//////////////////////////////////////////
	
	void PreJumpCommon()
	{
		//Jumptics settings
		if(Jumped && (Player.OnGround || WaterLevel >= 2 || bNOGRAVITY)) { Jumped = False; }
		
		//Jump Sound Cooler
		if(JumpSoundCooler) { JumpSoundCooler--; }
		
		//Doudle jump cooler
		if(DoubleJumpCooler) { DoubleJumpCooler--; }
		
		//Double Jump
		if(BMPlayer.OnGround) { CanDoubleJump = True; }
	}
	
	float GetPowerJump()
	{
		Float JumpFac = 0.f;
		
		for(let p = Inv; p != null; p = p.Inv)
		{
			let pp = PowerHighJump(p);
			if(pp) { JumpFac = max(JumpFac, pp.Strength); }
		}
		
		return JumpFac;
	}
	
	bool, bool CheckIfJumpable()
	{
		if(CeilingZ - FloorZ <= Height) //sector is just high enough for player to pass through but not jump
		{
			return True, False;
		}
		else
		{
			//===============================
			// Get floor normal
			
			Vector3 FloorNormal;
			F3DFloor ThreeDFloor;
			for(int i = 0; i < FloorSector.Get3DFloorCount(); i++)
			{
				if(FloorSector.Get3DFloor(i).Top.ZAtPoint(Pos.XY) ~== FloorZ)
				{
					ThreeDFloor = FloorSector.Get3DFloor(i);
					break;
				}
			}
			FloorNormal = ThreeDFloor ? - ThreeDFloor.Top.Normal : FloorSector.FloorPlane.Normal;
			FloorAngle = atan2(FloorNormal.XY.Length(), FloorNormal.Z);
			
			//==============================
			//Come to the logical conclusion
			
			if(FloorAngle < 45)
				return BlockJump ? True : False, !FloorAngle ? False : True;
			else
				return BMPlayer.OnGround ? True : False, True; //floor is too steep
		}
    }
	
	void ElevatorJump(bool SlopedFloor)
	{
		Int SecIndex = FloorSector.Index();
		Bool CheckForElevator = BMPlayer.OnGround && SecIndex == OldSecIndex && !SlopedFloor;
		
		if(zm_elevatorjump)
		{
			if(CheckForElevator && FloorZ > OldFloorZ) //no accidental elevator jump boost on slopes
				ElevatorJumpBoost = (FloorZ - OldFloorZ) * zm_ejumpmultiplier;
			else
				ElevatorJumpBoost = 0;
		}
		else
		{
			if(CheckForElevator && FloorZ - OldFloorZ >= zm_jumpheight / 2.f) { BlockJump = True; } //floor is raising too fast to not spam jump
			ElevatorJumpBoost = 0;
		}
		
		OldSecIndex = SecIndex;
	}
	
	void DGravity()
	{
		if(WaterLevel >= 2)
		{
			if(Vel.Length() < MaxGroundSpeed / 3.f)
				Gravity = 0.5f;
			else
				Gravity = 0.f;
		}
		else if(bNOGRAVITY || GrappleVel.Length())
		{
			Gravity = 0.f;
		}
		else
		{
			Gravity = zm_setgravity;
		}
	}
	
	Override void CheckJump()
	{
		//Common stuff
		PreJumpCommon();
		
		//underwater/flying specific jump behavior are in WaterMove and FlyMove
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Check slope angle and sector height
		Bool SlopedFloor;
		[BlockJump, SlopedFloor] = CheckIfJumpable();
		
		//Elevators Jump Boost
		ElevatorJump(SlopedFloor);
		
		////////////////////////////////
		//Actual Jump
		if(BMPlayer.cmd.buttons & BT_JUMP)
		{
			//Special circumstances jump denial
			if(LedgeGrabbed || GrappleVel.Length() || CanWSlide || DashCooler > 100) { return; }
			
			if(BMPlayer.crouchoffset != 0)
			{
				BMPlayer.crouching = 1;
			}
			else if(BMPlayer.OnGround && !BlockJump)
			{
				Float JumpVelZ = zm_jumpheight + ElevatorJumpBoost;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { JumpVelZ *= JumpFac; }
				
				Vel.Z += (Vel.Z > 0 ? zm_rjumpmulti : 1) * JumpVelZ;
				
				bONMOBJ = false;
				Jumped = True;
				
				if(!(BMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler)
				{
					A_PlaySound("*jump", CHAN_BODY);
					JumpSoundCooler = 4;
				}
				
				//if autojump is off set BlockJump true until jump key is unpressed
				BlockJump = zm_autojump ? False : True;
				DoubleJumpCooler = 5;
			}
			else if(!BMPlayer.OnGround && CanDoubleJump && !BlockDoubleJump && !DoubleJumpCooler && ((zm_doublejump == 1 && Vel.Z > 0) || zm_doublejump == 2))
			{
				Float DoubleJumpVelZ = zm_jumpheight * zm_doublejumpheight;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { DoubleJumpVelZ *= JumpFac; }
				Vel.Z = DoubleJumpVelZ;
				
				bONMOBJ = false;
				Jumped = True;
				
				if(!(BMPlayer.cheats & CF_PREDICTING)) { A_PlaySound("*jump", CHAN_BODY); }
				
				CanDoubleJump = False;
			}
			
			BlockDoubleJump = True;
		}
		else
		{
			BlockDoubleJump = False;
			BlockJump = False;
		}
	}
	
	void BuildGravity()
	{
		if(!bNOGRAVITY && !WaterLevel < 2 && !GrappleVel.Length())
			Gravity = zm_setgravity;
		else
			Gravity = 0.f;
	}
	
	void BuildJump()
	{
		//Common stuff
		PreJumpCommon();
		
		//underwater/flying specific jump behavior are in WaterMove and FlyMove
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Check slope angle and sector height
		Bool SlopedFloor;
		[BlockJump, SlopedFloor] = CheckIfJumpable();
		
		//Elevators Jump Boost
		ElevatorJump(SlopedFloor);
		
		////////////////////////////////
		//Actual Jump
		if(BMPlayer.cmd.buttons & BT_JUMP || BuildJumpDelay)
		{
			//Special circumstances jump denial
			if(LedgeGrabbed || GrappleVel.Length() || CanWSlide || LandingVelZ >= 10.f || DashCooler > 100) { return; }
			
			if(BMPlayer.crouchoffset != 0)
			{
				BMPlayer.crouching = 1;
			}
			else if(BMPlayer.onground && !BlockJump)
			{
				Double BuildSmallerJump;
				
				if(BMPlayer.deltaviewheight)
				{
					BuildSmallerJump = 0.85f;
				}
				else
				{
					BuildJumpDelay++;
					if(BuildJumpDelay == 1)
					{
						BMPlayer.viewheight -= be_jumpanim;
						return;
					}
					else
					{
						BuildJumpDelay = 0;
						BuildSmallerJump = 1.f;
					}
				}
				
				Float JumpVelZ = zm_jumpheight + ElevatorJumpBoost;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { JumpVelZ *= JumpFac; }
				
				Vel.Z += (Vel.Z > 0 ? zm_rjumpmulti : 1) * JumpVelZ;
					
				bONMOBJ = false;
				Jumped = True;
					
				if(!(BMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler)
				{
					A_PlaySound("*jump", CHAN_BODY);
					JumpSoundCooler = 4;
				}
				
				BlockJump = zm_autojump ? False : True;
				DoubleJumpCooler = 5;
			}
			else if(!BMPlayer.OnGround)
			{
				if(BuildJumpDelay) { BuildJumpDelay = 0; }
				
				if(CanDoubleJump && !BlockDoubleJump && !DoubleJumpCooler && ((zm_doublejump == 1 && Vel.Z > 0) || zm_doublejump == 2))
				{
					Float DoubleJumpVelZ = zm_jumpheight * zm_doublejumpheight;
					Float JumpFac = GetPowerJump();
					if(JumpFac) { DoubleJumpVelZ *= JumpFac; }
					Vel.Z = DoubleJumpVelZ;
					
					bONMOBJ = false;
					Jumped = True;
					
					if(!(BMPlayer.cheats & CF_PREDICTING)) { A_PlaySound("*jump", CHAN_BODY); }
					
					CanDoubleJump = False;
				}
			}
			
			BlockDoubleJump = True;
		}
		else
		{
			BlockDoubleJump = False;
			BlockJump = False;
		}
	}
	
	void UTGravity()
	{
		//Gravity
		if(WaterLevel >= 2)
		{
			if(Vel.Length() < MaxGroundSpeed / 3.f && !(BMPlayer.cmd.buttons & BT_JUMP))
				Gravity = 0.5f;
			else
				Gravity = 0.f;
		}
		else if(bNOGRAVITY || GrappleVel.Length())
		{
			Gravity = 0.f;
		}
		else
		{
			Gravity = zm_setgravity;
		}
	}
	
	void UTJump()
	{
		//Common stuff
		PreJumpCommon();
		
		//underwater/flying specific jump behavior are in WaterMove and FlyMove
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Check slope angle and sector height
		Bool SlopedFloor;
		[BlockJump, SlopedFloor] = CheckIfJumpable();
		
		//Elevators Jump Boost
		ElevatorJump(SlopedFloor);
		
		////////////////////////////////
		//Actual Jump
		if(BMPlayer.cmd.buttons & BT_JUMP)
		{
			//Special circumstances jump denial
			if(LedgeGrabbed || GrappleVel.Length() || CanWSlide || (DashCooler && DashCooler != 100)) { return; }
			
			if(BMPlayer.crouchoffset != 0)
			{
				BMPlayer.crouching = 1;
			}
			else if(BMPlayer.OnGround && !BlockJump)
			{
				Float JumpVelZ = zm_jumpheight + ElevatorJumpBoost;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { JumpVelZ *= JumpFac; }
				
				Vel.Z += (Vel.Z > 0 ? zm_rjumpmulti : 1) * JumpVelZ;
				
				bONMOBJ = false;
				Jumped = True;
				
				if(!(BMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler)
				{
					A_PlaySound("*jump", CHAN_BODY);
					JumpSoundCooler = 4;
				}
				
				//if autojump is on set Blockjump false while jump key is pressed
				BlockJump = zm_autojump ? False : True;
				DoubleJumpCooler = 5;
			}
			else if(!BMPlayer.OnGround && zm_doublejump && CanDoubleJump && !BlockDoubleJump && !DoubleJumpCooler && Vel.Z > 0)
			{
				Float DoubleJumpVelZ = zm_jumpheight * zm_doublejumpheight;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { DoubleJumpVelZ *= JumpFac; }
				Vel.Z = DoubleJumpVelZ;
				
				bONMOBJ = false;
				Jumped = True;
				
				if(!(BMPlayer.cheats & CF_PREDICTING)) { A_PlaySound("*jump", CHAN_BODY); }
				
				CanDoubleJump = False;
			}
			
			BlockDoubleJump = True;
		}
		else
		{
			BlockDoubleJump = False;
			if(BMPlayer.OnGround) { BlockJump = False; }
		}
	}
	
	//////////////////////////////////////////
	// Ground Movement						//
	//////////////////////////////////////////
	
	float ScaleMovement()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		Float MoveMulti;
		if(cmd.sidemove || cmd.forwardmove)
		{
			Bool IsWalking = (CVar.GetCVar("cl_run", Player).GetBool() && (cmd.buttons & BT_SPEED)) || (!CVar.GetCVar("cl_run", Player).GetBool() && !(cmd.buttons & BT_SPEED));
			
			if(BMPlayer.CrouchFactor == 0.5)
				MoveMulti = min(zm_crouchspeed, zm_walkspeed);
			else if(IsWalking)
				MoveMulti = zm_walkspeed;
			else
				MoveMulti = 1;
		}
		else
		{
			MoveMulti = 1;
		}
		
		return MoveMulti;
	}
	
	float SpeedMulti()
	{
		return MoveFactor * (BMPlayer.cmd.forwardmove && BMPlayer.cmd.sidemove ? zm_strafemodifier : 1);
	}
	
	float AccelMulti()
	{
		return ActualSpeed * (BMPlayer.cmd.forwardmove && BMPlayer.cmd.sidemove ? zm_strafemodifier : 1);
	}
	
	void DropPrevention()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		Bool GuardRail = ((!cmd.sidemove && !cmd.forwardmove && Vel.XY.Length()) ||
						 (CVar.GetCVar("cl_run", Player).GetBool() && (cmd.buttons & BT_SPEED)) || (!CVar.GetCVar("cl_run", Player).GetBool() && !(cmd.buttons & BT_SPEED))) //fuck me having to do this
						 && BMPlayer.OnGround && !Pain;
		
		if(GuardRail)
		{
			Float GuardAngle = VectorAngle(Vel.X, Vel.Y);
			Float GuardX = Pos.X + Radius * cos(GuardAngle);
			Float GuardY = Pos.Y + Radius * sin(GuardAngle);
			Bool FallDanger = Pos.Z - GetZAt(GuardX, GuardY, 0, GZF_ABSOLUTEPOS|GZF_ABSOLUTEANG) > Height;
			if(FallDanger) { Vel.XY *= 0.5f; }
		}
	}
	
	void GroundSpriteAnimation()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(BMPlayer.Cheats & CF_PREDICTING == 0 && Vel.XY.Length() > 1.f && (cmd.forwardmove || cmd.sidemove))
			PlayRunning();
		else
			PlayIdle();
			
		AnimateJump = 6;
	}
	
	void AirSpriteAnimation()
	{
		if(AnimateJump)
		{
			PlayRunning();
			AnimateJump--;
		}
		else
		{
			PlayIdle();
		}
	}
	
	//=========================
	// Doom
	
	void DoomHandleMove()
	{
		if(!BMPlayer.OnGround || (BMPlayer.OnGround && DashNumber))
		{
			DoomAirMove();
			if(zm_ledgegrab) { LedgeGrabInitiator(); }
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			DoomGroundMove();
			Grappled = False;
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void DFriction()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Going too slow, stop
		if(WaterLevel >= 2 || bNOGRAVITY)
		{
			if(Vel.Length() < 1.f && !cmd.sidemove && !cmd.forwardmove)
			{
				Vel.XY = (0, 0);
				return;
			}
		}
		else if(Vel.XY.Length() < 1.f && !cmd.sidemove && !cmd.forwardmove)
		{
			Vel.XY = (0, 0);
			return;
		}
		
		//Balance friction with inputs strength
		if(WaterLevel >= 2)
		{
			Acceleration *= 4.f;
			Vel *= 0.6f;
		}
		else if(bNOGRAVITY)
		{
			Vel *= 0.9f;
		}
		else
		{
			Acceleration.XY *= zm_friction;
			Vel.XY *= 1 - zm_friction / 10.f;
		}
	}
	
	void DoomGroundMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, -cmd.sidemove), Angle);
		Acceleration.XY = (MaxGroundSpeed / 10.f) * SafeUnit2(Acceleration.XY);
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		// Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DoomAirMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		Bool DashMove;
		if((DashNumber || Grappled) && MaxAirSpeed > MaxGroundSpeed) { DashMove = True; }
		
		//=========================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, -cmd.sidemove), Angle);
		Acceleration.XY = (MaxGroundSpeed / 100.f) * SafeUnit2(Acceleration.XY);
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), DashMove ? MaxAirSpeed : MaxGroundSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void WaterVelZLimiter()
	{
		//Avoids dolphin jumping out of water
		Vel.Z = min(6.f, Vel.Z);
		if(Pitch < 0) { Acceleration.Z = 0; }
	}
	
	void DoomWaterMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//=========================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = (MaxGroundSpeed / 20.f) * SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * (MaxGroundSpeed / 20.f) * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		if(WaterLevel == 2) { WaterVelZLimiter(); }
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DoomFlyMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//=========================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		if(Acceleration.Length()) { Acceleration.XY = (MaxGroundSpeed * 3.f / 20.f) * SafeUnit2(Acceleration.XY); }
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * (MaxGroundSpeed * 3.f / 20.f) * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Limiter
		Vel = min(Vel.Length(), (MaxGroundSpeed * 3.f) / 2.f) * SafeUnit3(Vel);
		
		//Sprite Animatiom
		PlayIdle();
	}
	
	//====================================
	// Build Engine
	
	void BuildHandleMove()
	{
		MaxGroundSpeed *= SpeedMulti();
		
		if(!BMPlayer.OnGround || (BMPlayer.OnGround && DashNumber))
		{
			BuildAirMove();
			if(zm_ledgegrab) { LedgeGrabInitiator(); }
		}
		else
		{
			BuildGroundMove();
			Grappled = False;
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void BuildInputDetection()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(cmd.sidemove)
		{
			if(cmd.buttons & BT_MOVERIGHT)
				SVel += 40;
			else
				SVel -= 40;
				
			SVel = clamp(SVel, -90, 90);
		}
		else
		{
			SVel = 0;
		}
		
		if(cmd.forwardmove)
		{
			if(cmd.buttons & BT_FORWARD)
				FVel += 40;
			else
				FVel -= 40;
				
			FVel = clamp(FVel, -90, 90);
		}
		else
		{
			FVel = 0;
		}
		
		//Only for flying and swimming
		if(WaterLevel == 2 && DeepWater)
		{
			if(cmd.buttons & BT_JUMP)
			{
				if(Vel.Z > 0) { Vel.Z = 0.f; }
				UVel = 0;
				return;
			}
			else
			{
				DeepWater = False;
			}
		}
		
		if(bNOGRAVITY || WaterLevel >= 2)
		{
			if(cmd.buttons & BT_JUMP)
				UVel += 40;
			else if(cmd.buttons & BT_CROUCH)
				UVel -= 40;
			else
				UVel = 0;
				
			UVel = clamp(UVel, -90, 90);
		}
		else
		{
			UVel = 0;
		}
	}
	
	int BuildFriction()
	{
		//Friction Value
		Int Friction;
		if(WaterLevel >= 2)
			Friction = - 0x2000;
		else if(bNOGRAVITY)
			Friction = 0;
		else
			Friction = (8 - zm_friction) * 2 * 0x0200;
		
		//Applying the friction on the length of the vector instead of the single components fixed the Build engine directional distortion
		Int FrictionedVel = Int((!bNOGRAVITY && WaterLevel < 2 ? Vel.XY.Length() : Vel.Length()) * (0xCFD0 + Friction)) >> 16;
		
		return FrictionedVel <= 10.f ? 0 : FrictionedVel;
	}
	
	void BuildGroundMove()
	{
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Convert Velocity in Build Units
		Vel.XY *= 20.f;
		
		if(LandingVelZ < 10.f) //this value feels good
		{
			//Directional inputs
			BuildInputDetection();
			Acceleration.XY = RotateVector((FVel, - SVel), Angle);
			if(Acceleration.XY.Length()) { Acceleration.XY = min(Acceleration.XY.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti(); }
			
			//Acceleration
			Vel.XY += Acceleration.XY;
		}
		else //landing recovery
		{
			LandingVelZ--;
		}
		
		//Friction
		Int FrictionedVel = BuildFriction();
		
		//Translate back into Doom Units
		Vel.XY /= 20.f;
		FrictionedVel /= 20.f;
		
		//Limiter
		Vel.XY = min(FrictionedVel, MaxGroundSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void BuildAirMove()
	{
		Bool DashMove;
		if((DashNumber || Grappled) && MaxAirSpeed > MaxGroundSpeed) { DashMove = True; }
		
		//====================================
		//Actual Movement
		
		//Convert Velocity in Build Units
		Vel.XY *= 20.f;
		
		//Directional inputs
		BuildInputDetection();
		Acceleration.XY = RotateVector((FVel, - SVel), Angle);
		Acceleration.XY = min(Acceleration.XY.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Friction
		Int FrictionedVel;
		if(!DashMove)
			FrictionedVel = BuildFriction();
		else
			FrictionedVel = Vel.XY.Length();
		
		//Limiter
		Vel.XY = min(FrictionedVel, (DashMove ? MaxAirSpeed : MaxGroundSpeed) * 20) * SafeUnit2(Vel.XY);
		
		//Translate back into Doom Units
		Vel.XY /= 20.f;
		
		//Sprite Animation
		AirSpriteAnimation();
		
		//Reset speed cap
		if(Vel.XY.Length() <= MaxGroundSpeed) { MaxAirSpeed = Vel.XY.Length(); }
	}
	
	void BuildWaterMove()
	{
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		if(WaterLevel == 3) { DeepWater = True; }
		
		//====================================
		//Actual Movement
		
		//Convert Velocity in Build Units
		Vel *= 20.f;
		
		//Directional inputs
		BuildInputDetection();
		Acceleration.XY = RotateVector((FVel, - SVel), Angle);
		Acceleration.XY = min(Acceleration.XY.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Crouch/jump press
		Vel.Z += UVel;
		
		//Friction
		Int FrictionedVel = BuildFriction();
		
		//Limiter
		Vel = min(FrictionedVel, MaxGroundSpeed * 15.f) * SafeUnit3(Vel);
		if(Deepwater && WaterLevel == 2 && Vel.Z > 0) { Vel.Z = 0; }
		
		//Translate back into Doom Units
		Vel /= 20.f;
		
		// Sprite Animation
		GroundSpriteAnimation();
	}
	
	void BuildFlyMove()
	{
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Convert Velocity in Build Units
		Vel *= 20.f;
		
		//Directional inputs
		BuildInputDetection();
		Acceleration.XY = RotateVector((FVel, - SVel), Angle);
		Acceleration.XY = min(Acceleration.XY.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Crouch/jump press
		Vel.Z += UVel;
		
		//Friction
		Int FrictionedVel = BuildFriction();
		
		//Limiter
		Vel = min(FrictionedVel, MaxGroundSpeed * 30.f) * SafeUnit3(Vel);
		
		//Translate back into Doom Units
		Vel /= 20.f;
		
		// Sprite Animatiom
		PlayIdle();
	}
	
	//====================================
	// Dusk
	
	void DuskHandleMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(!BMPlayer.OnGround || (BMPlayer.OnGround && (((cmd.buttons & BT_JUMP) && !BlockJump) || DashNumber)))
		{
			DuskAirMove();
			if(zm_ledgegrab) { LedgeGrabInitiator(); }
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			DuskGroundMove();
			Grappled = False;
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void DuskGroundMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, -cmd.sidemove), Angle);
		Acceleration.XY = (MaxGroundSpeed / 10.f) * SafeUnit2(Acceleration.XY);
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DuskAirMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		Bool CanAccelerate = ((cmd.buttons & BT_MOVERIGHT) && !(cmd.buttons & BT_MOVELEFT)) || (!(cmd.buttons & BT_MOVERIGHT) && (cmd.buttons & BT_MOVELEFT));
		
		//====================================
		//Actual Movement
		
		//Top Speed Penalty
		if(!CanAccelerate && BMPlayer.OnGround) { MaxAirSpeed = max(MaxAirSpeed - dsk_acceleration * ActualSpeed / 2.f, MaxGroundSpeed); }
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		if(Acceleration.XY.Length())
		{
			Acceleration.XY = MaxAirSpeed * SafeUnit2(Acceleration.XY) / 3.f; //multiplying by Vel / 10.f mantains air control consistent at all speed
			
			//Top Speed
			if(!ADashTargetSpeed)
			{
				if(BMPlayer.OnGround && CanAccelerate) { MaxAirSpeed += dsk_acceleration * ActualSpeed; }
				MaxAirSpeed = clamp(MaxAirSpeed, MaxGroundSpeed, zm_maxhopspeed);
			}
		}
		
		//Friction
		if(Vel.XY.Length() < 1.f)
			Vel.XY = (0, 0);
		else
			Vel.XY *= 0.8f;
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), MaxAirSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void DuskWaterMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional Inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.XY = (0, 0);
			Acceleration.Z = (cmd.buttons & BT_CROUCH ? -1 : 1) * (MaxGroundSpeed * 3.f / 40.f) * ActualSpeed;
		}
		else
		{
			Acceleration.XY = (MaxGroundSpeed * 3.f / 40.f) * SafeUnit2(Acceleration.XY);
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		if(WaterLevel == 2) { WaterVelZLimiter(); }
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DuskFlyMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional Inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.XY = (0, 0);
			Acceleration.Z = (cmd.buttons & BT_CROUCH ? -1 : 1) * (MaxGroundSpeed * 3.f / 20.f) * ActualSpeed;
		}
		else
		{
			Acceleration.XY = (MaxGroundSpeed * 3.f / 20.f) * SafeUnit2(Acceleration.XY);
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Sprite Animatiom
		PlayIdle();
	}
	
	//====================================
	// Quake
	
	void QuakeHandleMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(!BMPlayer.OnGround || (BMPlayer.OnGround && (((cmd.buttons & BT_JUMP) && !BlockJump) || DashNumber)))
		{
			QuakeAirMove();
			if(zm_ledgegrab) { LedgeGrabInitiator(); }
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			QuakeGroundMove();
			Grappled = False;
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void QuakeFriction(float StopSpeed, float Friction)
	{
		if(WaterLevel >= 2 || bNOGRAVITY)
		{
			if(Vel.Length() < 0.5f)
			{
				Vel.XY = (0, 0);
				return;
			}
		}
		else if(Vel.XY.Length() < 1.f)
		{
			Vel.XY = (0, 0);
			return;
		}
		
		if(FloorAngle >= 45 && BMPlayer.OnGround) //lower friction on steep slopes
		{
			StopSpeed *= 4;
			Friction /= 4;
		}
		
		Double Velocity = Vel.Length();
		Double Drop, Control;
		if(WaterLevel >= 2)
		{
			drop = Velocity * Friction / TICRATE; //very tight friction
		}
		else if(bNOGRAVITY)
		{
			drop = Velocity * Friction / TICRATE; //loose friction
		}
		else if(BMPlayer.OnGround)
		{
			if(!Pain)
			{
				Control = Velocity < StopSpeed ? zm_friction : Velocity;
				Drop = Control * Friction / TICRATE;
			}
		}
		
		Double NewVelocity = (Velocity - Drop <= 0 ? 0 : Velocity - Drop) / Velocity;
		if(WaterLevel >= 2 || bNOGRAVITY)
			Vel *= NewVelocity;
		else
			Vel.XY *= NewVelocity;
	}
	
	void QuakeAcceleration(Vector3 WishDir, Float WishSpeed, Float Accel)
	{
		Float CurrentSpeed = WishDir dot Vel;
		Float AddSpeed = WishSpeed - CurrentSpeed;
		if(AddSpeed <= 0) { return; }
		
		Float AccelerationSpeed = min(Accel * WishSpeed / TICRATE, AddSpeed);
		Vel += AccelerationSpeed * WishDir;
	}
	
	void QuakeGroundMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		
		//Friction
		QuakeFriction(MaxGroundSpeed, 6.f);
	
		//Acceleration
		QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), MaxGroundSpeed, Pain ? 1.f : 10.f / MoveFactor);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void QuakeAirMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		
		//Acceleration
		if(!ADashTargetSpeed)
		{
			if(!q_strafetype)
			{
				QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), MaxGroundSpeed, q_3airaccel);
			}
			else if(q_strafetype == 1)
			{
				QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), q_1airaccel, 106.f);
			}
			else
			{
				if(cmd.sidemove && !cmd.forwardmove && Vel.Length() >= MaxGroundSpeed)
					QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), q_1airaccel, 106.f);
				else
					QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), MaxGroundSpeed, q_3airaccel);
			}
			
			//Limiter
			Vel.XY = min(Vel.XY.Length(), zm_maxhopspeed) * SafeUnit2(Vel.XY);
		}
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void QuakeWaterMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1);
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		QuakeFriction(0, 2.f);
		
		//Acceleration
		Acceleration = (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		QuakeAcceleration(SafeUnit3(Acceleration), (MaxGroundSpeed * 3.f) / 5.f, 4.f / MoveFactor);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void QuakeFlyMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1);
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		QuakeFriction(0, 3.f);
		
		//Acceleration
		Acceleration = (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		QuakeAcceleration(SafeUnit3(Acceleration), (MaxGroundSpeed * 3.f) / 2.f, 8.f / MoveFactor);
		
		//Sprite Animatiom
		PlayIdle();
	}
	
	//====================================
	// UT
	
	void UTHandleMove()
	{
		if(!BMPlayer.OnGround || (BMPlayer.OnGround && DashNumber))
		{
			UTAirMove();
			if(zm_ledgegrab) { LedgeGrabInitiator(); }
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			UTGroundMove();
			Grappled = False;
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void UTFriction(Float BrakeFriction)
	{
		if(!Vel.XY.Length()) { return; }
		
		Float RemainingTime = 1.f / TICRATE;
		Float MaxTimeStep = 1.f / 33.f;
		
		while(RemainingTime >= 0.0002f) //value taken from UT4 source code
		{
			Float dt = min(MaxTimeStep, RemainingTime * 0.5f);
			RemainingTime -= dt;
			
			Vel.XY = Vel.XY - BrakeFriction * Vel.XY * dt ;
			
			if(Vel.XY.Length() <= 1.f)
			{
				Vel.XY = (0, 0);
				return;
			}
		}
	}
	
	void UTGroundMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Dash recovery
		if(DashCooler >= 13)
		{
			UTFriction(3.f * zm_friction); //stronger friction after landing from a dash/walldash
			BlockJump = True;
		}
		else
		{
			//Directional inputs
			Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
			Acceleration.XY = 200.f * SafeUnit2(Acceleration.XY) * AccelMulti() / zm_friction;
			
			//Friction
			if(Acceleration.XY.Length())
				Vel.XY = Vel.XY - (Vel.XY - Acceleration.XY * Vel.XY.Length()) / TICRATE;
			else
				UTFriction(1.5f * zm_friction); //this feels good
			
			//Acceleration
			Vel.XY += Acceleration.XY / TICRATE;
			
			//Limiter
			Vel.XY = min(Vel.XY.Length(), MaxGroundSpeed) * SafeUnit2(Vel.XY);
		}
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void UTAirMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		Acceleration.XY = 0.62f * SafeUnit2(Acceleration.XY);
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), MaxAirSpeed > MaxGroundSpeed ? MaxAirSpeed : MaxGroundSpeed) * SafeUnit2(Vel.XY);
			
		//Sprite Animation
		AirSpriteAnimation();
		
		//Reset speed cap
		if(Vel.XY.Length() <= MaxGroundSpeed) { MaxAirSpeed = Vel.XY.Length(); }
	}
	
	void UTWaterFlyFriction(Float BrakeFriction)
	{
		if(Vel.Length() < 1.f) { return; }
		
		Float RemainingTime = 1.f / TICRATE;
		Float MaxTimeStep = 1.f / 33.f;
		
		while(RemainingTime >= 0.0002f) //value taken from UT4 source code
		{
			Float dt = min(MaxTimeStep, RemainingTime * 0.5f);
			RemainingTime -= dt;
			
			Vel = Vel - BrakeFriction * Vel * dt;
			
			if(Vel.Length() <= 1.f)
			{
				Vel = (0, 0, 0);
				return;
			}
		}
	}
	
	void UTWaterMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		//XY
		Acceleration.XY = 10.f * SafeUnit2(Acceleration.XY) * AccelMulti();
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * 10.f * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		if(WaterLevel == 2) { WaterVelZLimiter(); }
		if(Acceleration.Length())
			Vel = Vel - (Vel - (RotateVector(Acceleration.XY, Angle), Acceleration.Z) * Vel.Length()) / TICRATE;
		else
			UTWaterFlyFriction(2.f);
			
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z) / TICRATE;
		
		//Limiter
		Vel = min(Vel.Length(), MaxGroundSpeed / 2.f) * SafeUnit3(Vel);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void UTFlyMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		//XY
		Acceleration.XY = 20.f * SafeUnit2(Acceleration.XY) * AccelMulti();
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * 20.f * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		if(Acceleration.Length())
			Vel = Vel - (Vel - (RotateVector(Acceleration.XY, Angle), Acceleration.Z) * Vel.Length()) / TICRATE;
		else
			UTWaterFlyFriction(2.f);
			
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z) / TICRATE;
		
		//Limiter
		Vel = min(Vel.Length(), (MaxGroundSpeed * 3.f) / 2.f) * SafeUnit3(Vel);
		
		// Sprite Animatiom
		PlayIdle();
	}
	
	//////////////////////////////////////////
	// Crouching							//
	//////////////////////////////////////////
	
	//====================================
	// Regular crouching
	
	Override void CheckCrouch(bool totallyfrozen)
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(cmd.buttons & BT_JUMP)
		{
			cmd.buttons &= ~BT_CROUCH;
		}
		
		if(BMPlayer.health > 0)
		{
			if(!totallyfrozen)
			{
				int crouchdir = BMPlayer.crouching;
				
				if(bNOGRAVITY || WaterLevel >= 2) //forcefully uncrouch when flying/swimming
					crouchdir = 1;
				else if(crouchdir == 0)
					crouchdir = (cmd.buttons & BT_CROUCH) ? -1 : 1;
				else if(cmd.buttons & BT_CROUCH)
					BMPlayer.crouching = 0;
				
				if(crouchdir == 1 && BMPlayer.crouchfactor < 1 && pos.Z + height < ceilingz)
					CrouchMove(1);
				else if(crouchdir == -1 && BMPlayer.crouchfactor > 0.5)
					CrouchMove(-1);
			}
		}
		else
		{
			BMPlayer.Uncrouch();
		}

		BMPlayer.crouchoffset = -(ViewHeight) * (1 - BMPlayer.crouchfactor);
	}
	
	Override void CrouchMove(int direction)
	{
		double defaultheight = FullHeight;
		double savedheight = Height;
		double crouchspeed = (CanCSlide && zm_crouchslide == 1 ? - 1.5 : direction) * CROUCHSPEED;
		double oldheight = BMPlayer.viewheight;

		BMPlayer.crouchdir = direction;
		BMPlayer.crouchfactor += crouchspeed;

		// check whether the move is ok
		Height  = defaultheight * BMPlayer.crouchfactor;
		if(!TryMove(Pos.XY, false, NULL))
		{
			Height = savedheight;
			if(direction > 0)
			{
				// doesn't fit
				BMPlayer.crouchfactor -= crouchspeed;
				return;
			}
		}
		Height = savedheight;

		BMPlayer.crouchfactor = clamp(BMPlayer.crouchfactor, 0.5, 1.);
		BMPlayer.viewheight = ViewHeight * BMPlayer.crouchfactor;
		BMPlayer.crouchviewdelta = BMPlayer.viewheight - ViewHeight;

		// Check for eyes going above/below fake floor due to crouching motion.
		CheckFakeFloorTriggers(pos.Z + oldheight, true);
	}
	
	//////////////////////////////////////////
	// Crouch Sliding
	
	void CSlideInitiator()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(WaterLevel >= 2 || bNOGRAVITY) // in the water or flying forbid attempting to start a slide
		{
			CSlideStartTime = 1;
			QSlideDuration = 0;
			A_StopSound(CHAN_BODY);
			return;
		}
		else if(BMPlayer.CrouchFactor == 1 && CSlideStartTime) // reallow attempting to slide after player stands back up
		{
			CSlideStartTime = 0;
			return;
		}
		else if(!BMPlayer.OnGround && zm_crouchslide == 2)
		{
			QSlideDuration = abs(Vel.Z) * zm_qslideduration;
		}
		
		if(BMPlayer.OnGround)
		{
			if(BMPlayer.CrouchFactor != 1 && !CSlideStartTime)
			{
				if(cmd.forwardmove || cmd.sidemove)
				{
					//Not enough space for a slide
					Double SlideAngle = Angle - VectorAngle(cmd.forwardmove, cmd.sidemove);
					MaximumSlideSpeed = min(zm_cslidestrength * MaxGroundSpeed, zm_maxhopspeed);
					if(!CheckMove(Pos.XY + MaximumSlideSpeed * AngleToVector(SlideAngle))) { return; }
					
					if(zm_crouchslide == 1)
					{
						CanCSlide = True;
						A_PlaySound("slide",CHAN_BODY);
						Vel.XY = MaximumSlideSpeed * AngleToVector(SlideAngle);
					}
					else if(QSlideDuration)
					{
						CanCSlide = True;
						MaximumSlideSpeed = Vel.XY.Length();
					}
				}
				
				CSlideStartTime = Level.MapTime;
			}
			else if(!CanCSlide)
			{
				QSlideDuration = 0;
			}
		}
	}
	
	void CSlideMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Value reset
		MaxAirSpeed = MaxGroundSpeed;
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		Acceleration.XY = 2.f * SafeUnit2(Acceleration.XY);
		
		//Friction if time has run out
		if(Level.MapTime > CSlideStartTime + zm_cslideduration)
		{
			Int FrictionDiv = abs(FloorZ - Pos.Z) > 16 ? 500 : 100;
			MaximumSlideSpeed *= 1 - Vel.XY.Length() / FrictionDiv;
		}
			
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Limiter
		Vel.XY = MaximumSlideSpeed * SafeUnit2(Vel.XY);
		
		//Sprite animation
		PlayIdle();
		
		///////////////////////////////////////////
		//Fun is over
		if(WaterLevel >= 2 || bNOGRAVITY || MaximumSlideSpeed <= MaxGroundSpeed || !CheckMove(Pos.XY + Vel.XY))
		{
			CSlideStartTime = 1;
			CanCSlide = False;
		}
	}
	
	void QSlideMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		A_PlaySound("WallSlide", CHAN_BODY, 0.5, True);
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = (cmd.forwardmove, - cmd.sidemove);
		
		//Friction
		QuakeFriction(MaxGroundSpeed, 6.f);
		
		//Acceleration
		Vector2 PreAccelVel = Vel.XY;
		QuakeAcceleration((RotateVector(SafeUnit2(Acceleration.XY), Angle), 0), max(MaximumSlideSpeed, MaxGroundSpeed), zm_qslideaccel);
		
		//Decrease slide duration depending on how tight turns are
		QSlideDuration--;
		Float SlideRemoveTime = SafeUnit2(PreAccelVel) dot SafeUnit2(Vel.XY);
		SlideRemoveTime = (SlideRemoveTime - 0.99) * 100;
		QSlideDuration -= 1 - SlideRemoveTime;
		
		//Sprite animation
		PlayIdle();
		
		//====================================
		//Fun is over
		if(QSlideDuration <= 0 || abs(FloorZ - Pos.Z) > 16 || !Acceleration.XY.Length() || BMPlayer.CrouchFactor == 1)
		{
			CSlideStartTime = QSlideDuration = CanCSlide = 0;
			A_StopSound(CHAN_BODY);
		}
	}
	
	//////////////////////////////////////
	// Dashing							//
	//////////////////////////////////////
	
	void DoubleTapCheck()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		Int	MaxTapTime = CVar.GetCVar("zm_maxtaptime", Player).GetInt();
		Int TapValue = (cmd.buttons & BT_FORWARD) + (cmd.buttons & BT_BACK) + (cmd.buttons & BT_MOVERIGHT) + (cmd.buttons & BT_MOVELEFT);
		Int	SecondTapValue;
		
		if(TapValue & ~OldTapValue)
		{
			if(!FirstTapValue)
			{
				FirstTapTime = Level.MapTime;
				FirstTapValue = TapValue;
			}
			else
			{
				if(TapValue != FirstTapValue)
				{
					FirstTapTime = FirstTapValue = 0;
				}
				else
				{
					SecondTapValue = TapValue;
				}
			}
		}
		
		if((FirstTapValue && SecondTapValue) || Level.Maptime > FirstTapTime + MaxTapTime)
		{
			if(SecondTapValue && Level.MapTime <= FirstTapTime + MaxTapTime) { DashInitiator(); }
			FirstTapValue = FirstTapTime = 0;
		}
		
		OldTapValue = TapValue;
	}
	
	void DashInitiator()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(WaterLevel >= 2 || bNOGRAVITY || BMPlayer.CrouchFactor != 1 || LedgeGrabbed || CeilingZ - FloorZ <= Height )
		{
			CheckForWJump = 0;
			Return;
		}
			
		///////////////////////////////////////////////////////
		
		//Ground Dash
		if(zm_dash && BMPlayer.OnGround && !((cmd.buttons & BT_JUMP) & !BlockJump) && !DashCooler && (cmd.sidemove || cmd.forwardmove) && !CheckForWJump && !BlockJump)
		{
			Vector2 ProjectedVelXY = zm_dashboost * MaxGroundSpeed * AngleToVector(Angle - VectorAngle(cmd.forwardmove , cmd.sidemove));
			if(CheckMove(Pos.XY + ProjectedVelXY)) { Dash(ProjectedVelXY); }
			return;
		}
		
		if(ADashCooler) { return; }
		
		//Wall Jump
		if(!BMPlayer.OnGround && zm_wjump)
		{
			if(!CheckForWJump)
			{
				CheckForWJump = 6;
				if(!WJumpSpeed) { WJumpSpeed = Vel.XY.Length(); } //this little trick helps make it feel much better
			}
			else
			{
				CheckForWJump--;
			}
			
			if(cmd.sidemove || cmd.forwardmove)
			{
				//Wall proximity check
				FLineTraceData WallCheck;
				Double WallAngle, WallDistance;
				Float DistanceCheck = Radius + 16;
				
				for(int w = 0; w < 8; w++)
				{
					LineTrace(w * 45, DistanceCheck, 0, 0, data: WallCheck);
					
					if(WallCheck.Distance < DistanceCheck)
					{
						if((!WallDistance || WallCheck.Distance <= WallDistance) && WallCheck.HitType == TRACE_HitWall) //Check for the minimum distance
						{
							WallDistance = WallCheck.Distance;
							WallAngle = VectorAngle(WallCheck.HitLine.Delta.X, WallCheck.HitLine.Delta.Y);
						}
					}
				}
				
				if(WallDistance)
				{
					//Check player is moving away from the wall
					Double WJumpAngle = Angle - VectorAngle(cmd.forwardmove, cmd.sidemove);
					Float DirDelta = AbsAngle(WallAngle, WJumpAngle);
					if(DirDelta > 90) { DirDelta = 180 - DirDelta; }
					
					if(DirDelta > 5)
					{
						//No obstacles near player check
						Float EstimatedWJumpSpeed1 = zm_wjumpboost * MaxGroundSpeed;
						Float EstimatedWJumpSpeed2 = zm_multipledashes + max(WJumpSpeed, Vel.XY.Length());
						WJumpSpeed = min(max(EstimatedWJumpSpeed1, EstimatedWJumpSpeed2), zm_maxhopspeed);
						Vector2 WJumpVector = WJumpSpeed * AngleToVector(WJumpAngle);
						
						if(CheckMove(Pos.XY + WJumpVector))
						{
							CheckForWJump = 0;
							WallJump(WJumpVector);
							return;
						}
						else
						{
							CheckForWJump = 0;
						}
					}
				}				
			}
		}
		else
		{
			CheckForWJump = 0;
		}
		
		//Air Dash
		if(zm_airdash && !BMPlayer.OnGround && (cmd.sidemove || cmd.forwardmove) && !ADashTargetSpeed)
		{
			Vector2 ADashVector;
			if(Vel.XY.Length() <= MaxGroundSpeed)
			{
				ADashVector = (MaxGroundSpeed + zm_adashboost) * AngleToVector(Angle - VectorAngle(cmd.forwardmove , cmd.sidemove));		
				if(CheckMove(Pos.XY + ADashVector))
				{
					AirDash(ADashVector);
					return;	
				}
			}
			else
			{
				ADashVector = zm_adashboost * AngleToVector(Angle - VectorAngle(cmd.forwardmove , cmd.sidemove));
				if(CheckMove(Pos.XY + Vel.XY + ADashVector))
				{
					AirDash(ADashVector);
					return;	
				}
			}
		}
	}
	
	void DashCommon()
	{
		DashCooler = 102;
		DoubleJumpCooler = 5;
		bONMOBJ = False;
		Jumped = True;
	}
	
	void Dash(Vector2 DashVector)
	{
		Usercmd cmd = BMPlayer.cmd;
		
		if(DashNumber > 3) { return; }
		DashNumber++;
		DashCommon();
		ADashCooler = 8;
		
		Float DashVelZ = zm_jumpheight * zm_dashheight + ElevatorJumpBoost;
		Float JumpFac = GetPowerJump();
		if(JumpFac) { DashVelZ *= JumpFac; }
		Vel.Z = DashVelZ;
		
		if(!(BMPlayer.cheats & CF_PREDICTING)) { A_PlaySound("*jump", CHAN_BODY); }
		
		Vel.XY = DashVector;
		MaxAirSpeed = min(Vel.XY.Length(), zm_maxhopspeed);
	}
	
	void AirDash(Vector2 ADashVector)
	{
		Usercmd cmd = BMPlayer.cmd;
		
		DashNumber++;
		DashCommon();
		ADashCooler = 53;
		
		if(!(BMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler) { A_PlaySound("*jump", CHAN_BODY); }
		
		if(Vel.XY.Length() <= MaxGroundSpeed)
		{
			Vel.XY = ADashVector; //this way the air dash always grants a satisfying boost
			ADashTargetSpeed = MaxGroundSpeed + (MoveType == 2 || MoveType == 3 || MoveType == 4 ? (Vel.XY.Length() - MaxGroundSpeed) / 4 : 0);
			ADashFrictionDelay = 8;
		}
		else
		{
			Float PreAirDashSpeed = Vel.XY.Length();
			Vel.XY += ADashVector;
			
			ADashTargetSpeed = min(PreAirDashSpeed + (MoveType == 2 || MoveType == 3 || MoveType == 4 ? (Vel.XY.Length() - PreAirDashSpeed) / 4 : 0), zm_maxhopspeed);
			
			//if going above the speed limit your speed will start decaying immediately
			Float Velocity = Vel.XY.Length();
			if(Velocity > PreAirDashSpeed && Velocity <= zm_maxhopspeed) { ADashFrictionDelay = 8; }
		}
			
		MaxAirSpeed = Vel.XY.Length();
	}
	
	void AirDashFriction()
	{
		if(!ADashFrictionDelay)
		{
			if(Vel.XY.Length() > ADashTargetSpeed)
			{
				Vel.XY *= 1 - Vel.Length() / (1000 * zm_adashfriction); //just like in real life air friction is proportional to the speed
				MaxAirSpeed = Vel.XY.Length();
			}
			else
			{
				MaxAirSpeed = ADashTargetSpeed;
				ADashTargetSpeed = 0;
			}
		}
		else
		{
			ADashFrictionDelay--;
		}
	}
	
	void WallJump(Vector2 WJumpVector)
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//Stop any eventual WallSlideMove
		StopWSlide();
		
		DashNumber++;
		DashCommon();
		ADashCooler = 8;
		if(DashNumber <= 3)
		{
			Float DashVelZ = zm_jumpheight * zm_dashheight;
			Float JumpFac = GetPowerJump();
			if(JumpFac) { DashVelZ *= JumpFac; }
			Vel.Z = DashVelZ;
		}
		
		if(zm_wjdoublejumprenew) { CanDoubleJump = True; }
		if(!(BMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler) { A_PlaySound("*jump", CHAN_BODY); }
		
		Vel.XY = WJumpVector;
		MaxAirSpeed = min(Vel.XY.Length(), zm_maxhopspeed);
	}
	
	//////////////////////////////////////
	// Wall Slide				 		//
	//////////////////////////////////////
	
	void WallSlideInitiator()
	{
		if(BMPlayer.OnGround || WaterLevel >= 2 || bNOGRAVITY || LedgeGrabbed)
		{
			CheckForWSlide = 0;
			return;
		}
		else if(!CheckForWSlide)
		{
			CheckForWSlide = 24;
		}
		
		CheckForWSlide--;
		
		FLineTraceData DirTrace;
		Int SlideAngleDelta;
		
		if(!WSlideVelocity.Length())
		{
			LineTrace(VectorAngle(Vel.X, Vel.Y), 100, 0, 0, data: DirTrace);
			if(DirTrace.Distance < 100 && DirTrace.HitType == TRACE_HitWall) { WSlideVelocity = Vel.XY; }
		}
		else
		{
			SlideAngleDelta = AbsAngle(VectorAngle(WSlideVelocity.X, WSlideVelocity.Y), VectorAngle(Vel.X, Vel.Y));
		}
		
		if(SlideAngleDelta && SlideAngleDelta <= 45)
		{
			WSlideVelocity =  WSlideVelocity.Length() * SafeUnit2(Vel.XY);
			Vel.XY = WSlideVelocity;
			CanWSlide = True;
			CheckForWSlide = 0;
			return;
		}
	}
	
	void WallSlideMove()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		//====================================================
		//Dumb ways to fail...so many don't waste your time
		
		//Common reasons of failure
		if(!WaterLevel >= 2 || bNOGRAVITY || BMPlayer.OnGround || (!cmd.forwardmove && !cmd.sidemove))
		{
			StopWSlide();
			return;
		}
		
		//WallCheck
		Float WallDistance;
		FLineTraceData SlideWallCheck;
		Int i;
		for(i = 0; i < 8; i++)
		{
			LineTrace(i * 45, (Radius * 3) / 2, 0, 0, data: SlideWallCheck);
			if(!WallDistance || SlideWallCheck.Distance <= WallDistance) { WallDistance = SlideWallCheck.Distance; }
		}
		if(WallDistance >= (Radius * 3) / 2)
		{
			StopWSlide();
			return;
		}
		
		//Moving away from wall
		Float WishDirection = Angle - VectorAngle(cmd.forwardmove, cmd.sidemove);
		Float VelAngle = VectorAngle(Vel.X, Vel.Y);
		Float DirAngle = AbsAngle(WishDirection, VelAngle);
		if(DirAngle >= 30)
		{
			StopWSlide();
			return;
		}
		
		//Wall changed angle, adjust slide velocity
		Int SlideAngleDelta = AbsAngle(VectorAngle(WSlideVelocity.X, WSlideVelocity.Y), VelAngle);
		if(SlideAngleDelta && SlideAngleDelta <= 30)
		{
			WSlideVelocity = WSlideVelocity.Length() * SafeUnit2(Vel.XY);
			Vel.XY = WSlideVelocity; //needed to not make velocity check fail
		}
		else if(SlideAngleDelta > 30)
		{
			StopWSlide();
			return;
		}
		
		//Too slow
		if(Vel.XY.Length() < MaxGroundSpeed)
		{
			StopWSlide();
			return;
		}
		
		//==============================================
		
		Vel.XY = WSlideVelocity;
		Vel.Z *= zm_wslidevelz;
		A_PlaySound("WallSlide", CHAN_BODY, 0.3, True);
		
		//Sprite animation
		PlayIdle();
	}
	
	void StopWSlide()
	{
		CanWSlide = False;
		WSlideVelocity = (0, 0);
		A_StopSound(CHAN_BODY);
	}
	
	//////////////////////////////////////
	// Ledge Grab						//
	//////////////////////////////////////
	
	void LedgeGrabInitiator()
	{
		//Already ledge grabbing, no clipping, moving away from where you are looking, ceiling already too low for sure
		if(LedgeGrabbed || (BMPlayer.Cheats & CF_NOCLIP2) || Vel.XY dot AngleToVector(Angle) <= 0 || CeilingZ <= Pos.Z + Height * 1.6f) { return; }
		
		//============================================
		//Find ledge (if any)						//
		//============================================
		
		FLineTraceData LedgeTrace;
		Float TraceDistance = sqrt(2) * Radius + 1; //account for the fact that Doom's hitboxes are square
		LineTrace(Angle, TraceDistance, 0, TRF_BLOCKSELF|TRF_THRUACTORS, Height * 1.2f, data: LedgeTrace);
		Vector3 HitPos = LedgeTrace.HitLocation;
		
		Int LedgeCandidate;
		if(LedgeTrace.HitType == TRACE_HitWall) //hit wall scenario
		{
			if(LedgeTrace.Hit3DFloor != NULL) //3D floor
			{
				LedgeCandidate = LedgeTrace.Hit3DFloor.Top.ZAtPoint(HitPos.XY);
			}
			else //regular wall
			{
				Line HitLine = LedgeTrace.HitLine;
				if(HitLine.FrontSector != NULL && HitLine.FrontSector != CurSector)
					LedgeCandidate = HitLine.FrontSector.FloorPlane.ZatPoint(HitPos.XY);
				else if(HitLine.BackSector != NULL && HitLine.BackSector != CurSector)
					LedgeCandidate = HitLine.BackSector.FloorPlane.ZatPoint(HitPos.XY);
			}
		}
		else if(LedgeTrace.HitSector != CurSector)//tracer stopper mid air in a sector that is not the one where player currently is
		{
			LedgeCandidate = LedgeTrace.HitSector.NextLowestFloorAt(HitPos.X, HitPos.Y, HitPos.Z, FFCF_3DRESTRICT, 0);
		}
		else
		{
			return;
		}
		
		//Check if the candidate ledge can suffice
		if(LedgeCandidate > Pos.Z + Height * 0.6f && LedgeCandidate <= Pos.Z + Height * 1.2f)
		{	
			Vector3 OrigPos = Pos;
			SetXYZ((Pos.XY, LedgeCandidate));
			if(!CheckMove(Pos.XY + 5.f * AngleToVector(Angle))) //not enough space, cancel everything :(
			{
				SetXYZ(OrigPos);
				return;
			}
			SetXYZ(OrigPos);
			LedgeHeight = LedgeCandidate;
		}
		else
		{
			return; //too high/low
		}
		
		//============================================
		//Abemus ledge, execute						//
		//============================================
		
		//Switch to a weapon that forbids firing during the ledge grab
		ReselectWeapon = BMPlayer.ReadyWeapon;
		GiveInventory("LedgeGrabWeapon", 1);
		BMPlayer.ReadyWeapon = Null;
		Let AssignWeapon = LedgeGrabWeapon(FindInventory("LedgeGrabWeapon"));
		BMPlayer.PendingWeapon = AssignWeapon;
		
		//Reset dash stuff just in case
		MaxAirSpeed = ADashTargetSpeed;
		DashCooler = ADashCooler = ADashTargetSpeed = WJumpSpeed = DashNumber = 0;
		
		//Allow ledge grab
		A_StopSound(CHAN_WEAPON); 	//stop looping weapon sounds
		StopHook();					//stop hook, not needed but just in case
		LedgeAngle = Angle;
		A_PlaySound("Climb", CHAN_BODY);
		LedgeGrabbed = True;
	}
	
	void LedgeGrab()
	{
		LedgeTime++;
		if(Pos.Z >= LedgeHeight || !Vel.Length() || LedgeTime >= 35)
		{
			//End Ledge Grab
			BMPlayer.PendingWeapon = ReselectWeapon;
			TakeInventory("LedgeGrabWeapon", 1);
			LedgeGrabbed = LedgeTime = LedgeHeight = 0;
			//Only if ledge grab was successful
			if(LedgeTime >= 35) { return; }
			Vel = Vel.Length() ? (5.f * AngleToVector(LedgeAngle), -3) : (0, 0, 0); //push player forward and downward
			A_PlaySound("*land", CHAN_BODY);
		}
		else
		{
			Vel = Vel.Length() ? (0, 0, 8) : (0, 0, 0);
		}
		
		//Sprite animation
		PlayIdle();
	}
	
	//////////////////////////////////////
	// Grappling Hook					//
	//////////////////////////////////////
	
	void FireHook()
	{
		//Heavy metal music stops
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Third click, detach hook
		if(PendulumLength || (GrappleVel.Length() && zm_hook == 1))
		{
			StopHook();
			return;
		}
		
		//Second click, activate pendulum physics
		if(GrappleVel.Length() && zm_hook == 2)
		{
			Float RopePitch = atan2(Rope.XY.Length(), Rope.Z);
			//Trust me, it's better if you do not see what happens otherwise
			if(RopePitch >= 90.f)
			{
				StopHook();
				return;
			}
			//Initiate pendulum
			PendulumLength = Rope.Length();
			RopePitch *= (Vel.Z < 0 ? -1 : 1);
			Float SwingPitch = RopePitch + 90;
			Float SwingAngle = VectorAngle(Vel.X, Vel.Y);
			Vel = GrappleVel.Length() * (sin(SwingPitch) * cos(SwingAngle), sin(SwingPitch) * sin(SwingAngle), cos(SwingPitch));
			GrappleVel = Vel;
			return;
		}
		
		//First click, fire hook
		if(HookFired || Grappled) { return; }
		A_PlaySound("HookLaunch", 7, 0.8);
		//Why actor projectile firing functions do not have a pitch parameter?
		FLineTraceData CrossHairProjection; LineTrace(Angle, 10000, Pitch, 0, BMPlayer.ViewHeight, data: CrossHairProjection);
		Float PitchOffset = VectorAngle(CrossHairProjection.Distance, -AttackZOffset);
		Pitch += PitchOffset;
		HookFired = SpawnPlayerMissile("Hook", Angle, 0, 0, -AttackZOffset); //SpawnPlayerMissile fires a projectile at 8/14 of Player Height, I need it to be fired at half
		Pitch -= PitchOffset;
		//Set hook to move faster the faster player is moving
		HookFired.Vel += Vel;
	}
	
	bool HookLOS()
	{
		Float LOSPitch = atan2(Rope.XY.Length(), Rope.Z) - 90;
		Float LOSAngle = VectorAngle(Rope.X, Rope.Y);
		FLineTraceData LOSCheck; LineTrace(LOSAngle, Rope.Length(), LOSPitch, TRF_SOLIDACTORS|TRF_BLOCKSELF, Height / 2.f, data: LOSCheck);
		
		if(GrappledMonster != Null && LOSCheck.HitActor == GrappledMonster) { return true; }
		
		return LOSCheck.Distance == Rope.Length();
	}
	
	void GrapplingMove()
	{
		if(!BMPlayer.OnGround) { Grappled = True; }
		
		//Fun is over kids, go home
		if((BMPlayer.OnGround && Grappled) || WaterLevel >= 2 || bNOGRAVITY || Rope.Length() <= 4.f * Radius || !CheckMove(Pos.XY + Vel.XY) || !HookLOS())
		{
			StopHook();
			return;
		}
		
		//All good
		if(PendulumLength)
		{
			//Reached the peak
			Float RopePitch = atan2(Rope.XY.Length(), Rope.Z);
			if(RopePitch >= 90)
			{
				StopHook();
				return;
			}
			
			Vector3 SwingVel;
			if(Vel.Z < 0)
			{
				SwingVel = (GrappleVel.X, GrappleVel.Y, GrappleVel.Z - zm_setgravity);
			}
			else
			{
				SwingVel = (GrappleVel.X, GrappleVel.Y, GrappleVel.Z - zm_setgravity / 2.f);
				RopePitch *= -1;
			}
			Float SwingPitch = RopePitch + 90;
			Float SwingAngle = VectorAngle(Vel.X, Vel.Y);
			Vel = SwingVel.Length() * (sin(SwingPitch) * cos(SwingAngle), sin(SwingPitch) * sin(SwingAngle), cos(SwingPitch));
			
			//Rope tension
			Float Tension = Rope.Length() - PendulumLength;
			if(Tension) { Vel += Tension * SafeUnit3(Rope); }
			
			//Limiter
			MaxAirSpeed = min(Vel.XY.Length(), zm_maxhopspeed);
			Vel.XY = MaxAirSpeed * SafeUnit2(Vel.XY);
			
			GrappleVel = Vel;
		}
		else
		{
			GrappleVel = SafeUnit3(Rope) * GrappleVel.Length();
			Vel = GrappleVel;
		}
		
		//Sprite animation
		PlayIdle();
	}
	
	void StopHook()
	{
		Rope = GrappleVel = (0, 0, 0);
		PendulumLength = 0;
		GrappledMonster = Null;
	}
	
	//////////////////////////////////////
	// Bobbing							//
	//////////////////////////////////////
	
	void BobWeaponAuxiliary()
	{
		Usercmd cmd = BMPlayer.cmd;
		
		Float Velocity = min(Vel.XY.Length(), zm_maxgroundspeed);
		Bool  InTheAirNoOffset = CanWSlide || CanCSlide || GrappleVel.Length() || bNOGRAVITY || WaterLevel >= 2;
		Bool  InTheAir = Jumped || abs(FloorZ - Pos.Z) > 16 || InTheAirNoOffset || (MoveType == 5 && DashCooler > 13 && DashCooler <= 100);
		
		//////////////////////////////////////////
		//Bobbing counter						//
		/////////////////////////////////////////
		
		DoBob = (cmd.forwardmove || cmd.sidemove) && Velocity > 1.f && !InTheAir && !VerticalOffset;
		if(DoBob || BobRange)
			BobTime += Velocity / zm_maxgroundspeed;
		else
			BobTime = 0;
		
		//////////////////////////////////////////
		//Horizontal sway and Vertical offset	//
		//////////////////////////////////////////
		
		Let PWeapon = BMPlayer.ReadyWeapon;
		if(PWeapon == Null || PWeapon.bDontBob || !(BMPlayer.WeaponState & WF_WEAPONBOBBING))
		{
			HorizontalSway = VerticalOffset = 0;
			return;
		}
		
		Let WeaponSprite = BMPlayer.PSprites;
		if(WeaponSprite == Null) { return; }
		
		//=========================================
		//Horizontal Sway
		
		if(CVar.GetCVar("zm_sway", Player).GetBool())
		{
			HorizontalSway += (CVar.GetCVar("zm_swaydirection", Player).GetBool() ? -1 : 1) *
						       ViewAngleDelta * CVar.GetCVar("zm_swayspeed", Player).GetFloat() / 10;
			Int SwayRange = CVar.GetCVar("zm_swayrange", Player).GetInt();
			HorizontalSway = clamp(HorizontalSway, -SwayRange, SwayRange);
			
			if(HorizontalSway)
			{
				Float Realign = min(abs(HorizontalSway), SwayRange - 1);
				HorizontalSway *= Realign / SwayRange * (abs(HorizontalSway) > BOB_MIN_REALIGN);
			}
			
			WeaponSprite.X = HorizontalSway;
		}
		
		//=========================================
		//Vertical offset
		
		if(CVar.GetCVar("zm_offset", Player).GetBool())
		{
			Int	OffsetRange = CVar.GetCVar("zm_offsetrange", Player).GetInt();
			
			if(InTheAir && !InTheAirNoOffset)
			{
				Float OffsetSpeed = CVar.GetCVar("zm_offsetspeed", Player).GetFloat();
				
				if(!CVar.GetCVar("zm_offsetdirection", Player).GetBool())
				{
					if(Vel.Z >= 0)
						VerticalOffset += OffsetSpeed * Vel.Z * (1. - abs(VerticalOffset) / OffsetRange);
					else
						VerticalOffset += OffsetSpeed * Vel.Z * max(abs(VerticalOffset) / OffsetRange, 1);
				}
				else
				{
					if(Vel.Z >= 0)
						VerticalOffset -= OffsetSpeed * Vel.Z * max(abs(VerticalOffset) / OffsetRange, 1);
					else
						VerticalOffset -= OffsetSpeed * Vel.Z * (1. - abs(VerticalOffset) / OffsetRange);
				}
				VerticalOffset = clamp(VerticalOffset, 0, OffsetRange);
			}
			else if(VerticalOffset)
			{
				Float Realign = min(abs(VerticalOffset), OffsetRange - 1);
				VerticalOffset *= Realign / OffsetRange * (abs(VerticalOffset) > BOB_MIN_REALIGN);
			}
			
			WeaponSprite.Y = VerticalOffset + 32;
		}
	}
	
	void GetBobMulti(double ticfrac) //bobbing range and smooth transitioning
	{
		if(DoBob)
		{
			Double BobRangeCandidate = zm_maxgroundspeed * MoveFactor;
			if(BobRangeCandidate == BobRange) { return; }
			
			if(BobRangeCandidate > BobRange)
				BobRange = min(BobRange + abs(OldTicFrac - ticfrac) * abs(BobRangeCandidate - BobRange) / zm_maxgroundspeed, BobRangeCandidate); //make transitions proportional to frame time for fps consistency
			else
				BobRange = max(BobRange - abs(OldTicFrac - ticfrac) * abs(BobRangeCandidate - BobRange) / zm_maxgroundspeed, BobRangeCandidate); //and make the transition proportional to the value difference
		}
		else if(BobRange)
		{
			BobRange = max(BobRange - abs(OldTicFrac - ticfrac), 0);
		}
		OldTicFrac = ticfrac;
	}
	
	Override Vector2 BobWeapon(double ticfrac)
	{
		if(!BMPlayer) { return (0, 0); }
		
		let weapon = BMPlayer.ReadyWeapon;
		if(weapon == null) { return (0, 0); }
		
		Vector2 r;
		GetBobMulti(ticfrac);
		int bobstyle = weapon.BobStyle;
		double RangeY = weapon.BobRangeY;
		if(weapon.bDontBob || !BobRange || !(BMPlayer.WeaponState & WF_WEAPONBOBBING)) //I should add a variable to do this very cleanly but I don't wanna
		{
			BobRange = BobTime = 0;
			switch(bobstyle)
			{
			case Bob_Dusk:
				r.Y = zm_maxgroundspeed * RangeY;
				break;
					
			case Bob_UT:
				r.Y = zm_maxgroundspeed * RangeY;
			}
			return r;
		}
		
		double BobSpeed = weapon.BobSpeed * 128;
		double bobx = weapon.BobRangeX * BobRange;
		double boby = RangeY * BobRange;
		Vector2 p1, p2;
		
		for(int i = 0; i < 2; i++)
		{
			double BobAngle = BobSpeed * BMPlayer.GetWBobSpeed() * (BobTime + i - 1) * (360. / 8192.);
			
			switch(bobstyle)
			{
			case Bob_Normal:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * abs(sin(BobAngle));
				break;
			
			case Bob_Inverse:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * (1. - abs(sin(BobAngle)));
				break;
				
			case Bob_Alpha:
				r.X = bobx * sin(BobAngle);
				r.Y = boby * abs(sin(BobAngle));
				break;
			
			case Bob_InverseAlpha:
				r.X = bobx * sin(BobAngle);
				r.Y = boby * (1. - abs(sin(BobAngle)));
				break;
			
			case Bob_Smooth:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * (1. - (cos(BobAngle * 2))) / 2.f;
				break;
			
			case Bob_InverseSmooth:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * (1. + (cos(BobAngle * 2))) / 2.f;
			
			case Bob_Build:
				r.X = 2. * bobx * cos(BobAngle);	
				r.Y = boby * (1. - abs(sin(BobAngle)));
				break;
			
			case Bob_Dusk:
				r.X = bobx * cos((BobAngle * 2.) / 3.);
				r.Y = boby * (cos(2.2 * BobAngle)) + zm_maxgroundspeed * RangeY;
				break;
							
			case Bob_UT:
				r.X = 1.5 * bobx * cos(BobAngle);	
				r.Y = boby * sin(2. * BobAngle) + zm_maxgroundspeed * RangeY;
			}
			
			if (i == 0) p1 = r; else p2 = r;
		}
		
		return p1 * (1. - ticfrac) + p2 * ticfrac;
	}
}

Class LedgeGrabWeapon : Weapon
{
	States
	{
		Select:
			TNT1 A 0 A_WeaponReady(WRF_NOFIRE|WRF_NOSWITCH);
			TNT1 A 0 A_Raise;
			Loop;
			
		Deselect:
			TNT1 A 0 A_WeaponReady(WRF_NOFIRE|WRF_NOSWITCH);
			TNT1 A 0 A_Lower;
			Loop;
			
		Ready:
			TNT1 A 1 A_WeaponReady(WRF_NOFIRE|WRF_NOSWITCH);
			Loop;
			
		Fire:
			TNT1 A 0 A_WeaponReady(WRF_NOFIRE|WRF_NOSWITCH);
			Stop;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
////																						////
//// Event Handlers																			////
////																						////
////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

Class SpeedoMeterHandler : EventHandler
{
	override void renderOverlay(RenderEvent e)
	{
		if(CVar.FindCVar("zm_speedometer").GetInt() && Level.MapName != "TITLEMAP")
		{
			Actor mo = players[consoleplayer].mo;
			if(mo != NULL && PlayerInGame[consoleplayer])
			{
				Int Value = (CVar.FindCVar("zm_speedometer").GetInt() == 2 ? 32 : 10) * mo.Vel.XY.Length();
				Int OffsetX = Confont.StringWidth(String.Format("%d", Value)) / 2;
				Int VScreenX = 768, VScreenY = 480;
				Screen.DrawText(Confont, Font.CR_WHITE, VScreenX / 2 - OffsetX, VScreenY / 2 + 16, String.format("%i", Value),
								DTA_VirtualWidth, VScreenX, DTA_VirtualHeight, VScreenY);
			}
		}
	}
}

Class DashHandler : EventHandler
{
    Override void NetworkProcess(ConsoleEvent e)
    {
        if(e.Player >= 0 && PlayerInGame[e.Player] && Players[e.Player].Mo)
        {
            if(e.Name == "Dash")
            {
                Let DashPlayer = BMovePlayer(Players[e.Player].Mo);
                if(DashPlayer) { DashPlayer.DashInitiator(); }
            }
        }
    }
}

Class WallSlideHandler : EventHandler
{
    Override void NetworkProcess(ConsoleEvent e)
    {
		if(!zm_wslide) { return; }
		
        if(e.Player >= 0 && PlayerInGame[e.Player] && Players[e.Player].Mo)
        {
            if(e.Name == "WallSlide")
            {
                Let WSlidePlayer = BMovePlayer(Players[e.Player].Mo);
                if(WSlidePlayer) { WSlidePlayer.WallSlideInitiator(); }
            }
        }
    }
}

Class GrapplingHookHandler : EventHandler
{
    Override void NetworkProcess(ConsoleEvent e)
    {
		if(!zm_hook) { return; }
		
        if(e.Player >= 0 && PlayerInGame[e.Player] && Players[e.Player].Mo)
        {
            if(e.Name == "GrapplingHook")
            {
                Let GrapplingPlayer = BMovePlayer(Players[e.Player].Mo);
                if(GrapplingPlayer) { GrapplingPlayer.FireHook(); }
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
////																						////
//// GrapplingHook																			////
////																						////
////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

Class Hook : Actor
{
	Default
	{
		+FORCEXYBILLBOARD;
		+HITMASTER;
		+MISSILE;
		//+NOALERT;
		+NOGRAVITY;
		+NOTELEPORT;
		+NOTONAUTOMAP;
		+THRUSPECIES;
		Damage 6;
		Height 4;
		Radius 2;
		Speed 80;
		Species "Hook";
	}
	
	vector3 HookToPlayer;
	vector3	HookToMonster;
	int		MonsterSpeed;
	int		MonsterFloatSpeed;
	
	vector3 SafeUnit3(Vector3 VecToUnit)
	{
		if(VecToUnit.Length()) { VecToUnit /= VecToUnit.Length(); }
		return VecToUnit;
	}
	
	vector2 SafeUnit2(Vector2 VecToUnit)
	{
		if(VecToUnit.Length()) { VecToUnit /= VecToUnit.Length(); }
		return VecToUnit;
	}
	
	Override void Tick()
	{
		Let HookOwner = BMovePlayer(Target);
		if(HookOwner)
		{
			Vector3 WaistPos = (HookOwner.Pos.X, HookOwner.Pos.Y, HookOwner.Pos.Z + HookOwner.Height / 2.f); // player position
			HookToPlayer = Pos - WaistPos; //hook-to-player vector
		}
		
		Super.Tick();
		
		UpdateTrail();
	}
	
	void UpdateTrail()
	{
		int b;
		for(b = 1; b <= 14; b++)
		{
			ActorIterator BallOfSteele = Level.CreateActorIterator(84115 + b);
			Actor Ball = BallOfSteele.Next();
			
			if(Ball != Null)
			{
				//Set trail velocity
				Vector3 TargetPos = Pos - (HookToPlayer * b / 15.f);
				Ball.Vel = TargetPos - Ball.Pos;
			}
		}
	}
	
	void InitiateGrapple(Bool Monster)
	{
		Let HookOwner = BMovePlayer(Target);
		
		Float	PushLength = HookOwner.MaxGroundSpeed * zm_hookboost;
		Vector3 HookPush = SafeUnit3(HookToPlayer) * PushLength;
		Float 	HookSpeed = max((HookOwner.Vel + HookPush).Length(), PushLength);
		HookOwner.Rope = HookToPlayer; //needed for the LOS check
		
		//Check hook is still in sight
		if(!HookOwner.HookLOS())
		{
			SetState(FindState("DespawnHook"));
			return;
		}
		
		//Stop any eventual wall slides
		HookOwner.StopWSlide();
		
		//Stop dashing stuff
		HookOwner.ADashCooler = HookOwner.ADashTargetSpeed = 0;
		
		//Initiate hook
		HookSpeed = HookOwner.MaxAirSpeed = min(HookSpeed, zm_maxhopspeed);
		HookOwner.Vel = HookOwner.GrappleVel = HookSpeed * SafeUnit3(HookPush);
		
		//Hooking monsters specific
		if(Monster)
		{
			Let Monster = Actor(Master);
			BMovePlayer(Target).GrappledMonster = Monster;
			SetMonsterSpeed(False);
			A_PlaySound("HookMeat", 7);
		}
		else
		{
			A_PlaySound("HookWall", 7);
		}
	}
	
	void SetMonsterSpeed(Bool Reset)
	{
		Let Monster = Actor(Master);
		
		if(!Reset)
		{
			MonsterSpeed = Monster.Speed;
			MonsterFloatSpeed = Monster.FloatSpeed;
			Monster.Speed = Monster.FloatSpeed = 0;
		}
		else
		{
			Monster.Speed = MonsterSpeed;
			Monster.FloatSpeed = MonsterFloatSpeed;
		}
	}
	
	void SpawnTrail()
	{
		int h;
		for(h = 1; h <= 14; h++)
		{
			A_SpawnItemEx("HookTrail",0,0,0,0,0,0,0,SXF_ISTRACER|SXF_SETTARGET|SXF_ORIGINATOR|SXF_NOCHECKPOSITION);
			
			Let SlaveTrail = HookTrail(Tracer);
			SlaveTrail.ChangeTid(84115 + h);
		}
	}
	
	States
	{
	//====================================
	//Hook is traveling through space
	Spawn:
		OCLW A 0 NoDelay
		{
			//A_AlertMonsters();
			SpawnTrail();
		}
	Looper:
		OCLW A 1
		{
			Let HookOwner = BMovePlayer(Target);
			//Despawn if no geometry was found
			if(HookToPlayer.Length() >= 1000.f || !HookOwner)
			{
				SetState(FindState("DespawnHook"));
				return;
			}
		}
		Loop;
	
	//====================================
	//Hook hit a wall or ceiling
	Death:
		OCLW A 0
		{
			Let HookOwner = BMovePlayer(Target);
			if(!HookOwner)
			{
				SetState(FindState("DespawnHook"));
				return;
			}
			
			InitiateGrapple(False);
		}
	
	TillDeathDoesUsApart:
		OCLW A 1
		{
			Let HookOwner = BMovePlayer(Target);
			if(!HookOwner.GrappleVel.Length() || !HookOwner)
			{
				SetState(FindState("DespawnHook"));
				return;
			}
			
			HookOwner.Rope = HookToPlayer;
		}
		Loop;
		
	//====================================
	//Hit actor
	XDeath:
		OCLW A 0
		{
			Let Monster = Actor(Master);
			if(!Monster.bISMONSTER)
			{
				SetState(FindState("DespawnHook"));
				return;
			}
			
			InitiateGrapple(True);
		}
	
	TillXDeathDoesUsApart:
		OCLW A 1
		{
			Let HookOwner = BMovePlayer(Target);
			Let Monster = Actor(Master);
			
			if(!HookOwner.GrappleVel.Length() || !HookOwner || Monster.Health <= 0)
			{
				SetState(FindState("DespawnHook"));
				return;
			}
			
			Vel = Monster.Vel;
			HookOwner.Rope = HookToPlayer;
		}
		Loop;
		
	//====================================
	//Die Monster! You don't belong in this world
	DespawnHook:
		OCLW A 0
		{
			Let HookOwner = BMovePlayer(Target);
			if(HookOwner)
			{
				HookOwner.StopHook();
				HookOwner.A_PlaySound("HookFailed", 7, 0.2);
			}
			
			Let Monster = Actor(Master);
			if(Monster && MonsterSpeed) { SetMonsterSpeed(True); }
		}
		Stop;
	}
}

Class HookTrail : Actor
{
	Default
	{
		+FORCEXYBILLBOARD;
		+MISSILE;
		+NOGRAVITY;
		+NOTELEPORT;
		+NOTONAUTOMAP;
		+THRUSPECIES;
		Radius 2;
		Height 4;
		Scale 0.5;
		Species "HookTrail";
	}
	
	States
	{
		Spawn:
		Looper:
			TEND A 1
			{
				if(!Hook(Target))
				{
					SetState(FindState("DespawnTrail"));
					return;
				}
			}
			Loop;
			
		Death:
			TEND A 1
			{
				if(!Hook(Target))
				{
					SetState(FindState("DespawnTrail"));
					return;
				}
			}
			Loop;
			
		DespawnTrail:
			Stop;
	}
}