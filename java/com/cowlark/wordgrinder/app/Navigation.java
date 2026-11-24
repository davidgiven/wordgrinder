package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.ui.Action;
import com.cowlark.wordgrinder.utils.Injector.Inject;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

public class Navigation
{
    @Inject
    public Navigation()
    {
    }

    public static class GotoXYPositionAction implements Action
    {
        public ActionResult execute(int x, int y)
        {
            return SUCCEEDED;
        }
    }
}
