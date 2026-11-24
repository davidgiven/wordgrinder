package com.cowlark.wordgrinder.ui;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;

import com.cowlark.wordgrinder.ui.Action.ActionResult;
import com.cowlark.wordgrinder.utils.Injector;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import java.util.ArrayList;
import java.util.List;
import org.junit.Test;

public class StaticActionTest
{
    /* An empty action list succeeds without resolving any actions. */
    @Test
    public void emptyListSucceeds()
    {
        assertSame(SUCCEEDED, new StaticAction().execute(new Injector()));
    }

    /* Resolve constructor dependencies and run every action in class-list order. */
    @Test
    public void runsInjectedActionsInOrder()
    {
        Trace trace = new Trace(SUCCEEDED);
        Injector injector = new Injector();
        injector.bindInstance(Trace.class, trace);

        /* A repeated class still runs at each position in the list. */
        var action = new StaticAction(RecordAction.class, ResultAction.class, RecordAction.class);
        assertSame(SUCCEEDED, action.execute(injector));
        assertEquals(List.of("record", "result", "record"), trace.calls);
    }

    /* Return the original failure and leave subsequent action classes unresolved. */
    @Test
    public void stopsOnFailure()
    {
        assertStopsWith(new ActionResult("Could not finish"));
    }

    /* A submenu result also ends the action list and is returned to the caller. */
    @Test
    public void stopsOnSubmenu()
    {
        assertStopsWith(new ActionResult(new Menu("Child", List.of())));
    }

    /* Reject any attempt to construct the action after the terminal result. */
    private static void assertStopsWith(ActionResult result)
    {
        Trace trace = new Trace(result);
        Injector injector = new Injector();
        injector.bindInstance(Trace.class, trace);
        var action = new StaticAction(RecordAction.class, ResultAction.class, UnexpectedAction.class);
        assertSame(result, action.execute(injector));
        assertEquals(List.of("record", "result"), trace.calls);
    }

    /* Share the execution log and terminal result with the injected actions. */
    public static class Trace
    {
        final List<String> calls = new ArrayList<>();
        final ActionResult result;

        Trace(ActionResult result)
        {
            this.result = result;
        }
    }

    /* Record an action that always succeeds. */
    public static class RecordAction implements Action
    {
        private final Trace trace;

        @Inject
        public RecordAction(Trace trace)
        {
            this.trace = trace;
        }

        @Override
        public ActionResult execute()
        {
            trace.calls.add("record");
            return SUCCEEDED;
        }
    }

    /* Record an action that returns the test's chosen result. */
    public static class ResultAction implements Action
    {
        private final Trace trace;

        @Inject
        public ResultAction(Trace trace)
        {
            this.trace = trace;
        }

        @Override
        public ActionResult execute()
        {
            trace.calls.add("result");
            return trace.result;
        }
    }

    /* Fail if an action beyond a terminal result is even constructed. */
    public static class UnexpectedAction implements Action
    {
        public UnexpectedAction()
        {
            throw new AssertionError("Action after terminal result was constructed");
        }

        @Override
        public ActionResult execute()
        {
            throw new AssertionError("Action after terminal result was executed");
        }
    }
}
