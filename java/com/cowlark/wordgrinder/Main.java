package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.nativeinterface.Screen;

import com.cowlark.wordgrinder.forms.Ui;
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
            Screen.screenInit(args);
            Screen.initScreen();
            try
            {
                var c = Ui.getCharWithBlinkingCursor();
            } finally
            {
                Screen.deinitScreen();
            }
        } catch (Exception e)
        {
            e.printStackTrace();
            exit(1);
        }
    }

    @Import(name = "exit")
    private static native void exit(int status);
}
