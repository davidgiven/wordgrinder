package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.ui.Action.ActionResult;
import com.cowlark.wordgrinder.utils.Injector;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;

public class StaticAction
{
    public Class<? extends Action>[] classes;

    @SafeVarargs
    public static StaticAction of(
            Class<? extends Action>... classes)
    {
        return new StaticAction(classes);
    }

    @SafeVarargs
    public StaticAction(Class<? extends Action>... classes)
    {
        this.classes = classes;
    }

    public ActionResult execute(Injector injector)
    {
        for (Class<? extends Action> theClass : classes)
        {
            Action action = injector.create(theClass);
            ActionResult result = action.execute();
            if (result != SUCCEEDED)
                return result;
        }
        return SUCCEEDED;
    }
}
