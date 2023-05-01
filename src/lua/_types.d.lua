-- © 2023 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

type Colour = {number}
type InputEvent = {x: number, y: number, b: boolean} | string

type Stat = {
	size: number,
	mode: string
}

type Markdown = any
type MarkdownIterator = any

declare wg: {
	access: (string, number) -> (boolean, string?, number?),
	applystyletoword: (string, number, number, number, number, number) -> (string, number),
	chdir: (string) -> (boolean, string?, number?),
	cleararea: (number, number, number, number) -> never,
	clearscreen: () -> never,
	cleartoeol: () -> never,
	clipboard_get: () -> (string?, string?),
	clipboard_set: (string?, string?) -> never,
	compress: (string) -> string,
	createstylebyte: (number) -> string,
	decompress: (string) -> string,
	deinitscreen: () -> never,
	deletefromword: (string, number, number) -> string,
	escape: (string) -> string,
	exit: (number) -> never,
	getboundedstring: (string, number) -> string,
	getbytesofcharacter: (string) -> {number},
	getchar: (number?) -> InputEvent,
	getcwd: () -> string,
	getenv: (string) -> string?,
	getscreensize: () -> (number, number),
	getstringwidth: (string) -> number,
	getstylefromword: (string, number) -> number,
	getwordtext: (string) -> string,
	getwordtext: (string) -> string,
	gotoxy: (number, number) -> never,
	hidecursor: () -> never,
	initscreen: () -> never,
	insertintoword: (string, string, number, number) -> (string, number?, number?),
	mkdir: (string) -> (boolean, string?, number?),
	mkdirs: (string) -> (boolean, string?, number?),
	nextcharinword: (string, number) -> number?,
	parseword: (string, number, (number, string) -> never) -> never,
	prevcharinword: (string, number) -> number?,
	printerr: (...string) -> never,
	printout: (...string) -> never,
	readdir: (string) -> (boolean, string?, number?),
	readfile: (string) -> (string?, string?, number?),
	readfromzip: (string, string) -> string?,
	readu8: (string, number) -> (number, number),
	remove: (string) -> (boolean, string?, number?),
	rename: (string, string) -> (boolean, string?, number?),
	setbold: () -> never,
	setbright: () -> never,
	setcolour: (Colour, Colour) -> never,
	setdim: () -> never,
	setnormal: () -> never,
	setreverse: () -> never,
	setunderline: () -> never,
	setunicode: (boolean) -> never,
	showcursor: () -> never,
	stat: (string) -> (Stat?, string?, number?),
	sync: () -> never,
	time: () -> number,
	transcode: (string) -> string,
	unescape: (string) -> string,
	useunicode: () -> boolean,
	write: (number, number, string) -> never,
	writefile: (string, string) -> (boolean, string?, number?),
	writestyled: (number, number, string, number, number, number, number) -> number,
	writeu8: (number) -> string,
	writezip: (string, {[string]: string}) -> boolean?,

	BOLD: number,
	BRIGHT: number,
	DIM: number,
	ITALIC: number,
	REVERSE: number,
	UNDERLINE: number,

	W_OK: number,
	R_OK: number,

	EACCES: number,
	EEXIST: number,
	EISDIR: number,
	ENOENT: number,
}

declare FRONTEND: string
declare DEBUG: boolean
declare VERSION: string
declare FILEFORMAT: number
declare ARCH: string

declare function CMarkParse(data: string): Markdown
declare function CMarkIterate(node: Markdown): MarkdownIterator
declare function CMarkNext(iter: MarkdownIterator): (number, number, string?)
declare function CMarkGetHeading(node: Markdown): number
declare function CMarkGetList(node: Markdown): number

declare CMARK_EVENT_NONE: number
declare CMARK_EVENT_DONE: number
declare CMARK_EVENT_ENTER: number
declare CMARK_EVENT_EXIT: number

declare CMARK_NO_LIST: number
declare CMARK_BULLET_LIST: number
declare CMARK_ORDERED_LIST: number

declare CMARK_NODE_DOCUMENT: number
declare CMARK_NODE_BLOCK_QUOTE: number
declare CMARK_NODE_LIST: number
declare CMARK_NODE_ITEM: number
declare CMARK_NODE_CODE_BLOCK: number
declare CMARK_NODE_HTML_BLOCK: number
declare CMARK_NODE_CUSTOM_BLOCK: number
declare CMARK_NODE_PARAGRAPH: number
declare CMARK_NODE_HEADING: number
declare CMARK_NODE_THEMATIC_BREAK: number
declare CMARK_NODE_TEXT: number
declare CMARK_NODE_SOFTBREAK: number
declare CMARK_NODE_LINEBREAK: number
declare CMARK_NODE_CODE: number
declare CMARK_NODE_HTML_INLINE: number
declare CMARK_NODE_CUSTOM_INLINE: number
declare CMARK_NODE_EMPH: number
declare CMARK_NODE_STRONG: number
declare CMARK_NODE_LINK: number
declare CMARK_NODE_IMAGE: number

declare class Palette
	ControlFG: Colour
	ControlBG: Colour
end
declare Palette: Palette

