package com.cowlark.wordgrinder.fileio;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Includes an instance field in a dump; an optional value overrides its saved name.
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
public @interface Dumpable
{
    String value() default "";

    /** Stores an int field one higher than its Java value, omitting an unset value of -1. */
    boolean oneOffset() default false;
}
