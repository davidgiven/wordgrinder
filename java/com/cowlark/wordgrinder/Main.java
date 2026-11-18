package com.cowlark.wordgrinder;

public class Main
{
    public static void main(String[] args)
    {
        Screen.screenInit(args);
        Screen.initScreen();

        try
        {
            Screen.clearScreen();
            Screen.write(5, 5, "Hello, world!");
            var c = Screen.getEvent();
        } finally
        {
            Screen.deinitScreen();
        }
    }
}
