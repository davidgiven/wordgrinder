package com.cowlark.wordgrinder;

import java.io.IOException;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class Main
{
    public static void main(String[] args)
    {
        var m = new Main();
        m.run(args);
    }

    public void run(String[] args)
    {
        if (args.length != 1)
        {
            System.err.println("Usage: wordgrinder <zipfile>");
            return;
        }

        try (ZipFile zip = new ZipFile(args[0]))
        {
            Enumeration<? extends ZipEntry> entries = zip.entries();
            while (entries.hasMoreElements())
                System.out.println(entries.nextElement().getName());
        }
        catch (IOException e)
        {
            System.err.println(args[0] + ": " + e.getMessage());
        }
    }
}
