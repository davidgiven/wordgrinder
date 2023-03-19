-- © 2023 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

type Colour = {number}
type InputEvent = {x: number, y: number, b: boolean} | string

type Stat = {
	size: number,
	mode: number
}

declare wg: {
	exit: (number) -> never,
	getchar: () -> InputEvent,
	getcwd: () -> string,
	printerr: (...string) -> never,
	printout: (...string) -> never,
	readfile: (string) -> (string?, string?, number?),
	remove: (string) -> (boolean, string?, number?),
	rename: (string, string) -> (boolean, string?, number?),
	setcolour: (Colour, Colour) -> never,
	useunicode: () -> boolean,
	writefile: (string, string) -> (boolean, string?, number?),
	getstringwidth: (string) -> number,
	setnormal: () -> never,
	setreverse: () -> never,
	setbright: () -> never,
	setbold: () -> never,
	gotoxy: (number, number) -> never,
	cleartoeol: () -> never,
	write: (number, number, string) -> never,
	access: (string, number) -> (boolean, string?, number?),
	stat: (string) -> (Stat?, string?, number?),
	chdir: (string) -> (boolean, string?, number?),
	getwordtext: (string) -> string,
	clipboard_get: () -> (string?, string?),
	clipboard_set: (string?, string?) -> never,
	writeu8: (number) -> string,
	readu8: (string, number) -> (number, number),
	getstylefromword: (string, number) -> number,
	applystyletoword: (string, number, number, number, number, number) -> (string, number),
	deletefromword: (string, number, number) -> string,
	insertintoword: (string, string, number, number) -> (string, number?, number?),
	prevcharinword: (string, number) -> number?,
	nextcharinword: (string, number) -> number?,
	getwordtext: (string) -> string,
	initscreen: () -> never,
	deinitscreen: () -> never,

	DIM: number,
	UNDERLINE: number,
	BOLD: number,
	ITALIC: number,
	REVERSE: number,

	W_OK: number,
	R_OK: number,

	ENOENT: number,
}

declare VERSION: string
declare FILEFORMAT: number
declare ARCH: string

