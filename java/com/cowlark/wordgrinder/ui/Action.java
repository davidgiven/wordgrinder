package com.cowlark.wordgrinder.ui;

import com.cowlark.wordgrinder.utils.Injector;
import org.jspecify.annotations.Nullable;

/**
 * A word processor operation that returns a result when executed.
 */
public interface Action
{
    static <T extends Action> T of(Class<T> theClass)
    {
        return Injector.INSTANCE.create(theClass);
    }

    /* Distinguish successful operations from failed ones. */
    class ActionResult
    {
        public static ActionResult SUCCEEDED = new ActionResult();

        private @Nullable String message = null;
        private @Nullable Menu menu = null;

        /**
         * A successful result.
         */
        public ActionResult()
        {
        }

        /**
         * A result which has failed with a message.
         */
        public ActionResult(String message)
        {
            this.message = message;
        }

        /**
         * A result which is opening a menu.
         */
        public ActionResult(Menu menu)
        {
            this.menu = menu;
        }

        /** Returns the message to display, if supplied. */
        public @Nullable String message()
        {
            return message;
        }

        /** Returns the submenu to open, if supplied. */
        public @Nullable Menu menu()
        {
            return menu;
        }
    }
}
