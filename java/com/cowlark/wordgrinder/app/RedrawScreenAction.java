package com.cowlark.wordgrinder.app;

import com.cowlark.wordgrinder.addons.lookandfeel.LookAndFeelGlobalSettings;
import com.cowlark.wordgrinder.document.Document;
import com.cowlark.wordgrinder.document.DocumentSet;
import com.cowlark.wordgrinder.document.GlobalSettings;
import com.cowlark.wordgrinder.document.Paragraph;
import com.cowlark.wordgrinder.document.Position;
import com.cowlark.wordgrinder.document.Paragraph.WrapData;
import com.cowlark.wordgrinder.eventbus.BuildStatusBarEvent;
import com.cowlark.wordgrinder.eventbus.EventBus;
import com.cowlark.wordgrinder.nativeinterface.Screen;
import com.cowlark.wordgrinder.ui.Ui;
import com.cowlark.wordgrinder.ui.VoidAction;
import com.cowlark.wordgrinder.utils.Injector.Inject;
import java.util.Comparator;
import org.jspecify.annotations.Nullable;

import static com.cowlark.wordgrinder.ui.Action.ActionResult.SUCCEEDED;
import static java.lang.Math.max;
import static java.lang.Math.min;

/* Draw the document, status bar and transient messages. */
public class RedrawScreenAction implements VoidAction
{
    private final WordProcessor wordProcessor;
    private final Ui ui;
    private final Screen screen;
    private final GlobalSettings globalSettings;
    private final EventBus eventBus;

    @Inject
    public RedrawScreenAction(WordProcessor wp, GlobalSettings globalSettings)
    {
        wordProcessor = wp;
        ui = wp.ui();
        screen = wp.screen();
        this.globalSettings = globalSettings;
        eventBus = wp.eventBus();
    }

    @Override
    public ActionResult execute()
    {
        /* We can't draw until the backend reports a usable screen size. */
        int[] size = screen.getScreenSize();
        int width = size[0];
        int height = size[1];
        int margin = wordProcessor.resize(width, globalSettings);
        int y = height - 1;
        wordProcessor.setLineIndex(new LinePosition[0]);
        if (width <= 0 || y < 0)
            return SUCCEEDED;

        ui.setColour(null, "Desktop");
        screen.clearScreen();

        /* Draw the paper before overlaying the status bar and messages. */
        Document document = wordProcessor.getCurrentDocument();
        if (document.wrapWidth > 0)
            wordProcessor.setLineIndex(new DocumentRedraw(document, height, margin).draw());

        /* Reserve the bottom row for the status bar when enabled. */
        if (wordProcessor.getDocumentSet().statusBar)
            drawStatusBar(width, y--);

        /* Stack messages upwards from the bottom, with the newest message last on screen. */
        var messages = wordProcessor.messages();
        if (!messages.isEmpty())
        {
            /* Reversed due to setReverse below. */
            ui.setColour("MessageFG", "MessageBG");
            screen.setReverse();
            int i = messages.size() - 1;
            while (i >= 0 && y >= 0)
            {
                screen.clearArea(0, y, width - 1, y);
                screen.write(0, y, messages.get(i));
                i--;
                y--;
            }
            screen.setNormal();
        }

        return SUCCEEDED;
    }

    /* Draw document names and the dirty marker before collecting add-on fields. */
    private void drawStatusBar(int width, int y)
    {
        DocumentSet set = wordProcessor.getDocumentSet();
        String filename = set.name == null ? "(unnamed)" : set.name;
        int separator = max(filename.lastIndexOf('/'), filename.lastIndexOf('\\'));
        String name = set.current.name == null ? "" : set.current.name;
        String label = filename.substring(separator + 1) + "[" + name + "] " + (set.changed ? "CHANGED" : "");

        /* Reversed due to setReverse below. */
        ui.setColour("StatusbarBG", "StatusbarFG");
        screen.setReverse();
        screen.clearArea(0, y, width - 1, y);
        ui.lAlignInField(0, y, width, label);

        /* Deliver the event now so its fields can be laid out in this redraw. */
        BuildStatusBarEvent event = new BuildStatusBarEvent();
        eventBus.fireEvent(event);
        event.fields.sort(Comparator.comparingInt(BuildStatusBarEvent.Field::priority));
        if (!event.fields.isEmpty())
        {
            StringBuilder fields = new StringBuilder(" ");
            for (BuildStatusBarEvent.Field field : event.fields)
                fields.append(" │ ").append(field.value());
            if (fields.charAt(fields.length() - 1) == ' ')
                fields.setLength(fields.length() - 1);
            ui.rAlignInField(0, y, width, fields.toString());
        }
        screen.setNormal();
    }

    /* Record the first word and text origin for each visible document row. */
    record LinePosition(int paragraph, int word, int x)
    {
    }

    /** Draws one document viewport, preserving the paper and scroll layout from redraw.lua. */
    private final class DocumentRedraw
    {
        private final Document document;
        private final LookAndFeelGlobalSettings settings;
        private final int height;
        private final int left;
        private final int right;
        private final int textX;
        private final @Nullable LinePosition[] lineIndex;
        private @Nullable Position start;
        private @Nullable Position end;

        /* Capture the viewport geometry for this redraw. */
        DocumentRedraw(Document document, int height, int margin)
        {
            this.document = document;
            settings = globalSettings.lookandfeel;
            this.height = height;
            left = margin;
            right = left + document.wrapWidth - 1;
            textX = left + 1;
            lineIndex = new LinePosition[height];
        }

        /* Lay out the viewport around the scroll anchor and return its line index. */
        @Nullable LinePosition[] draw()
        {
            int cursorParagraph = document.cursorParagraph;
            int cursorWord = document.cursorWord;
            int anchor = document.redrawParagraph;
            int anchorWord = document.redrawWord;
            if (anchor < 0 || "Fixed".equals(settings.scrollmode))
            {
                anchor = cursorParagraph;
                anchorWord = cursorWord;
            }

            /* Find out the offset of the paragraph at the middle of the screen. */
            anchor = min(anchor, document.paragraphs.size() - 1);
            int middle = max(0, height / 2 - 1);
            int anchorY = middle - lineOfWord(layout(anchor), anchorWord);
            var cursorLayout = layout(cursorParagraph);
            int cursorLine = lineOfWord(cursorLayout, cursorWord);
            int cursorY = anchorY + cursorLine;

            /* Work up and down from the middle to find the real cursor position. */
            for (int p = anchor; p < cursorParagraph; p++)
                cursorY += lineCount(layout(p)) + document.spaceBelow(p);
            for (int p = anchor; p > cursorParagraph; p--)
                cursorY -= lineCount(layout(p - 1)) + document.spaceBelow(p - 1);
            if (cursorY < min(4, middle) || cursorY >= max(height - 5, middle + 1))
            {
                anchor = cursorParagraph;
                anchorWord = cursorWord;
                anchorY = middle - cursorLine;
                cursorY = middle;
            }
            document.redrawParagraph = anchor;
            document.redrawWord = anchorWord;

            /* Position the cursor. */
            Paragraph paragraph = document.paragraphs.get(cursorParagraph);
            int cursorX = textX + paragraph.getIndentOfLine(cursorLine);
            if (!paragraph.words().isEmpty())
            {
                String word = paragraph.words().get(cursorWord);
                cursorX += cursorLayout.xs().get(cursorWord)
                        + screen.getStringWidth(word.substring(0, document.cursorOffset));
            }
            screen.gotoXY(min(right, cursorX), cursorY);

            /* Cache values for mark drawing. */
            if (document.markParagraph >= 0)
            {
                var mark = new Position(document.markParagraph, document.markWord, document.markOffset);
                var cursor = new Position(cursorParagraph, cursorWord, document.cursorOffset);
                boolean markFirst = mark.compareTo(cursor) <= 0;
                start = markFirst ? mark : cursor;
                end = markFirst ? cursor : mark;
            }

            /* Draw backwards. */
            int y = anchorY;
            for (int p = anchor - 1; p >= 0 && y > 0; p--)
            {
                int gap = document.spaceBelow(p);
                clearPaper(y - gap, y - 1);
                var layout = layout(p);
                y -= gap + lineCount(layout);
                drawParagraph(p, layout, y, true);
            }
            if (y > 0)
            {
                int gap = document.spaceAbove(0);
                clearPaper(y - gap, y - 1);
                if (settings.terminators)
                    drawTopMarker(y - gap - 1);
            }

            /* Draw forwards. */
            y = anchorY;
            for (int p = anchor; p < document.paragraphs.size() && y < height; p++)
            {
                var layout = layout(p);
                drawParagraph(p, layout, y, false);
                y += lineCount(layout);
                int gap = document.spaceBelow(p);
                clearPaper(y, y + gap - 1);
                y += gap;
            }
            if (settings.terminators)
                drawBottomMarker(y);

            /* The first and last visible text rows delimit page navigation. */
            document.topParagraph = 0;
            document.topWord = 0;
            document.bottomParagraph = 0;
            document.bottomWord = 0;
            boolean first = true;
            for (var position : lineIndex)
            {
                if (position == null)
                    continue;
                if (first)
                {
                    document.topParagraph = position.paragraph();
                    document.topWord = position.word();
                    first = false;
                }
                document.bottomParagraph = position.paragraph();
                document.bottomWord = position.word();
            }
            return lineIndex;
        }

        /* Wrap paragraphs on demand with the current document width and sentence spacing. */
        private WrapData layout(int paragraph)
        {
            return document.wrapParagraph(paragraph);
        }

        private static int lineCount(WrapData layout)
        {
            return max(1, layout.lines().size());
        }

        private static int lineOfWord(WrapData layout, int word)
        {
            int line = layout.lineOfWord(word);
            return line >= 0 ? line : lineCount(layout) - 1;
        }

        /* Draw visible lines in the requested direction, leaving clipped rows untouched. */
        private void drawParagraph(int index, WrapData layout, int y, boolean backwards)
        {
            var paragraph = document.paragraphs.get(index);
            int first = max(0, -y);
            int last = min(lineCount(layout), height - y) - 1;
            for (int count = 0; count <= last - first; count++)
            {
                int line = backwards ? last - count : first + count;
                int row = y + line;
                int x = textX + paragraph.getIndentOfLine(line);

                /* Clear in the paragraph's style before painting its words. */
                screen.setNormal();
                ui.setColour(paragraph.style().name() + "_FG", paragraph.style().name() + "_BG");
                screen.clearArea(left, row, right, row);
                int word = 0;
                if (!layout.lines().isEmpty())
                {
                    var wrappedLine = layout.lines().get(line);
                    word = wrappedLine.firstWord();
                    if (start != null && end != null)
                        paragraph.renderMarkedLine(wrappedLine, x, row, index, start, end);
                    else
                        paragraph.renderLine(wrappedLine, x, row, true);
                }
                if (line == 0)
                    drawMargin(paragraph, index, row);
                lineIndex[row] = new LinePosition(index, word, textX);
            }
        }

        /* Draw the selected margin label and the paragraph's bullet or number. */
        private void drawMargin(Paragraph paragraph, int index, int y)
        {
            var style = paragraph.style();
            String label = switch (document.viewMode)
            {
                case 2 -> style.name();
                case 3 -> Integer.toString(index + 1);
                case 4 -> Integer.toString(paragraph.words().size());
                default -> "";
            };
            if (!label.isEmpty() && left > 1)
            {
                ui.setColour("StyleFG", "Desktop");
                screen.setDim();
                ui.rAlignInField(0, y, left - 1, label);
            }

            String bullet = style.bullet();
            if (bullet == null && style.numbered())
                bullet = paragraph.number + ".";
            if (bullet != null)
            {
                int width = screen.getStringWidth(bullet) + 1;
                if (style.indent() >= width)
                {
                    screen.setNormal();
                    ui.setColour("LB_FG", "LB_BG");
                    screen.write(left + style.indent() - width, y, bullet);
                }
            }
            screen.setNormal();
        }

        /* Clear only the visible part of a gap between paragraphs. */
        private void clearPaper(int first, int last)
        {
            first = max(first, 0);
            last = min(last, height - 1);
            if (first <= last)
            {
                screen.setNormal();
                ui.setColour("Paper", "Paper");
                screen.clearArea(left, first, right, last);
            }
        }

        /* Draw the ruler and upper edge of the paper. */
        private void drawTopMarker(int y)
        {
            if (y < 0)
                return;
            boolean unicode = screen.useUnicode();
            screen.setNormal();
            ui.setColour("MarkerFG", "Desktop");
            if (y > 2)
            {
                String digits = unicode ? "₀₁₂₃₄₅₆₇₈₉" : "0123456789";
                for (int x = left, number = 0; x <= right; x += 10, number++)
                    screen.write(x, y - 2, digits.substring(number % 10, number % 10 + 1));
            }
            if (y > 1)
            {
                screen.write(left, y - 1, unicode ? "◥" : "\\");
                for (int x = left + 5; x <= right; x += 10)
                    screen.write(x, y - 1, unicode ? "▾" : ".");
                for (int x = left + 10; x <= right; x += 10)
                    screen.write(x, y - 1, unicode ? "▼" : "+");
                screen.write(right, y - 1, unicode ? "◤" : "/");
            }
            drawPaperEdge(y, unicode ? "▔" : "-");
        }

        /* Draw the lower edge and its continuation markers. */
        private void drawBottomMarker(int y)
        {
            if (y >= height)
                return;
            boolean unicode = screen.useUnicode();
            drawPaperEdge(y, unicode ? "▁" : "-");
            if (y + 1 < height)
            {
                ui.setColour("MarkerFG", "Desktop");
                screen.write(left, y + 1, unicode ? "◿" : "/");
                for (int x = left + 10; x <= right; x += 10)
                    screen.write(x, y + 1, unicode ? "△" : "+");
                screen.write(right, y + 1, unicode ? "◺" : "\\");
            }
        }

        private void drawPaperEdge(int y, String glyph)
        {
            screen.setNormal();
            ui.setColour("MarkerFG", "Paper");
            screen.clearArea(left, y, right, y);
            if (right > left + 1)
                screen.write(left + 1, y, glyph.repeat(right - left - 1));
        }
    }
}
