
# Bugs  
    Why is the font line height so big?  
		
# Features  
    Make font->ignore_newlines so you can render lines with newlines in them without going onto extra lines.  
    Add functions to get/set glyph data  
        Is this enough to make it generally useful?  
        Can I implement a bitmap font thing on top of it?  
        Needs functions to:  
            Set texture cache (e.g. from custom bitmap)  
            Set glyph data (could just be the source which is called as needed)  
            Set glyph data source and texture cache generator  
    Functions for manipulating UTF-8 text  
        U8_stroffset(iter->value, i)  // convert pos to offset  
        U8_strreplace(s, p, c)  // Replaces the character there  
           Is string overwrite more useful?  
    Scaled box/column text  
	Dynamic kerning calculation stored in 2D codepoint array (render "XY" and compare to width of "X"+"Y") if TTF_GetFontKerning(ttf) is true.  Render without kerning lookup if that is off, too.  Could dig into FreeType for getting this info more directly.  