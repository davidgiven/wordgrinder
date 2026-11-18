package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.document.GlobalSettings;
import com.cowlark.wordgrinder.fileio.Dumper;
import com.cowlark.wordgrinder.fileio.Undumper;

public class Context
{
    public GlobalSettings globalSettings = new GlobalSettings();
    public Dumper dumper = new Dumper();
    public Undumper undumper = new Undumper();
}
