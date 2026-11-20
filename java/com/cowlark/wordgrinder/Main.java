package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.document.DocumentStyle;
import com.cowlark.wordgrinder.document.GlobalSettings;
import org.teavm.interop.Import;
import org.teavm.interop.c.Include;
import java.io.IOException;

@Include("stdlib.h")
public class Main
{
    public static void main(String[] args) throws IOException
    {
        try
        {
            var g = GlobalSettings.loadGlobalSettings();
            System.out.println("" + g);
            System.out.println(g.lookandfeel.denseparagraphs);
            System.out.println(g.lookandfeel.enabled);

            var d = new DocumentStyle("test", "test", 0, 0, 0, "", false, 0, false, "P");
            var p = new Paragraph(d);
            System.out.println(p.toString());
        } catch (Exception e)
        {
            e.printStackTrace();
            exit(1);
        }
    }

    @Import(name = "exit")
    private static native void exit(int status);
}
