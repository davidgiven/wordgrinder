package com.cowlark.wordgrinder.addons.undo;

import com.cowlark.wordgrinder.ui.Action;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

public class CheckpointAction implements Action {
    @Override
    public ActionResult execute() {
        return SUCCEEDED;
    }
}
