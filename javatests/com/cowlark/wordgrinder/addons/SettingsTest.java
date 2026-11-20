package com.cowlark.wordgrinder.addons;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.cowlark.wordgrinder.addons.autosave.AutosaveDocumentSetSettings;
import com.cowlark.wordgrinder.addons.scrapbook.ScrapbookDocumentSetSettings;
import com.cowlark.wordgrinder.addons.smartquotes.SmartQuotesDocumentSetSettings;
import com.cowlark.wordgrinder.addons.spillchocker.SpillchockerDocumentSetSettings;
import com.cowlark.wordgrinder.addons.statusbar_pagecount.StatusbarPageCountDocumentSetSettings;
import com.cowlark.wordgrinder.document.GlobalSettings;
import com.cowlark.wordgrinder.fileio.Dumpable;
import com.cowlark.wordgrinder.fileio.Dumper;
import com.cowlark.wordgrinder.fileio.Undumper;
import org.jspecify.annotations.NonNull;
import org.junit.Test;
import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.StringReader;
import java.io.StringWriter;
import java.util.List;

/**
 * Checks compatibility with the saved Lua addon structures.
 */
public final class SettingsTest
{
    /* Read headerless Lua metadata through the production reader. */
    private static void read(@NonNull Object target, @NonNull String text) throws Exception
    {
        new Undumper().undump(target, new BufferedReader(new StringReader(text)));
    }

    /* Write headerless metadata through the production writer. */
    private static @NonNull String dump(@NonNull Object target)
    {
        StringWriter output = new StringWriter();
        new Dumper().dump(target, new PrintWriter(output));
        return output.toString();
    }

    /* Global fields retain their Lua names, including the indexed recents list. */
    @Test
    public void globalSettingsReadLuaPathsAndRoundTrip() throws Exception
    {
        GlobalSettings settings = new GlobalSettings();
        read(
                settings,
                ".debug.memory: true\n.directories.templates: \"/templates\"\n" +
                        ".gui.font_size: 24\n.lookandfeel.palette: \"Dark\"\n" +
                        ".recents.1: \"first.wg\"\n.recents.2: \"second.wg\"\n" +
                        ".systemdictionary.filename: \"/dictionary\"\n.future.option: true\n");

        /* Check the values were assigned to typed fields rather than unknown metadata. */
        assertTrue(settings.debug.memory);
        assertEquals("/templates", settings.directories.templates);
        assertEquals(24, settings.gui.font_size);
        assertEquals("Dark", settings.lookandfeel.palette);
        assertEquals(List.of("first.wg", "second.wg"), settings.recents);
        assertEquals("/dictionary", settings.systemdictionary.filename);
        assertEquals(1, settings.remaining.size());

        /* Repeated loading preserves both typed fields and unknown metadata. */
        GlobalSettings restored = new GlobalSettings();
        read(restored, dump(settings));
        assertEquals(dump(settings), dump(restored));
    }

    /* Each document addon uses its original key, even when its filename differs. */
    @Test
    public void documentSettingsReadLuaPathsAndRetainDefaults() throws Exception
    {
        Addons settings = new Addons();
        read(
                settings,
                ".autosave.enabled: true\n.autosave.period: 2.5\n" +
                        ".autosave.lastsaved: 1700000000\n.scrapbook.document: \"Clippings\"\n" +
                        ".smartquotes.doublequotes: true\n.spellchecker.enabled: true\n" +
                        ".pagecount.wordsperpage: 300\n");

        /* Missing properties retain the addon registration defaults. */
        assertTrue(settings.autosave.enabled);
        assertEquals(2.5, settings.autosave.period, 0);
        assertEquals(Long.valueOf(1700000000L), settings.autosave.lastsaved);
        assertEquals("%F.autosave.%T.wg", settings.autosave.pattern);
        assertEquals("Clippings", settings.scrapbook.document);
        assertTrue(settings.scrapbook.timestamp);
        assertTrue(settings.smartquotes.doublequotes);
        assertEquals("“", settings.smartquotes.leftdouble);
        assertTrue(settings.spellchecker.enabled);
        assertTrue(settings.spellchecker.usesystemdictionary);
        assertEquals(300, settings.pagecount.wordsperpage, 0);

        /* Serialisation preserves every defined document setting. */
        Addons restored = new Addons();
        read(restored, dump(settings));
        assertEquals(dump(settings), dump(restored));
    }

    /* Model only the document addon container needed to check saved field paths. */
    public static class Addons
    {
        @Dumpable public @NonNull AutosaveDocumentSetSettings autosave =
                new AutosaveDocumentSetSettings();
        @Dumpable public @NonNull ScrapbookDocumentSetSettings scrapbook =
                new ScrapbookDocumentSetSettings();
        @Dumpable public @NonNull SmartQuotesDocumentSetSettings smartquotes =
                new SmartQuotesDocumentSetSettings();
        @Dumpable public @NonNull SpillchockerDocumentSetSettings spellchecker =
                new SpillchockerDocumentSetSettings();
        @Dumpable public @NonNull StatusbarPageCountDocumentSetSettings pagecount =
                new StatusbarPageCountDocumentSetSettings();
    }
}
