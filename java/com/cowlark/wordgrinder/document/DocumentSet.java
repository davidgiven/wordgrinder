package com.cowlark.wordgrinder.document;

import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.fileio.Dumpable;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.ui.MenuSettings;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/** The stored and transient state shared by the documents in a set. */
public class DocumentSet
{
    /* Store the document collection and its current selection. Match FILEFORMAT in config.py. */
    @Dumpable("fileformat") public int fileFormat = 8;
    @Dumpable public String name;
    @Dumpable public List<Document> documents = new ArrayList<>();
    @Dumpable public Document current;
    @Dumpable public Document clipboard;

    /* Store per-set preferences, add-on state and the most recent search and replacement text. */
    @Dumpable public MenuSettings menu = new MenuSettings();
    @Dumpable("statusbar") public boolean statusBar = true;
    @Dumpable("addons") public Map<String, Object> addOns = new LinkedHashMap<>();
    @Dumpable("findtext") public String findText;
    @Dumpable("replacetext") public String replaceText;

    /* Keep lookup, change tracking and compiled search patterns in memory. */
    public Map<String, Document> documentIndex = new LinkedHashMap<>();
    public boolean changed;
    public boolean justChanged;
    public List<Pattern> findPatterns;

    /** Starts with the blank main document selected and indexed by name. */
    public DocumentSet(Screen screen, Word wordRenderer, EventBus eventBus)
    {
        current = new Document(screen, wordRenderer, eventBus);
        current.name = "main";
        documents.add(current);
        documentIndex.put(current.name, current);
    }
}
