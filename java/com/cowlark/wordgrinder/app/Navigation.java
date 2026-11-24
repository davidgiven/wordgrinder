package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.document.Document;
import com.cowlark.wordgrinder.document.DocumentSet;
import com.cowlark.wordgrinder.document.Paragraph;
import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.ui.Action;
import com.cowlark.wordgrinder.ui.Menu;
import com.cowlark.wordgrinder.ui.VoidAction;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import java.util.ArrayList;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.FAILED;
import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

public class Navigation
{
    /* Share the active word processor with every navigation command. */
    private abstract static class NavigationAction implements Action
    {
        protected final WordProcessor wordProcessor;

        private NavigationAction(WordProcessor wordProcessor)
        {
            this.wordProcessor = wordProcessor;
        }

        /* Read the active set and selection from the editor when a command needs them. */
        protected DocumentSet getDocumentSet()
        {
            return wordProcessor.getDocumentSet();
        }

        protected Document getCurrentDocument()
        {
            return wordProcessor.getCurrentDocument();
        }

        /* Look up the Lua-style one-based paragraph and word positions. */
        protected static Paragraph paragraph(Document document)
        {
            return document.paragraphs.get(document.cursorParagraph - 1);
        }

        protected static String word(Document document)
        {
            return paragraph(document).words.get(document.cursorWord - 1);
        }

        /* Java word procedures take zero-based UTF-16 offsets. */
        protected boolean moveCharacter(Document document, boolean forward)
        {
            String word = word(document);
            int offset = document.cursorOffset - 1;
            int next = forward ? Word.nextCharInWord(word, offset) : Word.prevCharInWord(word, offset);
            if (next < 0)
                return false;

            document.cursorOffset = next + 1;
            wordProcessor.queueRedraw();
            return true;
        }

        /* Move between paragraphs, leaving the cursor unchanged at a document boundary. */
        protected boolean moveParagraph(Document document, int delta)
        {
            int next = document.cursorParagraph + delta;
            wordProcessor.queueRedraw();
            if (next < 1 || next > document.paragraphs.size())
                return false;

            document.cursorParagraph = next;
            document.cursorWord = 1;
            document.cursorOffset = 1;
            return true;
        }

        /* Position the cursor after the last word of its current paragraph. */
        protected static void endOfParagraph(Document document)
        {
            document.cursorWord = paragraph(document).words.size();
            document.cursorOffset = word(document).length() + 1;
        }

        /* Move to the beginning of a word, optionally crossing a paragraph boundary. */
        protected boolean moveWord(Document document, boolean forward, boolean wrap)
        {
            boolean moved;
            if (forward)
            {
                moved = document.cursorWord < paragraph(document).words.size();
                if (moved)
                {
                    document.cursorWord++;
                    document.cursorOffset = 1;
                }
                else
                    document.cursorOffset = word(document).length() + 1;
            }
            else
            {
                boolean insideWord = moveCharacter(document, false);
                moved = insideWord || document.cursorWord > 1;
                if (moved)
                {
                    if (!insideWord)
                        document.cursorWord--;
                    document.cursorOffset = 1;
                }
            }

            /* Wrap to the adjacent paragraph if movement within this one failed. */
            wordProcessor.queueRedraw();
            if (!moved && wrap && moveParagraph(document, forward ? 1 : -1))
            {
                if (!forward)
                    endOfParagraph(document);
                return true;
            }
            return moved;
        }

        /* Capture a mark at the start of any style controls immediately before the cursor. */
        protected static void setMark(Document document, boolean sticky)
        {
            String word = word(document);
            int previous = Word.prevCharInWord(word, document.cursorOffset - 1);
            document.markParagraph = document.cursorParagraph;
            document.markWord = document.cursorWord;
            document.markOffset = previous < 0 ? 1 : Word.nextCharInWord(word, previous) + 1;
            document.stickySelection = sticky;
        }

        /* Clear positional marks and schedule a redraw of the selection. */
        protected void unsetMark(Document document)
        {
            document.markParagraph = 0;
            document.markWord = 0;
            document.markOffset = 0;
            wordProcessor.queueRedraw();
        }

        /* Mark the set dirty when stored text changes. */
        protected void textChanged()
        {
            DocumentSet set = getDocumentSet();
            set.changed = true;
            set.justChanged = true;
            wordProcessor.queueRedraw();
        }

        /* Join the current paragraph to its successor while retaining its style. */
        protected boolean joinParagraph(Document document)
        {
            int index = document.cursorParagraph - 1;
            if (index + 1 >= document.paragraphs.size())
                return false;

            Paragraph paragraph = paragraph(document);
            var words = new ArrayList<>(paragraph.words);
            words.addAll(document.paragraphs.get(index + 1).words);
            document.paragraphs.set(index, paragraph.withWords(words));
            document.paragraphs.remove(index + 1);
            textChanged();
            return true;
        }

        /* Merge two neighbouring styled words and leave the cursor at the join. */
        protected boolean joinWord(Document document)
        {
            Paragraph paragraph = paragraph(document);
            if (document.cursorWord == paragraph.words.size())
            {
                if (!joinParagraph(document))
                    return false;
                paragraph = paragraph(document);
            }

            int index = document.cursorWord - 1;
            if (index + 1 >= paragraph.words.size())
                return false;
            Word.InsertResult joined = Word.insertIntoWord(
                    paragraph.words.get(index + 1), paragraph.words.get(index), 0, 0);
            if (joined.endOffset() < 0)
                return false;

            var words = new ArrayList<>(paragraph.words);
            words.set(index, joined.word());
            words.remove(index + 1);
            document.paragraphs.set(document.cursorParagraph - 1, paragraph.withWords(words));
            document.cursorOffset = joined.endOffset() + 1;
            textChanged();
            return true;
        }

        /* Remove a styled range from the current word and retain the containing paragraph. */
        protected void deleteWordRange(Document document, int start, int end)
        {
            Paragraph paragraph = paragraph(document);
            int index = document.cursorWord - 1;
            var words = new ArrayList<>(paragraph.words);
            words.set(index, Word.deleteFromWord(words.get(index), start, end));
            document.paragraphs.set(document.cursorParagraph - 1, paragraph.withWords(words));
            textChanged();
        }

        /* Delete forward across characters, words or paragraphs. */
        protected boolean deleteNextCharacter(Document document)
        {
            int start = document.cursorOffset - 1;
            int end = Word.nextCharInWord(word(document), start);
            if (end < 0)
                return joinWord(document);

            deleteWordRange(document, start, end);
            return true;
        }

        /* Match Lua's fallback from character movement to word and paragraph movement. */
        protected boolean moveCharacterAcrossWords(Document document, boolean forward)
        {
            if (moveCharacter(document, forward))
                return true;
            if (!moveWord(document, forward, true))
                return false;

            document.cursorOffset = forward ? 1 : word(document).length() + 1;
            wordProcessor.queueRedraw();
            return true;
        }
    }

    /* Represent Cmd.GotoBeginningOfWord from navigate.lua. */
    public static class GotoBeginningOfWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoBeginningOfWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            document.cursorOffset = 1;
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.GotoEndOfWord from navigate.lua. */
    public static class GotoEndOfWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoEndOfWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            document.cursorOffset = word(document).length() + 1;
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.GotoBeginningOfParagraph from navigate.lua. */
    public static class GotoBeginningOfParagraphAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoBeginningOfParagraphAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            document.cursorWord = 1;
            document.cursorOffset = 1;
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.GotoEndOfParagraph from navigate.lua. */
    public static class GotoEndOfParagraphAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoEndOfParagraphAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            endOfParagraph(document);
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.GotoBeginningOfDocument from navigate.lua. */
    public static class GotoBeginningOfDocumentAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoBeginningOfDocumentAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            document.cursorParagraph = 1;
            document.cursorWord = 1;
            document.cursorOffset = 1;
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.GotoEndOfDocument from navigate.lua. */
    public static class GotoEndOfDocumentAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoEndOfDocumentAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            document.cursorParagraph = document.paragraphs.size();
            endOfParagraph(document);
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.GotoPreviousParagraph from navigate.lua. */
    public static class GotoPreviousParagraphAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousParagraphAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveParagraph(document, -1) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoNextParagraph from navigate.lua. */
    public static class GotoNextParagraphAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextParagraphAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveParagraph(document, 1) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoPreviousParagraphW from navigate.lua. */
    public static class GotoPreviousParagraphWAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousParagraphWAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveParagraph(document, -1) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoNextParagraphW from navigate.lua. */
    public static class GotoNextParagraphWAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextParagraphWAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveParagraph(document, 1) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoPreviousWord from navigate.lua. */
    public static class GotoPreviousWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveWord(document, false, false) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoNextWord from navigate.lua. */
    public static class GotoNextWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveWord(document, true, false) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoPreviousWordW from navigate.lua. */
    public static class GotoPreviousWordWAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousWordWAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveWord(document, false, true) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoNextWordW from navigate.lua. */
    public static class GotoNextWordWAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextWordWAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveWord(document, true, true) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoPreviousChar from navigate.lua. */
    public static class GotoPreviousCharAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousCharAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveCharacter(document, false) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoNextChar from navigate.lua. */
    public static class GotoNextCharAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextCharAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveCharacter(document, true) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoPreviousCharW from navigate.lua. */
    public static class GotoPreviousCharWAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousCharWAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveCharacterAcrossWords(document, false) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.GotoNextCharW from navigate.lua. */
    public static class GotoNextCharWAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextCharWAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveCharacterAcrossWords(document, true) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.InsertStringIntoWord from navigate.lua. */
    public static class InsertStringIntoWordAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public InsertStringIntoWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(String text)
        {
            throw new UnsupportedOperationException("InsertStringIntoWord is not implemented");
        }
    }

    /* Represent Cmd.InsertStringIntoParagraph from navigate.lua. */
    public static class InsertStringIntoParagraphAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public InsertStringIntoParagraphAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(String text)
        {
            throw new UnsupportedOperationException("InsertStringIntoParagraph is not implemented");
        }
    }

    /* Represent Cmd.SplitCurrentWord from navigate.lua. */
    public static class SplitCurrentWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public SplitCurrentWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("SplitCurrentWord is not implemented");
        }
    }

    /* Represent Cmd.JoinWithNextParagraph from navigate.lua. */
    public static class JoinWithNextParagraphAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public JoinWithNextParagraphAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return joinParagraph(document) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.JoinWithNextWord from navigate.lua. */
    public static class JoinWithNextWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public JoinWithNextWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return joinWord(document) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.DeletePreviousChar from navigate.lua. */
    public static class DeletePreviousCharAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public DeletePreviousCharAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return moveCharacterAcrossWords(document, false) && deleteNextCharacter(document) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.DeleteSelectionOrPreviousChar from navigate.lua. */
    public static class DeleteSelectionOrPreviousCharAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public DeleteSelectionOrPreviousCharAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeleteSelectionOrPreviousChar is not implemented");
        }
    }

    /* Represent Cmd.DeleteNextChar from navigate.lua. */
    public static class DeleteNextCharAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public DeleteNextCharAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            return deleteNextCharacter(document) ? SUCCEEDED : FAILED;
        }
    }

    /* Represent Cmd.DeleteSelectionOrNextChar from navigate.lua. */
    public static class DeleteSelectionOrNextCharAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public DeleteSelectionOrNextCharAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeleteSelectionOrNextChar is not implemented");
        }
    }

    /* Represent Cmd.DeleteWordLeftOfCursor from navigate.lua. */
    public static class DeleteWordLeftOfCursorAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public DeleteWordLeftOfCursorAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            deleteWordRange(document, 0, document.cursorOffset - 1);
            document.cursorOffset = 1;
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.DeleteWord from navigate.lua. */
    public static class DeleteWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public DeleteWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            /* At a paragraph start Lua deletes backwards across the boundary. */
            if (document.cursorOffset == 1 && document.cursorWord == 1)
                return moveCharacterAcrossWords(document, false) && deleteNextCharacter(document)
                        ? SUCCEEDED : FAILED;
            if (document.cursorOffset == 1 && moveCharacterAcrossWords(document, false))
                deleteNextCharacter(document);

            /* Remove the whole current word, then join away its preceding boundary. */
            deleteWordRange(document, 0, word(document).length());
            document.cursorOffset = 1;
            if (document.cursorWord != 1 && moveCharacterAcrossWords(document, false))
                deleteNextCharacter(document);
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.SplitCurrentParagraph from navigate.lua. */
    public static class SplitCurrentParagraphAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public SplitCurrentParagraphAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("SplitCurrentParagraph is not implemented");
        }
    }

    /* Represent Cmd.GotoXPosition from navigate.lua. */
    public static class GotoXPositionAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoXPositionAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(int position)
        {
            throw new UnsupportedOperationException("GotoXPosition is not implemented");
        }
    }

    /* Represent Cmd.GotoXYPosition from navigate.lua. */
    public static class GotoXYPositionAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoXYPositionAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(int x, int y)
        {
            throw new UnsupportedOperationException("GotoXYPosition is not implemented");
        }
    }

    /* Represent Cmd.GotoNextLine from navigate.lua. */
    public static class GotoNextLineAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextLineAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextLine is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousLine from navigate.lua. */
    public static class GotoPreviousLineAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousLineAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousLine is not implemented");
        }
    }

    /* Represent Cmd.GotoBeginningOfLine from navigate.lua. */
    public static class GotoBeginningOfLineAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoBeginningOfLineAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoBeginningOfLine is not implemented");
        }
    }

    /* Represent Cmd.GotoEndOfLine from navigate.lua. */
    public static class GotoEndOfLineAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoEndOfLineAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoEndOfLine is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousPage from navigate.lua. */
    public static class GotoPreviousPageAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoPreviousPageAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousPage is not implemented");
        }
    }

    /* Represent Cmd.GotoNextPage from navigate.lua. */
    public static class GotoNextPageAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoNextPageAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextPage is not implemented");
        }
    }

    /* Order selection endpoints in document order, including positions within a word. */
    private record Position(int paragraph, int word, int offset) implements Comparable<Position>
    {
        @Override
        public int compareTo(Position other)
        {
            int result = Integer.compare(paragraph, other.paragraph);
            if (result == 0)
                result = Integer.compare(word, other.word);
            if (result == 0)
                result = Integer.compare(offset, other.offset);
            return result;
        }
    }

    /* Represent Cmd.ApplyStyleToSelection from navigate.lua. */
    public static class ApplyStyleToSelectionAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public ApplyStyleToSelectionAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(String style)
        {
            Document document = getCurrentDocument();
            if (document.markParagraph == 0)
                return FAILED;

            /* Resolve the Lua style masks and order the selection's endpoints. */
            int styleOr = switch (style)
            {
                case "b" -> Word.BOLD;
                case "u" -> Word.UNDERLINE;
                case "i" -> Word.ITALIC;
                case "o" -> 0;
                default -> -1;
            };
            if (styleOr < 0)
                return FAILED;
            int styleAnd = style.equals("o") ? 0 : Word.STYLE_ALL;
            Position mark = new Position(document.markParagraph, document.markWord, document.markOffset);
            Position cursor = new Position(document.cursorParagraph, document.cursorWord, document.cursorOffset);
            boolean markFirst = mark.compareTo(cursor) <= 0;
            Position first = markFirst ? mark : cursor;
            Position last = markFirst ? cursor : mark;

            /* Apply the style to the selected part of each paragraph. */
            for (int p = first.paragraph(); p <= last.paragraph(); p++)
            {
                Paragraph paragraph = document.paragraphs.get(p - 1);
                var words = new ArrayList<>(paragraph.words);
                int start = p == first.paragraph() ? first.word() : 1;
                int end = p == last.paragraph() ? last.word() : words.size();
                for (int w = start; w <= end; w++)
                {
                    String word = words.get(w - 1);
                    int from = p == first.paragraph() && w == first.word() ? first.offset() - 1 : 0;
                    int to = p == last.paragraph() && w == last.word() ? last.offset() - 1 : word.length();
                    boolean atCursor = p == cursor.paragraph() && w == cursor.word();
                    Word.StyleResult styled = Word.applyStyleToWord(
                            word, styleOr, styleAnd, from, to, atCursor ? cursor.offset() - 1 : 0);
                    words.set(w - 1, styled.word());
                    if (atCursor)
                        document.cursorOffset = styled.cursorOffset() + 1;
                }
                document.paragraphs.set(p - 1, paragraph.withWords(words));
            }

            /* Clear the selection and mark the document set dirty. */
            unsetMark(document);
            textChanged();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.SetStyle from navigate.lua. */
    public static class SetStyleAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public SetStyleAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(String style)
        {
            throw new UnsupportedOperationException("SetStyle is not implemented");
        }
    }

    /* Represent Cmd.ActivateMenu from navigate.lua. */
    public static class ActivateMenuAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public ActivateMenuAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(Menu menu)
        {
            throw new UnsupportedOperationException("ActivateMenu is not implemented");
        }
    }

    /* Represent Cmd.TerminateProgram from navigate.lua. */
    public static class TerminateProgramAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public TerminateProgramAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("TerminateProgram is not implemented");
        }
    }

    /* Represent Cmd.ChangeParagraphStyle from navigate.lua. */
    public static class ChangeParagraphStyleAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public ChangeParagraphStyleAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(String style)
        {
            throw new UnsupportedOperationException("ChangeParagraphStyle is not implemented");
        }
    }

    /* Represent Cmd.ToggleMark from navigate.lua. */
    public static class ToggleMarkAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public ToggleMarkAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            if (document.markParagraph != 0)
            {
                unsetMark(document);
                document.stickySelection = false;
            }
            else
            {
                setMark(document, true);
                wordProcessor.queueRedraw();
            }
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.SetMark from navigate.lua. */
    public static class SetMarkAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public SetMarkAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            if (document.markParagraph == 0)
                setMark(document, false);
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.UnsetMark from navigate.lua. */
    public static class UnsetMarkAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public UnsetMarkAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            unsetMark(document);
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.MoveWhileSelected from navigate.lua. */
    public static class MoveWhileSelectedAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public MoveWhileSelectedAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            if (document.markParagraph != 0 && !document.stickySelection)
                unsetMark(document);
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.TypeWhileSelected from navigate.lua. */
    public static class TypeWhileSelectedAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public TypeWhileSelectedAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("TypeWhileSelected is not implemented");
        }
    }

    /* Represent Cmd.SelectWord from navigate.lua. */
    public static class SelectWordAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public SelectWordAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            Document document = getCurrentDocument();
            unsetMark(document);
            document.cursorOffset = 1;
            setMark(document, false);
            document.cursorOffset = word(document).length() + 1;
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.ChangeDocument from navigate.lua. */
    public static class ChangeDocumentAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public ChangeDocumentAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(String name)
        {
            throw new UnsupportedOperationException("ChangeDocument is not implemented");
        }
    }

    /* Represent Cmd.Cut from navigate.lua. */
    public static class CutAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public CutAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("Cut is not implemented");
        }
    }

    /* Represent Cmd.Copy from navigate.lua. */
    public static class CopyAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public CopyAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(boolean keepSelection)
        {
            throw new UnsupportedOperationException("Copy is not implemented");
        }
    }

    /* Represent Cmd.Paste from navigate.lua. */
    public static class PasteAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public PasteAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("Paste is not implemented");
        }
    }

    /* Represent Cmd.Delete from navigate.lua. */
    public static class DeleteAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public DeleteAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("Delete is not implemented");
        }
    }

    /* Represent Cmd.Find from navigate.lua. */
    public static class FindAction extends NavigationAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public FindAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(String findText, String replaceText)
        {
            throw new UnsupportedOperationException("Find is not implemented");
        }
    }

    /* Represent Cmd.FindNext from navigate.lua. */
    public static class FindNextAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public FindNextAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("FindNext is not implemented");
        }
    }

    /* Represent Cmd.ReplaceThenFind from navigate.lua. */
    public static class ReplaceThenFindAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public ReplaceThenFindAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("ReplaceThenFind is not implemented");
        }
    }

    /* Represent Cmd.ToggleStatusBar from navigate.lua. */
    public static class ToggleStatusBarAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public ToggleStatusBarAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            DocumentSet set = getDocumentSet();
            set.statusBar = !set.statusBar;
            wordProcessor.nonmodalMessage(set.statusBar ? "Status bar enabled." : "Status bar disabled.");
            return SUCCEEDED;
        }
    }

    /* Represent Cmd.AboutWordGrinder from navigate.lua. */
    public static class AboutWordGrinderAction extends NavigationAction implements VoidAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public AboutWordGrinderAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("AboutWordGrinder is not implemented");
        }
    }
}
