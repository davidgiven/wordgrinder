/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

package com.cowlark.wordgrinder.eventbus;

/**
 * Base class for application events. Each concrete subclass defines an event type and its payload.
 * The event class replaces the original Lua event-name string; fields replace its extra arguments.
 *
 * <p>The original application defines these event kinds:
 * <ul>
 * <li>{@code BuildStatusBar}: the status-bar contents are being calculated; carries the
 * status-bar list.</li>
 * <li>{@code Changed}: the document has changed.</li>
 * <li>{@code DocumentCreated}: a new document set has just been created.</li>
 * <li>{@code DocumentLoaded}: a document set has just been loaded.</li>
 * <li>{@code DocumentModified}: a document has been modified; carries the document.</li>
 * <li>{@code DocumentUpgrade}: a document set is being upgraded; carries the old and new
 * versions.</li>
 * <li>{@link DrawWordEvent}: a word is being drawn; carries mutable word text, old/current styles,
 * and sentence-start status.</li>
 * <li>{@code KeyTyped}: the user is typing into the document; carries the typed value.</li>
 * <li>{@code Idle}: the user is not touching the keyboard.</li>
 * <li>{@code Moved}: the cursor has moved.</li>
 * <li>{@code Redraw}: the screen has just been redrawn.</li>
 * <li>{@code RegisterAddons}: all addons should register themselves in the document set.</li>
 * <li>{@code WaitingForUser}: the application is about to wait for a keypress.</li>
 * <li>{@code ScreenInitialised}: the screen has just been set up.</li>
 * </ul>
 * These names describe the Lua event catalogue; concrete Java event subclasses are added
 * as the corresponding application code is ported.
 */
public abstract class Event
{
    /**
     * Constructs an event for delivery through an {@link EventBus}.
     */
    protected Event()
    {
    }
}
