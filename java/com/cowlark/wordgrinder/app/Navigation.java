package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.ui.Action;
import com.cowlark.wordgrinder.ui.Menu;
import com.cowlark.wordgrinder.ui.VoidAction;
import com.cowlark.wordgrinder.utils.Injector;

public class Navigation
{
    /* Share the active word processor with every navigation command. */
    private abstract static class NavigationAction implements Action
    {
        protected final WordProcessor wordProcessor = Injector.INSTANCE.create(WordProcessor.class);
    }

    /* Represent Cmd.GotoBeginningOfWord from navigate.lua. */
    public static class GotoBeginningOfWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoBeginningOfWord is not implemented");
        }
    }

    /* Represent Cmd.GotoEndOfWord from navigate.lua. */
    public static class GotoEndOfWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoEndOfWord is not implemented");
        }
    }

    /* Represent Cmd.GotoBeginningOfParagraph from navigate.lua. */
    public static class GotoBeginningOfParagraphAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoBeginningOfParagraph is not implemented");
        }
    }

    /* Represent Cmd.GotoEndOfParagraph from navigate.lua. */
    public static class GotoEndOfParagraphAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoEndOfParagraph is not implemented");
        }
    }

    /* Represent Cmd.GotoBeginningOfDocument from navigate.lua. */
    public static class GotoBeginningOfDocumentAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoBeginningOfDocument is not implemented");
        }
    }

    /* Represent Cmd.GotoEndOfDocument from navigate.lua. */
    public static class GotoEndOfDocumentAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoEndOfDocument is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousParagraph from navigate.lua. */
    public static class GotoPreviousParagraphAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousParagraph is not implemented");
        }
    }

    /* Represent Cmd.GotoNextParagraph from navigate.lua. */
    public static class GotoNextParagraphAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextParagraph is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousParagraphW from navigate.lua. */
    public static class GotoPreviousParagraphWAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousParagraphW is not implemented");
        }
    }

    /* Represent Cmd.GotoNextParagraphW from navigate.lua. */
    public static class GotoNextParagraphWAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextParagraphW is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousWord from navigate.lua. */
    public static class GotoPreviousWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousWord is not implemented");
        }
    }

    /* Represent Cmd.GotoNextWord from navigate.lua. */
    public static class GotoNextWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextWord is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousWordW from navigate.lua. */
    public static class GotoPreviousWordWAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousWordW is not implemented");
        }
    }

    /* Represent Cmd.GotoNextWordW from navigate.lua. */
    public static class GotoNextWordWAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextWordW is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousChar from navigate.lua. */
    public static class GotoPreviousCharAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousChar is not implemented");
        }
    }

    /* Represent Cmd.GotoNextChar from navigate.lua. */
    public static class GotoNextCharAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextChar is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousCharW from navigate.lua. */
    public static class GotoPreviousCharWAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousCharW is not implemented");
        }
    }

    /* Represent Cmd.GotoNextCharW from navigate.lua. */
    public static class GotoNextCharWAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextCharW is not implemented");
        }
    }

    /* Represent Cmd.InsertStringIntoWord from navigate.lua. */
    public static class InsertStringIntoWordAction extends NavigationAction
    {
        public ActionResult execute(String text)
        {
            throw new UnsupportedOperationException("InsertStringIntoWord is not implemented");
        }
    }

    /* Represent Cmd.InsertStringIntoParagraph from navigate.lua. */
    public static class InsertStringIntoParagraphAction extends NavigationAction
    {
        public ActionResult execute(String text)
        {
            throw new UnsupportedOperationException("InsertStringIntoParagraph is not implemented");
        }
    }

    /* Represent Cmd.SplitCurrentWord from navigate.lua. */
    public static class SplitCurrentWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("SplitCurrentWord is not implemented");
        }
    }

    /* Represent Cmd.JoinWithNextParagraph from navigate.lua. */
    public static class JoinWithNextParagraphAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("JoinWithNextParagraph is not implemented");
        }
    }

    /* Represent Cmd.JoinWithNextWord from navigate.lua. */
    public static class JoinWithNextWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("JoinWithNextWord is not implemented");
        }
    }

    /* Represent Cmd.DeletePreviousChar from navigate.lua. */
    public static class DeletePreviousCharAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeletePreviousChar is not implemented");
        }
    }

    /* Represent Cmd.DeleteSelectionOrPreviousChar from navigate.lua. */
    public static class DeleteSelectionOrPreviousCharAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeleteSelectionOrPreviousChar is not implemented");
        }
    }

    /* Represent Cmd.DeleteNextChar from navigate.lua. */
    public static class DeleteNextCharAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeleteNextChar is not implemented");
        }
    }

    /* Represent Cmd.DeleteSelectionOrNextChar from navigate.lua. */
    public static class DeleteSelectionOrNextCharAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeleteSelectionOrNextChar is not implemented");
        }
    }

    /* Represent Cmd.DeleteWordLeftOfCursor from navigate.lua. */
    public static class DeleteWordLeftOfCursorAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeleteWordLeftOfCursor is not implemented");
        }
    }

    /* Represent Cmd.DeleteWord from navigate.lua. */
    public static class DeleteWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("DeleteWord is not implemented");
        }
    }

    /* Represent Cmd.SplitCurrentParagraph from navigate.lua. */
    public static class SplitCurrentParagraphAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("SplitCurrentParagraph is not implemented");
        }
    }

    /* Represent Cmd.GotoXPosition from navigate.lua. */
    public static class GotoXPositionAction extends NavigationAction
    {
        public ActionResult execute(int position)
        {
            throw new UnsupportedOperationException("GotoXPosition is not implemented");
        }
    }

    /* Represent Cmd.GotoXYPosition from navigate.lua. */
    public static class GotoXYPositionAction extends NavigationAction
    {
        public ActionResult execute(int x, int y)
        {
            throw new UnsupportedOperationException("GotoXYPosition is not implemented");
        }
    }

    /* Represent Cmd.GotoNextLine from navigate.lua. */
    public static class GotoNextLineAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextLine is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousLine from navigate.lua. */
    public static class GotoPreviousLineAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousLine is not implemented");
        }
    }

    /* Represent Cmd.GotoBeginningOfLine from navigate.lua. */
    public static class GotoBeginningOfLineAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoBeginningOfLine is not implemented");
        }
    }

    /* Represent Cmd.GotoEndOfLine from navigate.lua. */
    public static class GotoEndOfLineAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoEndOfLine is not implemented");
        }
    }

    /* Represent Cmd.GotoPreviousPage from navigate.lua. */
    public static class GotoPreviousPageAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoPreviousPage is not implemented");
        }
    }

    /* Represent Cmd.GotoNextPage from navigate.lua. */
    public static class GotoNextPageAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("GotoNextPage is not implemented");
        }
    }

    /* Represent Cmd.ApplyStyleToSelection from navigate.lua. */
    public static class ApplyStyleToSelectionAction extends NavigationAction
    {
        public ActionResult execute(String style)
        {
            throw new UnsupportedOperationException("ApplyStyleToSelection is not implemented");
        }
    }

    /* Represent Cmd.SetStyle from navigate.lua. */
    public static class SetStyleAction extends NavigationAction
    {
        public ActionResult execute(String style)
        {
            throw new UnsupportedOperationException("SetStyle is not implemented");
        }
    }

    /* Represent Cmd.ActivateMenu from navigate.lua. */
    public static class ActivateMenuAction extends NavigationAction
    {
        public ActionResult execute(Menu menu)
        {
            throw new UnsupportedOperationException("ActivateMenu is not implemented");
        }
    }

    /* Represent Cmd.TerminateProgram from navigate.lua. */
    public static class TerminateProgramAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("TerminateProgram is not implemented");
        }
    }

    /* Represent Cmd.ChangeParagraphStyle from navigate.lua. */
    public static class ChangeParagraphStyleAction extends NavigationAction
    {
        public ActionResult execute(String style)
        {
            throw new UnsupportedOperationException("ChangeParagraphStyle is not implemented");
        }
    }

    /* Represent Cmd.ToggleMark from navigate.lua. */
    public static class ToggleMarkAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("ToggleMark is not implemented");
        }
    }

    /* Represent Cmd.SetMark from navigate.lua. */
    public static class SetMarkAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("SetMark is not implemented");
        }
    }

    /* Represent Cmd.UnsetMark from navigate.lua. */
    public static class UnsetMarkAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("UnsetMark is not implemented");
        }
    }

    /* Represent Cmd.MoveWhileSelected from navigate.lua. */
    public static class MoveWhileSelectedAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("MoveWhileSelected is not implemented");
        }
    }

    /* Represent Cmd.TypeWhileSelected from navigate.lua. */
    public static class TypeWhileSelectedAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("TypeWhileSelected is not implemented");
        }
    }

    /* Represent Cmd.SelectWord from navigate.lua. */
    public static class SelectWordAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("SelectWord is not implemented");
        }
    }

    /* Represent Cmd.ChangeDocument from navigate.lua. */
    public static class ChangeDocumentAction extends NavigationAction
    {
        public ActionResult execute(String name)
        {
            throw new UnsupportedOperationException("ChangeDocument is not implemented");
        }
    }

    /* Represent Cmd.Cut from navigate.lua. */
    public static class CutAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("Cut is not implemented");
        }
    }

    /* Represent Cmd.Copy from navigate.lua. */
    public static class CopyAction extends NavigationAction
    {
        public ActionResult execute(boolean keepSelection)
        {
            throw new UnsupportedOperationException("Copy is not implemented");
        }
    }

    /* Represent Cmd.Paste from navigate.lua. */
    public static class PasteAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("Paste is not implemented");
        }
    }

    /* Represent Cmd.Delete from navigate.lua. */
    public static class DeleteAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("Delete is not implemented");
        }
    }

    /* Represent Cmd.Find from navigate.lua. */
    public static class FindAction extends NavigationAction
    {
        public ActionResult execute(String findText, String replaceText)
        {
            throw new UnsupportedOperationException("Find is not implemented");
        }
    }

    /* Represent Cmd.FindNext from navigate.lua. */
    public static class FindNextAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("FindNext is not implemented");
        }
    }

    /* Represent Cmd.ReplaceThenFind from navigate.lua. */
    public static class ReplaceThenFindAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("ReplaceThenFind is not implemented");
        }
    }

    /* Represent Cmd.ToggleStatusBar from navigate.lua. */
    public static class ToggleStatusBarAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("ToggleStatusBar is not implemented");
        }
    }

    /* Represent Cmd.AboutWordGrinder from navigate.lua. */
    public static class AboutWordGrinderAction extends NavigationAction implements VoidAction
    {
        @Override
        public ActionResult execute()
        {
            throw new UnsupportedOperationException("AboutWordGrinder is not implemented");
        }
    }
}
