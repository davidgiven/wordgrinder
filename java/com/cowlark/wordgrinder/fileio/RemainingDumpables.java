package com.cowlark.wordgrinder.fileio;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Marks a Map<String, String> which preserves otherwise unmapped dump entries.
 * Keys are dotted paths relative to the containing object, including the leading dot;
 * values are raw serialized values, including quotes and escapes for strings.
 * Only one such instance field may occur in an object's class hierarchy. It is
 * not itself a named dump property and must not also have {@link Dumpable}.
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
public @interface RemainingDumpables
{
}
