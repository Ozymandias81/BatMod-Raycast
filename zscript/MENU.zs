/*
 * Copyright (c) 2019-2022 Ivory Duke
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

Class OptionMenuItemZMoveOption : OptionMenuItemOption
{
	String mTooltip;

	OptionMenuItemZMoveOption Init(String label, String Tooltip, Name command, Name values, CVar graycheck = null, int center = 0)
	{
		mTooltip = Tooltip;
		Super.Init(label, command, values, graycheck, center);
		return self;
	}
}

Class OptionMenuItemZMoveSlider : OptionMenuItemSlider
{
	String mTooltip;

	OptionMenuItemZMoveSlider Init(String label, String Tooltip, Name command, double min, double max, double step, int showval = 1)
	{
		mTooltip = Tooltip;
		Super.Init(label, command, min, max, step, showval);
		return self;
	}
}

Class ZMoveMenu : OptionMenu
{
	const HELP_BOX_INDENT = 12;
	
	int 		TooltipCounter;
	int			mFrameW;
	int			mFrameH;
	int 		OldSelectedItem;
	string  	mBoxText;
	TextureID 	mBackdrop;
	vector2 	ToolPos;
	
	Override void Init(Menu parent, OptionMenuDescriptor desc)
	{
		Super.Init(parent, desc);
		mBackdrop = TexMan.CheckForTexture("HELPBOX", TexMan.Type_MiscPatch);
	}
	
	Override bool MouseEvent(int type, int x, int y)
	{
		bool mouse = Super.MouseEvent(type, x, y);
		ToolPos = (x, y);
		if(type == Menu.MOUSE_Click) { TooltipCounter = MenuTime() + 70; }
		return mouse;
	}
	
	Override bool MenuEvent(int mkey, bool fromcontroller)
	{
		bool Event = Super.MenuEvent(mkey, fromcontroller);
		if(mkey == MKEY_Left || mkey == MKEY_Right || mkey == MKEY_Enter)
			TooltipCounter = MenuTime() + 70;
		return Event;
	}
	
	Override void Drawer()
	{
		//====================================
		// Regular Drawer
		
		int y = mDesc.mPosition;

		if(y <= 0)
		{
			let font = generic_ui || !mDesc.mFont? NewSmallFont : mDesc.mFont;
			if(font && mDesc.mTitle.Length() > 0)
			{
				let tt = Stringtable.Localize(mDesc.mTitle);
				screen.DrawText (font, OptionMenuSettings.mTitleColor,
					(screen.GetWidth() - font.StringWidth(tt) * CleanXfac_1) / 2, 10*CleanYfac_1,
					tt, DTA_CleanNoMove_1, true);
				y = -y + font.GetHeight();
			}
			else
			{
				y = -y;
			}
		}
		mDesc.mDrawTop = y;
		int fontheight = OptionMenuSettings.mLinespacing * CleanYfac_1;
		y *= CleanYfac_1;
		
		int indent = GetIndent();
		int ytop = y + mDesc.mScrollTop * 8 * CleanYfac_1;
		int lastrow = screen.GetHeight() - OptionHeight() * CleanYfac_1;

		int i, MenuSize = mDesc.mItems.Size(), selectedY;
		for(i = 0; i < MenuSize && y <= lastrow; i++)
		{
			// Don't scroll the uppermost items
			if(i == mDesc.mScrollTop)
			{
				i += mDesc.mScrollPos;
				if(i >= MenuSize) break;	// skipped beyond end of menu 
			}
			bool isSelected = mDesc.mSelectedItem == i;
			int cur_indent = mDesc.mItems[i].Draw(mDesc, y, indent, isSelected);
			if(cur_indent >= 0 && isSelected && mDesc.mItems[i].Selectable())
			{
				selectedY = y;
				if(((MenuTime() % 8) < 6) || GetCurrentMenu() != self)
				{
					DrawOptionText(cur_indent + 3 * CleanXfac_1, y, OptionMenuSettings.mFontColorSelection, "◄");
				}
			}
			y += fontheight;
		}

		CanScrollUp = mDesc.mScrollPos > 0;
		CanScrollDown = i < MenuSize;
		VisBottom = i - 1;

		if(CanScrollUp)
		{
			DrawOptionText(screen.GetWidth() - 11 * CleanXfac_1, ytop, OptionMenuSettings.mFontColorSelection, "▲");
		}
		if(CanScrollDown)
		{
			DrawOptionText(screen.GetWidth() - 11 * CleanXfac_1 , y - 8 * CleanYfac_1, OptionMenuSettings.mFontColorSelection, "▼");
		}
		
		if (self == GetCurrentMenu() && BackbuttonAlpha > 0 && m_show_backbutton >= 0 && m_use_mouse)
		{
			let tex = TexMan.CheckForTexture(gameinfo.mBackButton, TexMan.Type_MiscPatch);
			if (tex.IsValid())
			{
				Vector2 v = TexMan.GetScaledSize(tex);
				int w = int(v.X + 0.5) * CleanXfac;
				int h = int(v.Y + 0.5) * CleanYfac;
				int x = (!(m_show_backbutton&1))? 0:screen.GetWidth() - w;
				int y = (!(m_show_backbutton&2))? 0:screen.GetHeight() - h;
				if (mBackbuttonSelected && (mMouseCapture || m_use_mouse == 1))
				{
					screen.DrawTexture(tex, true, x, y, DTA_CleanNoMove, true, DTA_ColorOverlay, Color(40, 255,255,255));
				}
				else
				{
					screen.DrawTexture(tex, true, x, y, DTA_CleanNoMove, true, DTA_Alpha, BackbuttonAlpha);
				}
			}
		}
		
		//====================================
		// Help Text
		
		Int SelectedItem = mDesc.mSelectedItem;
		Int Length; if(SelectedItem >= 0) { Length = OptionWidth(StringTable.Localize(mDesc.mItems[SelectedItem].mLabel)) * CleanXfac_1; }
		Bool OutsideLabel =  ToolPos.X > indent || ToolPos.X < indent - Length || ToolPos.Y < selectedY || ToolPos.Y > selectedY + fontheight;
		
		if(SelectedItem < 0 || SelectedItem != OldSelectedItem || OutsideLabel)
		{
			TooltipCounter = MenuTime() + 35;
		}
		else
		{
			//I will say this only once
			if(MenuTime() == TooltipCounter) { HelpBoxInit(SelectedItem); }
			
			//Start drawing after 1 second but only if there is text to draw
			if(mBoxText != "" && MenuTime() >= TooltipCounter)
			{
				//Hypothetical draw position
				Vector2 DrawPos = ToolPos + (HELP_BOX_INDENT, HELP_BOX_INDENT);
				
				//Adjust draw position if the help box is getting out of bounds
				Int Width = Screen.GetWidth();
				if(DrawPos.X + mFrameW > Width) { DrawPos.X = Width - mFrameW; }
				Int Height = Screen.GetHeight();
				if(DrawPos.Y + mFrameH > Height) { DrawPos.Y = ToolPos.Y - mFrameH; }
				
				//Draw frame and back texture
				Screen.DrawFrame(DrawPos.X, DrawPos.Y, mFrameW, mFrameH);
				screen.DrawTexture(mBackdrop, false, DrawPos.X, DrawPos.Y, DTA_DestWidth, mFrameW, DTA_DestHeight, mFrameH);
				
				//Draw text
				DrawPos += (HELP_BOX_INDENT * CleanXfac_1, (HELP_BOX_INDENT / 2 + 1) * CleanYfac_1);
				DrawOptionText(DrawPos.X, DrawPos.Y, OptionMenuSettings.mFontColorValue, mBoxText);
			}
		}
		
		OldSelectedItem = SelectedItem;
	}
	
	void HelpBoxInit(int SelectedItem)
	{
		Let MenuItem = mDesc.mItems[SelectedItem];
		if(MenuItem is "OptionMenuItemZMoveOption")
		{
			mBoxText = StringTable.Localize(OptionMenuItemZMoveOption(MenuItem).mTooltip);
		}
		else if(MenuItem is "OptionMenuItemZMoveSlider")
		{
			mBoxText = StringTable.Localize(OptionMenuItemZMoveSlider(MenuItem).mTooltip);
		}
		else
		{
			mBoxText = "";
			return;
		}
		
		int TextLength = OptionWidth(mBoxText);
		mFrameW = (TextLength + HELP_BOX_INDENT * 2) * CleanXfac_1; //same length
		mFrameH = (OptionHeight() + HELP_BOX_INDENT) * CleanYfac_1; //beautiful
	}
}