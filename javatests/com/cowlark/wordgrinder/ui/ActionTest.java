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

public class ActionTest
{
    /* Resolve a typed action and its dependencies from the shared injector. */
    @Test
    public void resolvesActionAndAcceptsExecutionParameters()
    {
        Trace trace = prepare(SUCCEEDED);
        CoordinateAction action = Action.of(CoordinateAction.class);
        assertSame(action, Injector.INSTANCE.create(CoordinateAction.class));
        assertEquals(List.of(), trace.calls);
        assertSame(SUCCEEDED, action.execute(3, 7));
        assertEquals(List.of("3,7"), trace.calls);
    }

    /* Execute chained actions in order after each preceding action succeeds. */
    @Test
    public void runsSuccessfulChainInOrder()
    {
        Trace trace = prepare(SUCCEEDED);
        VoidAction action = Action.of(RecordAction.class).then(ResultAction.class).then(RecordAction.class);
        assertSame(SUCCEEDED, action.execute());
        assertEquals(List.of("record", "result", "record"), trace.calls);
    }

    /* Preserve failure messages and submenu results without executing the rest of the chain. */
    @Test
    public void stopsOnFailureOrSubmenu()
    {
        for (ActionResult result : List.of(new ActionResult("Could not finish"),
                new ActionResult(new Menu("Child", List.of()))))
        {
            Trace trace = prepare(result);
            VoidAction action = Action.of(ResultAction.class).then(RecordAction.class);
            assertSame(result, action.execute());
            assertEquals(List.of("result"), trace.calls);
        }
    }

    /* Reset the shared test dependency without replacing the cached action instances. */
    private static Trace prepare(ActionResult result)
    {
        Trace trace = Injector.INSTANCE.create(Trace.class);
        trace.calls.clear();
        trace.result = result;
        return trace;
    }

    /* Supply a shared execution log and a configurable result. */
    public static class Trace
    {
        final List<String> calls = new ArrayList<>();
        ActionResult result = SUCCEEDED;
    }

    /* Record parameters passed to a typed action at execution time. */
    public static class CoordinateAction implements Action
    {
        private final Trace trace;

        @Inject
        public CoordinateAction(Trace trace)
        {
            this.trace = trace;
        }

        public ActionResult execute(int x, int y)
        {
            trace.calls.add(x + "," + y);
            return SUCCEEDED;
        }
    }

    /* Record an action that always succeeds. */
    public static class RecordAction implements VoidAction
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

    /* Record an action that returns the configured result. */
    public static class ResultAction implements VoidAction
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
}
