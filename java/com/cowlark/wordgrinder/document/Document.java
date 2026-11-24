package com.cowlark.wordgrinder.document;

import com.cowlark.wordgrinder.fileio.Dumpable;
import java.util.ArrayList;
import java.util.List;

/** The stored and transient state of a document. Position fields retain Lua's one-based values. */
public class Document
{
    /* Store the document's paragraphs and view settings. */
    @Dumpable public List<Paragraph> paragraphs = new ArrayList<>();
    @Dumpable public String name;
    @Dumpable("wordcount") public int wordCount;
    @Dumpable("viewmode") public int viewMode = 1;
    @Dumpable public int margin;

    /* Store the cursor and selection mode. */
    @Dumpable("cp") public int cursorParagraph = 1;
    @Dumpable("cw") public int cursorWord = 1;
    @Dumpable("co") public int cursorOffset = 1;
    @Dumpable("sticky_selection") public boolean stickySelection;

    /* Use zero for an unset mark and one-based coordinates for a set mark. */
    @Dumpable("mp") public int markParagraph;
    @Dumpable("mw") public int markWord;
    @Dumpable("mo") public int markOffset;

    /* Keep change tracking and undo history in memory. */
    public boolean changed;
    public List<ShadowDocument> undoStack;
    public List<ShadowDocument> redoStack;

    /* Cache viewport positions, using zero for an unset one-based position. */
    public int wrapWidth;
    public int topParagraph;
    public int topWord;
    public int bottomParagraph;
    public int bottomWord;
    public int redrawParagraph;
    public int redrawWord;

    /** An undo or redo snapshot containing paragraphs and a cursor position. */
    public record ShadowDocument(List<Paragraph> paragraphs, int cursorParagraph, int cursorWord, int cursorOffset)
    {
    }
}
