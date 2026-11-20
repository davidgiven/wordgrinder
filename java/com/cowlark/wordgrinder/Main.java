package com.cowlark.wordgrinder;

import com.cowlark.wordgrinder.ui.LabelWidget;
import com.cowlark.wordgrinder.ui.Ui;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.nativeinterface.System;
import com.cowlark.wordgrinder.teavm.impl.DisplayImpl;
import com.cowlark.wordgrinder.teavm.impl.ScreenImpl;
import com.cowlark.wordgrinder.teavm.impl.SystemImpl;
import org.jspecify.annotations.NonNull;
import java.io.IOException;

public class Main
{
    /* Keep backend selection separate from application execution. */
    private final @NonNull Screen screen;
    private final @NonNull Ui ui;
    private final @NonNull System process;

    public Main(@NonNull Screen screen, @NonNull System process)
    {
        this.screen = screen;
        this.process = process;
        ui = new Ui(screen);
    }

    /* The entry point chooses the backend; application logic receives its interface. */
    public static void main(String[] args) throws IOException
    {
        new Main(new ScreenImpl(new DisplayImpl()), new SystemImpl()).run(args);
    }

    public void run(@NonNull String[] args) throws IOException
    {
        try
        {
            screen.screenInit(args);
            screen.initScreen();
            try
            {
                ui.newForm()
                        .setTitle("This is a form")
                        .add(new LabelWidget().setBounds(2, 2, -2, 2).setValue("This a is a label"))
                        .run();
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
