/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source licence. See the COPYING
 * file in this distribution for the full text.
 */
package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.document.Document;
import com.cowlark.wordgrinder.document.DocumentSet;
import com.cowlark.wordgrinder.document.Paragraph;
import com.cowlark.wordgrinder.document.Position;
import com.cowlark.wordgrinder.document.Word;
import com.cowlark.wordgrinder.eventbus.ChangedEvent;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.eventbus.RedrawEvent;
import com.cowlark.wordgrinder.ui.Action;
import com.cowlark.wordgrinder.ui.Menu;
import com.cowlark.wordgrinder.ui.MenuTree;
import com.cowlark.wordgrinder.ui.VoidAction;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import java.util.ArrayList;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.FAILED;
import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;
import static java.lang.Math.clamp;

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

        /* Look up the paragraph and word at the current cursor. */
        protected static Paragraph paragraph(Document document)
        {
            return document.paragraphs.get(document.cursorParagraph);
        }

        protected static String word(Document document)
        {
            return paragraph(document).words().get(document.cursorWord);
        }

        /* Java word procedures take zero-based UTF-16 offsets. */
        protected boolean moveCharacter(Document document, boolean forward)
        {
            String word = word(document);
            int offset = document.cursorOffset;
            int next = forward ? Word.nextCharInWord(word, offset) : Word.prevCharInWord(word, offset);
            if (next < 0)
                return false;

            document.cursorOffset = next;
            wordProcessor.queueRedraw();
            return true;
        }

        /* Move between paragraphs, leaving the cursor unchanged at a document boundary. */
        protected boolean moveParagraph(Document document, int delta)
        {
            int next = document.cursorParagraph + delta;
            wordProcessor.queueRedraw();
            if (next < 0 || next >= document.paragraphs.size())
                return false;

            document.cursorParagraph = next;
            document.cursorWord = 0;
            document.cursorOffset = 0;
            return true;
        }

        /* Position the cursor after the last word of its current paragraph. */
        protected static void endOfParagraph(Document document)
        {
            document.cursorWord = paragraph(document).words().size() - 1;
            document.cursorOffset = word(document).length();
        }

        /* Move to the beginning of a word, optionally crossing a paragraph boundary. */
        protected boolean moveWord(Document document, boolean forward, boolean wrap)
        {
            boolean moved;
            if (forward)
            {
                moved = document.cursorWord + 1 < paragraph(document).words().size();
                if (moved)
                {
                    document.cursorWord++;
                    document.cursorOffset = 0;
                }
                else
                    document.cursorOffset = word(document).length();
            }
            else
            {
                boolean insideWord = moveCharacter(document, false);
                moved = insideWord || document.cursorWord > 0;
                if (moved)
                {
                    /* If moving back a character worked, we weren't at the beginning of the word. */
                    if (!insideWord)
                        document.cursorWord--;
                    document.cursorOffset = 0;
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
            int previous = Word.prevCharInWord(word, document.cursorOffset);
            document.markParagraph = document.cursorParagraph;
            document.markWord = document.cursorWord;
            document.markOffset = previous < 0 ? 0 : Word.nextCharInWord(word, previous);
            document.stickySelection = sticky;
        }

        /* Clear positional marks and schedule a redraw of the selection. */
        protected void unsetMark(Document document)
        {
            document.markParagraph = -1;
            document.markWord = -1;
            document.markOffset = -1;
            wordProcessor.queueRedraw();
        }

        /* Mark the set dirty when stored text changes. */
        protected void textChanged()
        {
            DocumentSet set = getDocumentSet();
            set.changed = true;
            set.justChanged = true;
            getCurrentDocument().renumber();
            wordProcessor.queueRedraw();
        }

        /* Join the current paragraph to its successor while retaining its style. */
        protected boolean joinParagraph(Document document)
        {
            int index = document.cursorParagraph;
            if (index + 1 >= document.paragraphs.size())
                return false;

            Paragraph paragraph = paragraph(document);
            var words = new ArrayList<>(paragraph.words());
            words.addAll(document.paragraphs.get(index + 1).words());
            document.paragraphs.set(index, paragraph.withWords(words));
            document.paragraphs.remove(index + 1);
            textChanged();
            return true;
        }

        /* Merge two neighbouring styled words and leave the cursor at the join. */
        protected boolean joinWord(Document document)
        {
            Paragraph paragraph = paragraph(document);
            if (document.cursorWord + 1 == paragraph.words().size())
            {
                if (!joinParagraph(document))
                    return false;
                paragraph = paragraph(document);
            }

            int index = document.cursorWord;
            if (index + 1 >= paragraph.words().size())
                return false;
            Word.InsertResult joined = Word.insertIntoWord(
                    paragraph.words().get(index + 1), paragraph.words().get(index), 0, 0);
            if (joined.endOffset() < 0)
                return false;

            var words = new ArrayList<>(paragraph.words());
            words.set(index, joined.word());
            words.remove(index + 1);
            document.paragraphs.set(document.cursorParagraph, paragraph.withWords(words));
            document.cursorOffset = joined.endOffset();
            textChanged();
            return true;
        }

        /* Remove a styled range from the current word and retain the containing paragraph. */
        protected void deleteWordRange(Document document, int start, int end)
        {
            Paragraph paragraph = paragraph(document);
            int index = document.cursorWord;
            var words = new ArrayList<>(paragraph.words());
            words.set(index, Word.deleteFromWord(words.get(index), start, end));
            document.paragraphs.set(document.cursorParagraph, paragraph.withWords(words));
            textChanged();
        }

        /* Delete forward across characters, words or paragraphs. */
        protected boolean deleteNextCharacter(Document document)
        {
            int start = document.cursorOffset;
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

            document.cursorOffset = forward ? 0 : word(document).length();
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
            document.cursorOffset = 0;
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
            document.cursorOffset = word(document).length();
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
            document.cursorWord = 0;
            document.cursorOffset = 0;
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
            document.cursorParagraph = 0;
            document.cursorWord = 0;
            document.cursorOffset = 0;
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
            document.cursorParagraph = document.paragraphs.size() - 1;
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
            deleteWordRange(document, 0, document.cursorOffset);
            document.cursorOffset = 0;
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
            if (document.cursorOffset == 0 && document.cursorWord == 0)
                return moveCharacterAcrossWords(document, false) && deleteNextCharacter(document)
                        ? SUCCEEDED : FAILED;
            if (document.cursorOffset == 0 && moveCharacterAcrossWords(document, false))
                deleteNextCharacter(document);

            /* Remove the whole current word, then join away its preceding boundary. */
            deleteWordRange(document, 0, word(document).length());
            document.cursorOffset = 0;
            if (document.cursorWord != 0 && moveCharacterAcrossWords(document, false))
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

    /* Share column mapping and movement across wrapped lines. */
    private abstract static class ViewportAction extends NavigationAction
    {
        ViewportAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        /* Find the rightmost word which starts at or before the requested column. */
        protected ActionResult gotoX(Document document, int position)
        {
            var paragraph = paragraph(document);
            var layout = document.wrapParagraph(document.cursorParagraph);
            int lineNumber = layout.lineOfWord(document.cursorWord);
            if (lineNumber < 0)
                return FAILED;
            var line = layout.lines().get(lineNumber);
            int column = Math.max(0, position - paragraph.getIndentOfLine(lineNumber));
            int index = line.words().size() - 1;
            while (index > 0 && layout.xs().get(line.words().get(index)) > column)
                index--;

            /* Returns the offset into a string needed for a screen width. */
            int wordIndex = line.words().get(index);
            String word = paragraph.words().get(wordIndex);
            int remaining = Math.max(0, column - layout.xs().get(wordIndex));
            int offset = 0;
            while (offset < word.length() && remaining > 0)
            {
                int end = offset + Character.charCount(word.codePointAt(offset));
                int cells = wordProcessor.screen().getStringWidth(word.substring(offset, end));
                if (cells > remaining)
                    break;
                remaining -= cells;
                offset = end;
            }
            document.cursorWord = wordIndex;
            document.cursorOffset = offset;
            wordProcessor.queueRedraw();
            return FAILED; /* Lua returns false even when it successfully positions the cursor. */
        }

        /* Measure the cursor column from the start of the paper's text area. */
        private int cursorX(Document document, Paragraph.WrapData layout, int line)
        {
            if (line < 0)
                return 0;
            return paragraph(document).getIndentOfLine(line) + layout.xs().get(document.cursorWord)
                    + wordProcessor.screen().getStringWidth(word(document).substring(0, document.cursorOffset));
        }

        /* Keep the same column on the adjacent line or paragraph. */
        protected ActionResult moveLine(boolean forward)
        {
            var document = getCurrentDocument();
            var layout = document.wrapParagraph(document.cursorParagraph);
            int line = layout.lineOfWord(document.cursorWord);
            int x = cursorX(document, layout, line);
            int destination = line + (forward ? 1 : -1);
            if (line >= 0 && destination >= 0 && destination < layout.lines().size())
            {
                var target = layout.lines().get(destination);
                if (!target.words().isEmpty())
                {
                    document.cursorWord = target.firstWord();
                    return gotoX(document, x);
                }
            }

            /* At the edge of the document, move to the start or end of its text. */
            if (!moveParagraph(document, forward ? 1 : -1))
            {
                if (forward && !paragraph(document).words().isEmpty())
                    endOfParagraph(document);
                else
                {
                    document.cursorWord = 0;
                    document.cursorOffset = 0;
                }
                return SUCCEEDED;
            }
            if (!forward && !paragraph(document).words().isEmpty())
                endOfParagraph(document);
            return gotoX(document, x);
        }

        /* Move to the displayed page boundary while keeping the cursor column. */
        protected ActionResult movePage(boolean forward)
        {
            var document = getCurrentDocument();
            int paragraph = forward ? document.bottomParagraph : document.topParagraph;
            int word = forward ? document.bottomWord : document.topWord;
            if (paragraph < 0 || paragraph >= document.paragraphs.size() || word < 0)
                return FAILED;

            var layout = document.wrapParagraph(document.cursorParagraph);
            int x = cursorX(document, layout, layout.lineOfWord(document.cursorWord));
            document.cursorParagraph = paragraph;
            document.cursorWord = clamp(paragraph(document).words().size() - 1, 0, word);
            document.cursorOffset = 0;
            return gotoX(document, x);
        }
    }

    /* Represent Cmd.GotoXPosition from navigate.lua. */
    public static class GotoXPositionAction extends ViewportAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoXPositionAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(int position)
        {
            return gotoX(getCurrentDocument(), position);
        }
    }

    /* Represent Cmd.GotoXYPosition from navigate.lua. */
    public static class GotoXYPositionAction extends ViewportAction
    {
        /* Pass the injected processor to the shared navigation action. */
        @Inject
        public GotoXYPositionAction(WordProcessor wordProcessor)
        {
            super(wordProcessor);
        }

        public ActionResult execute(int x, int y)
        {
            var position = wordProcessor.getPositionOfLine(y);
            if (position == null)
                return FAILED;

            /* Use the paragraph and word recorded when this screen row was drawn. */
            var document = getCurrentDocument();
            if (position.paragraph() >= document.paragraphs.size())
                return FAILED;
            document.cursorParagraph = position.paragraph();
            document.cursorWord = clamp(paragraph(document).words().size() - 1, 0, position.word());
            document.cursorOffset = 0;
            return gotoX(document, x - position.x());
        }
    }

    /* Represent Cmd.GotoNextLine from navigate.lua. */
    public static class GotoNextLineAction extends ViewportAction implements VoidAction
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
            return moveLine(true);
        }
    }

    /* Represent Cmd.GotoPreviousLine from navigate.lua. */
    public static class GotoPreviousLineAction extends ViewportAction implements VoidAction
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
            return moveLine(false);
        }
    }

    /* Represent Cmd.GotoBeginningOfLine from navigate.lua. */
    public static class GotoBeginningOfLineAction extends ViewportAction implements VoidAction
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
            return gotoX(getCurrentDocument(), 0);
        }
    }

    /* Represent Cmd.GotoEndOfLine from navigate.lua. */
    public static class GotoEndOfLineAction extends ViewportAction implements VoidAction
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
            return gotoX(getCurrentDocument(), wordProcessor.screen().getScreenSize()[0]);
        }
    }

    /* Represent Cmd.GotoPreviousPage from navigate.lua. */
    public static class GotoPreviousPageAction extends ViewportAction implements VoidAction
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
            return movePage(false);
        }
    }

    /* Represent Cmd.GotoNextPage from navigate.lua. */
    public static class GotoNextPageAction extends ViewportAction implements VoidAction
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
            return movePage(true);
        }
    }

    /* Resolve the character style names shared by selection and typing commands. */
    private static int styleMask(String style)
    {
        return switch (style)
        {
            case "b" -> Word.BOLD;
            case "u" -> Word.UNDERLINE;
            case "i" -> Word.ITALIC;
            case "o" -> 0;
            default -> -1;
        };
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
            if (document.markParagraph == -1)
                return FAILED;

            /* Resolve the Lua style masks and order the selection's endpoints. */
            int styleOr = styleMask(style);
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
                Paragraph paragraph = document.paragraphs.get(p);
                var words = new ArrayList<>(paragraph.words());
                int start = p == first.paragraph() ? first.word() : 0;
                int end = p == last.paragraph() ? last.word() : words.size() - 1;
                for (int w = start; w <= end; w++)
                {
                    String word = words.get(w);
                    int from = p == first.paragraph() && w == first.word() ? first.offset() : 0;
                    int to = p == last.paragraph() && w == last.word() ? last.offset() : word.length();
                    boolean atCursor = p == cursor.paragraph() && w == cursor.word();
                    Word.StyleResult styled = Word.applyStyleToWord(
                            word, styleOr, styleAnd, from, to, atCursor ? cursor.offset() : 0);
                    words.set(w, styled.word());
                    if (atCursor)
                        document.cursorOffset = styled.cursorOffset();
                }
                document.paragraphs.set(p, paragraph.withWords(words));
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
            if (getCurrentDocument().markParagraph >= 0)
                return new ApplyStyleToSelectionAction(wordProcessor).execute(style);

            /* Toggle the requested typing style, or clear all style bits for normal. */
            int mask = styleMask(style);
            if (mask < 0)
                return FAILED;
            wordProcessor.charStyle().setCurrentStyleHint(mask, mask == 0 ? 0 : Word.STYLE_ALL);
            wordProcessor.queueRedraw();
            return SUCCEEDED;
        }
    }

    /* Open the top-level menu from a key binding or activate a supplied menu. */
    public static class ActivateMenuAction extends NavigationAction implements VoidAction
    {
        private final MenuTree menuTree;
        private final EventBus eventBus;

        @Inject
        public ActivateMenuAction(WordProcessor wordProcessor, MenuTree menuTree, EventBus eventBus)
        {
            super(wordProcessor);
            this.menuTree = menuTree;
            this.eventBus = eventBus;
        }

        @Override
        public ActionResult execute()
        {
            return execute(MenuDefinitions.TOPLEVEL);
        }

        public ActionResult execute(Menu menu)
        {
            return menuTree.activate(menu, getDocumentSet().menu,
                    () -> eventBus.fireEvent(RedrawEvent.INSTANCE),
                    wordProcessor::nonmodalMessage);
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
            if (document.markParagraph != -1)
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
            if (document.markParagraph == -1)
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
            if (document.markParagraph != -1 && !document.stickySelection)
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
            document.cursorOffset = 0;
            setMark(document, false);
            document.cursorOffset = word(document).length();
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
            var set = getDocumentSet();
            Document next = set.documentIndex.get(name);
            if (next == null)
            {
                /* Recover a document which exists in the list but is missing from the index. */
                for (Document document : set.documents)
                {
                    if (name.equals(document.name))
                    {
                        next = document;
                        break;
                    }
                }
                if (next == null)
                    return FAILED;
                wordProcessor.modalMessage("Document index inconsistency corrected",
                        "Something freaky happened to '" + name + "'.");
                set.documentIndex.put(name, next);
            }

            /* Ensure any housekeeping on the current document gets done. */
            if (set.current.changed)
                wordProcessor.eventBus().fireEvent(new ChangedEvent());

            /* Select, renumber and resize the requested document before repainting. */
            set.current = next;
            next.renumber();
            Action.of(WordProcessor.ResizeScreenAction.class).execute();
            wordProcessor.queueRedraw();
            return SUCCEEDED;
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
