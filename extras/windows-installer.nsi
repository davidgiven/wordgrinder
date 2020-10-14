; © 2010 David Given.
; WordGrinder is licensed under the MIT open source license. See the COPYING
; file in this distribution for the full text.
;
; $Id: dpy.c 159 2009-12-13 13:11:03Z dtrg $
; $URL: https://wordgrinder.svn.sf.net/svnroot/wordgrinder/wordgrinder/src/c/arch/win32/console/dpy.c $

!include MUI2.nsh

Name "WordGrinder for Windows"
OutFile "${OUTFILE}"
Unicode True

InstallDir "$PROGRAMFILES\Cowlark Technologies\WordGrinder"

InstallDirRegKey HKLM "Software\Cowlark Technologies\WordGrinder" \
	"InstallationDirectory"

RequestExecutionLevel admin
SetCompressor /solid lzma

;--------------------------------

!define MUI_WELCOMEPAGE_TITLE "WordGrinder for Windows ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "WordGrinder is a word processor for processing \
	words. It is not WYSIWYG. It is not point and click. It is not a desktop \
	publisher. It is not a text editor. It is not do fonts and it barely does \
	styles. What it does do is words. It's designed for writing text. It gets \
	out of your way and lets you type.$\r$\n\
	$\r$\n\
	This wizard will install WordGrinder on your computer.$\r$\n\
	$\r$\n\
	$_CLICK"

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis.bmp"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME

!define MUI_COMPONENTSPAGE_NODESC
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "Installation complete"
!define MUI_FINISHPAGE_TEXT_LARGE
!define MUI_FINISHPAGE_TEXT "WordGrinder is now ready to use. However:$\r$\n\
	$\r$\n\
	Beware! \
	WordGrinder is not a conventional Windows program! You REALLY \
	NEED to read at least the first few paragraphs of the manual. \
	Not kidding.$\r$\n\
	$\r$\n\
	Have fun!"

Function showreadmeaction
	ExecShell "" "$INSTDIR\README.wg"
FunctionEnd

!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Show manual now (strongly, strongly recommended)"
!define MUI_FINISHPAGE_RUN_FUNCTION showreadmeaction
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Utility functions

!define SHCNE_ASSOCCHANGED 0x08000000
!define SHCNF_IDLIST 0

Function RefreshShellIcons
	System::Call 'shell32.dll::SHChangeNotify(i, i, i, i) v \
		(${SHCNE_ASSOCCHANGED}, ${SHCNF_IDLIST}, 0, 0)'
FunctionEnd

Function un.RefreshShellIcons
	System::Call 'shell32.dll::SHChangeNotify(i, i, i, i) v \
		(${SHCNE_ASSOCCHANGED}, ${SHCNF_IDLIST}, 0, 0)'
FunctionEnd

;--------------------------------

; The stuff to install
Section "WordGrinder (required)"
	SectionIn RO
	SetOutPath $INSTDIR
	File /oname=wordgrinder.exe "bin\wordgrinder-builtin-windows-release.exe"
	File /oname=cwordgrinder.exe "bin\wordgrinder-builtin-cwindows-release.exe"
	File "README.wg"
	File "licenses\COPYING.*"

	CreateDirectory $INSTDIR\Dictionaries
	File /oname=Dictionaries\British.dictionary "extras\british.dictionary"
	File /oname=Dictionaries\American-Canadian.dictionary "extras\american-canadian.dictionary"

	; Write the installation path into the registry
	WriteRegStr HKLM SOFTWARE\NSIS_WordGrinder "Install_Dir" "$INSTDIR"

	; Write the uninstall keys for Windows
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\WordGrinder" "DisplayName" "WordGrinder for Windows"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\WordGrinder" "UninstallString" '"$INSTDIR\uninstall.exe"'
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\WordGrinder" "NoModify" 1
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\WordGrinder" "NoRepair" 1
	WriteUninstaller "uninstall.exe"

	; Create a file extension mapping.
	WriteRegStr HKCR ".wg" "" "WordGrinder.Document"

	; Now create the file type.
	WriteRegStr HKCR "WordGrinder.Document" "" "WordGrinder Document"
	WriteRegStr HKCR "WordGrinder.Document\DefaultIcon" "" "$INSTDIR\wordgrinder.exe,0"

	; Add an open action.
	WriteRegStr HKCR "WordGrinder.Document\shell\open\command" "" '"$INSTDIR\wordgrinder.exe" "%1"'

	; Update the shell.
	Call RefreshShellIcons
SectionEnd

Section "Start Menu Shortcuts"
	CreateDirectory "$SMPROGRAMS\WordGrinder"
	CreateShortCut "$SMPROGRAMS\WordGrinder\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
	SetOutPath "$DOCUMENTS"
	CreateShortCut "$SMPROGRAMS\WordGrinder\WordGrinder.lnk" "$INSTDIR\wordgrinder.exe" "" "$INSTDIR\wordgrinder.exe" 0
	CreateShortCut "$SMPROGRAMS\WordGrinder\WordGrinder manual.lnk" "$INSTDIR\wordgrinder.exe" '"$INSTDIR\README.wg"' "$INSTDIR\wordgrinder.exe" 0
SectionEnd

Section "Desktop Shortcut"
	SetOutPath "$DOCUMENTS"
	CreateShortCut "$DESKTOP\WordGrinder.lnk" "$INSTDIR\wordgrinder.exe" "" "$INSTDIR\wordgrinder.exe" 0
SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"
	; Remove registry keys
	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\WordGrinder"
	DeleteRegKey HKLM SOFTWARE\NSIS_WordGrinder
	DeleteRegKey HKCR ".wg"
	DeleteRegKey HKCR "WordGrinder.Document"
	Call un.RefreshShellIcons

	; Remove files and uninstaller
	Delete $INSTDIR\wordgrinder.exe
	Delete $INSTDIR\uninstall.exe
	Delete $INSTDIR\README.wg

	Delete $INSTDIR\COPYING.*
	RMDir /r $INSTDIR\Dictionaries

	; Remove shortcuts, if any
	Delete "$SMPROGRAMS\WordGrinder\*.*"
	Delete "$DESKTOP\WordGrinder.lnk"

	; Remove directories used
	RMDir "$SMPROGRAMS\WordGrinder"
	RMDir "$INSTDIR"
SectionEnd
