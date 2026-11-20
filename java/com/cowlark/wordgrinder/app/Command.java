package com.cowlark.wordgrinder.app;

/**
 * A word processor-y thing which can be done. Create one by passing a constructor reference into
 * WordProcessor.command() and then call run(...) on it..
 */
public class Command<T extends Command>
{
    private WordProcessor wp;

    public T init(WordProcessor wp)
    {
        this.wp = wp;
        return (T) this;
    }
}
