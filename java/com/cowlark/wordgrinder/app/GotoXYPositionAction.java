package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.ui.Action;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

public class GotoXYPositionAction implements Action
{
    public ActionResult execute(int x, int y)
    {
        return SUCCEEDED;
    }
}
