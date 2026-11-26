package com.cowlark.wordgrinder.document;

import com.cowlark.wordgrinder.fileio.Dumpable;
import java.util.ArrayList;
import java.util.List;

/** The stored and transient state of a document. Position fields use zero-based indices. */
public class Document
{
    /* Share the normal paragraph style among newly created documents. */
    private static final DocumentStyle DEFAULT_STYLE =
            new DocumentStyle("Plain text", "P", 1, 1, 0, null, false, 0, false, null);

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
    private boolean fullStopSpaces;
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

    /** Stores the width used when paragraphs are wrapped on demand. */
    public void wrap(int width)
    {
        wrapWidth = width;
    }

    /** Updates the document layout with the current sentence spacing preference. */
    public void wrap(int width, boolean fullStopSpaces)
    {
        wrap(width);
        this.fullStopSpaces = fullStopSpaces;
    }

    /** Wraps a paragraph using the current document layout. */
    public Paragraph.WrapData wrapParagraph(int paragraph)
    {
        return paragraphs.get(paragraph).wrap(wrapWidth, fullStopSpaces);
    }

    /** Calculates the space above this paragraph. */
    public int spaceAbove(int paragraph)
    {
        int belowPrevious = paragraph > 0 ? paragraphs.get(paragraph - 1).style().below() : 0;
        return Math.max(paragraphs.get(paragraph).style().above(), belowPrevious);
    }

    /** Calculates the space below this paragraph. */
    public int spaceBelow(int paragraph)
    {
        int aboveNext = paragraph + 1 < paragraphs.size() ? paragraphs.get(paragraph + 1).style().above() : 0;
        return Math.max(paragraphs.get(paragraph).style().below(), aboveNext);
    }

    /** Updates the word count and assigns numbers to numbered list paragraphs. */
    public void renumber()
    {
        /* Count every stored word and restart numbering after a non-list paragraph. */
        int count = 0;
        int nextNumber = 1;
        for (Paragraph paragraph : paragraphs)
        {
            count += paragraph.words().size();
            DocumentStyle style = paragraph.style();
            if (style.numbered())
                paragraph.number = nextNumber++;
            else if (!style.list())
                nextNumber = 1;
        }
        wordCount = count;
    }

    /** An undo or redo snapshot containing paragraphs and a cursor position. */
    public record ShadowDocument(List<Paragraph> paragraphs, int cursorParagraph, int cursorWord, int cursorOffset)
    {
    }
}
