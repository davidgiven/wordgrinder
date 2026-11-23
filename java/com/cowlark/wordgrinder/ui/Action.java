package com.cowlark.wordgrinder.ui;

/**
 * A word processor operation that returns a result when executed.
 */
public interface Action {
    /* Distinguish successful operations from failed ones. */
    class ActionResult {
        public static ActionResult SUCCEEDED = new ActionResult();
        public static ActionResult FAILED = new ActionResult();
    }

    /* Execute the operation and report its result. */
    ActionResult execute();
}
