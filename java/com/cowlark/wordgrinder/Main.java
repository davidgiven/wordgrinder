package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.document.Dumpable;
import com.cowlark.wordgrinder.document.Dumper;

public class Main
{
    static class TestClass
    {
        public @Dumpable int fnord;
    }

    public static void main(String[] args)
    {
        var o = new TestClass();
        o.fnord = 7;

        System.out.println("start dump");
        new Dumper().dump(o, System.out);
        System.out.println("end dump");

        //
        //        Screen.screenInit(args);
        //        Screen.initScreen();
        //
        //        Screen.deinitScreen();
    }
}
