package com.cowlark.wordgrinder;

public class Main
{
    public static void main(String[] args)
    {
        System.out.println("Welcome to WordGrinder!");
        Display.dpy_init(args);
        Display.dpy_start();
        try
        {
            Display.dpy_clearscreen();
            Display.dpy_writechar(5, 5, 'q');
            for (; ; )
            {
                var c = Display.dpy_getchar(10.0);
                if (c == ' ')
                    break;
            }
        } finally
        {
            Display.dpy_shutdown();
        }
    }
}
