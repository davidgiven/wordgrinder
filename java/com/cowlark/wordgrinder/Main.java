package com.cowlark.wordgrinder;

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
        } catch (Exception e)
        {
            e.printStackTrace();
            exit(1);
        }
    }

    @Import(name = "exit")
    private static native void exit(int status);
}
