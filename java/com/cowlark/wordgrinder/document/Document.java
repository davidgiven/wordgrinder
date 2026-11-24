package com.cowlark.wordgrinder.document;

import com.cowlark.wordgrinder.fileio.Dumpable;
import java.util.ArrayList;
import java.util.List;

/** The stored and transient state of a document. Position fields use zero-based indices. */
public class Document
{
    /* Share the normal paragraph style among newly created documents. */
    private static final DocumentStyle DEFAULT_STYLE =
            new DocumentStyle("Plain text", "P", 1, 1, null, null, null, 0, null, null);

    /* Store the document's paragraphs and view settings. */
    @Dumpable public List<Paragraph> paragraphs = new ArrayList<>();
    @Dumpable public String name;
    @Dumpable("wordcount") public int wordCount;
    @Dumpable("viewmode") public int viewMode = 1;
    @Dumpable public int margin;

    /* Store the cursor and selection mode. */
    @Dumpable(value = "cp", oneOffset = true) public int cursorParagraph;
    @Dumpable(value = "cw", oneOffset = true) public int cursorWord;
    @Dumpable(value = "co", oneOffset = true) public int cursorOffset;
    @Dumpable("sticky_selection") public boolean stickySelection;

    /* Use -1 for an unset mark and zero-based coordinates for a set mark. */
    @Dumpable(value = "mp", oneOffset = true) public int markParagraph = -1;
    @Dumpable(value = "mw", oneOffset = true) public int markWord = -1;
    @Dumpable(value = "mo", oneOffset = true) public int markOffset = -1;

    /* Keep change tracking and undo history in memory. */
    public boolean changed;
    public List<ShadowDocument> undoStack;
    public List<ShadowDocument> redoStack;

    /* Cache viewport positions, using -1 for an unset position. */
    public int wrapWidth;
    public int topParagraph = -1;
    public int topWord = -1;
    public int bottomParagraph = -1;
    public int bottomWord = -1;
    public int redrawParagraph = -1;
    public int redrawWord = -1;

    /** Starts the cursor in a single blank paragraph containing one empty word. */
    public Document()
    {
        paragraphs.add(Paragraph.builder()
                .setDocumentStyle(DEFAULT_STYLE)
                .setWords("")
                .build());
    }

    /** An undo or redo snapshot containing paragraphs and a cursor position. */
    public record ShadowDocument(List<Paragraph> paragraphs, int cursorParagraph, int cursorWord, int cursorOffset)
    {
    }
}
