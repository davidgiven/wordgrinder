package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.document.Word;

import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.System;
import com.cowlark.wordgrinder.teavm.impl.DisplayImpl;
import com.cowlark.wordgrinder.teavm.impl.ScreenImpl;
import com.cowlark.wordgrinder.teavm.impl.SystemImpl;
import com.cowlark.wordgrinder.ui.Ui;
import com.cowlark.wordgrinder.ui.WrappedLabelWidget;
import org.jspecify.annotations.NonNull;
import java.io.IOException;

public class Main
{
    /* Keep backend selection separate from application execution. */
    private final @NonNull Screen screen;
    private final @NonNull Ui ui;
    private final @NonNull System process;
    private final @NonNull Word wordRenderer;
    private final @NonNull EventBus eventBus;

    public Main(
            @NonNull Screen screen,
            @NonNull System process,
            @NonNull Word wordRenderer,
            @NonNull EventBus eventBus)
    {
        this.screen = screen;
        this.process = process;
        this.wordRenderer = wordRenderer;
        this.eventBus = eventBus;
        ui = new Ui(screen);
    }

    /* The entry point chooses the backend; application logic receives its interface. */
    public static void main(String[] args) throws IOException
    {
        DisplayImpl display = new DisplayImpl();
        new Main(new ScreenImpl(display), new SystemImpl(), new Word(display), new EventBus()).run(
                args);
    }

    public void run(@NonNull String[] args) throws IOException
    {
        try
        {
            screen.screenInit(args);
            screen.initScreen();
            try
            {
                ui.newForm().setTitle("This is a form").setSize(40, 2).setStretchy(true)
                        .add(new WrappedLabelWidget(wordRenderer, eventBus)
                                .setBounds(1, 1, -1, -1)
                                .setValue("""
                                        This is a wrapped label. Its text flows across several
                                        lines, and the form grows to fit it.
                                        """)).run();
            } finally
            {
                screen.deinitScreen();
            }
        } catch (Exception e)
        {
            e.printStackTrace();
            process.exit(1);
        }
    }

}
