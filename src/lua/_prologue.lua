--!strict
-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- Global definitions that the various source files need.

declare function AddEventListener(event: Event, callback: EventCallback)
declare function CLIError(...: string)
declare function CentreInField(x: number, y: number, w: number, s: string)
declare function CliConvert(opt1: string, opt2: string): never
declare function CreateDocument(): Document
declare function CreateDocumentSet(): DocumentSet
declare function CreateMenuTree(): MenuTree
declare function EngageCLI()
declare function GetMaximumAllowedWidth(w: number): number
declare function GetScrollMode(): string
declare function LAlignInField(x: number, y: number, w: number, s: string)
declare function LoadFromFile(filename: string): any?
declare function ModalMessage(title: string?, message: string)
declare function RAlignInField(x: number, y: number, w: number, s: string)
declare function RebuildParagraphStylesMenu(styles: DocumentStyles)
declare function RebuildDocumentsMenu(s: {Document})
declare function ResizeScreen()
declare function SaveToFile(filename: string, object: any): (boolean, string?)
declare function SetColour(fg: Colour?, bg: Colour?)
declare function SetTheme(theme: string)
declare function SetCurrentStyleHint(sor: number, sand: number)
declare function SpellcheckerOff(): boolean
declare function SpellcheckerRestore(state: boolean)
declare function UnSmartquotify(s: string): string
declare function UpdateDocumentStyles()
declare function WantDenseParagraphLayout(): boolean
declare function WantFullStopSpaces(): boolean
declare function WantTerminators(): boolean
declare function NonmodalMessage(s: string)
declare function QueueRedraw()

declare Cmd: {[string]: any}
Cmd = {}

declare Form: {[string]: any}

declare MenuTree: {[string]: any}
declare M: {[string]: any}
declare GlobalSettings: {[string]: {[any]: any}}

type Colour = {number}
type ColourMap = {[string]: Colour}

declare ScreenWidth: number
declare ScreenHeight: number
declare Palette: ColourMap
declare currentDocument: Document
declare documentSet: DocumentSet
declare documentStyles: DocumentStyles
declare marginControllers: {MarginController}

declare ESCAPE_KEY: string

declare BLINK_ON_TIME: number
declare BLINK_OFF_TIME: number
declare IDLE_TIME: number

BLINK_ON_TIME = 0.8
BLINK_OFF_TIME = 0.53
IDLE_TIME = (BLINK_ON_TIME + BLINK_OFF_TIME) * 5

type StatusbarField = {
	priority: number,
	value: string
}

-- Polyfills for Luau.

function loadfile(filename: string)
	local data, e = wg.readfile(filename)
	if data then
		return loadstring(data, filename)
	end
	return nil, e
end

