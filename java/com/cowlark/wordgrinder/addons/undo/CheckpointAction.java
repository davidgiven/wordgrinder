package com.cowlark.wordgrinder.addons.undo;

import com.cowlark.wordgrinder.ui.VoidAction;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import com.cowlark.wordgrinder.ui.Action;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

public class CheckpointAction implements VoidAction
{
    /* Expose this constructor to the action injector. */
    @Inject
    public CheckpointAction() {}

    @Override
    public ActionResult execute() {
        return SUCCEEDED;
    }
}
