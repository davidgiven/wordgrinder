package com.cowlark.wordgrinder.ui;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

@FunctionalInterface
public interface VoidAction extends Action
{
    ActionResult execute();

    default <T extends VoidAction> VoidAction then(Class<T> theClass)
    {
        T nextAction = Action.of(theClass);
        return () -> {
            ActionResult result = execute();
            if (result != SUCCEEDED)
                return result;
            return nextAction.execute();
        };
    }
}
