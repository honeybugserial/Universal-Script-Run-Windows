@echo off
setlocal EnableDelayedExpansion
REM ============================================================================
REM Run-Script.bat - find launchable files beside this .bat and run one.
REM
REM   Picks up:  *.ps1  *.py  *.exe  *.bat   (this launcher excludes itself)
REM
REM   * First run (no run_defaults.ini): prompts for script / elevated / args,
REM     launches it in a NEW window, and saves your choices to run_defaults.ini.
REM   * Later runs: shows saved choices and asks a single [Y/n]. Yes = run them,
REM     No = prompt again and update the file.
REM   * NoPrompt=true in the ini: skip ALL prompts and run the defaults silently
REM     (set it by editing the ini). Falls back to prompting only if the saved
REM     script can't be found.
REM
REM   Launch is always a NEW window:
REM     .ps1 -> PowerShell (-NoExit, ExecutionPolicy Bypass)
REM     .py  -> Python via 'py' (falls back to 'python'), in cmd /k
REM     .bat -> cmd /k
REM     .exe -> run directly
REM   Elevated just adds -Verb RunAs (UAC prompt).
REM
REM   Optional extras (saved in run_defaults.ini, honored by NoPrompt too):
REM     PostRun     - a command run in THIS launcher window AFTER spawning the
REM                   script (e.g. a curl test). Prompted after Args.
REM     AfterLaunch - what this launcher window does when done: pause |
REM                   countdown | none. Edit it in the ini. Defaults to
REM                   countdown, or pause when a PostRun command is set.
REM ============================================================================

cd /d "%~dp0"
set "iniFile=%~dp0run_defaults.ini"
set "selfName=%~nx0"

REM ---- collect launchable files (exclude THIS .bat) --------------------------
set "count=0"
for %%F in ("%~dp0*.ps1" "%~dp0*.py" "%~dp0*.exe" "%~dp0*.bat") do (
    if exist "%%~fF" if /i not "%%~nxF"=="%selfName%" (
        set /a count+=1
        set "file[!count!]=%%~fF"
        set "name[!count!]=%%~nxF"
        set "ext[!count!]=%%~xF"
    )
)

if "%count%"=="0" (
    echo No .ps1 / .py / .exe / .bat files found in this folder:
    echo   %~dp0
    echo.
    pause
    exit /b 1
)

REM ---- read defaults file (if present) ---------------------------------------
set "d_script="
set "d_elev="
set "d_args="
set "d_noprompt="
set "d_postrun="
set "d_after="
set "d_delay="
if exist "%iniFile%" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%iniFile%") do (
        if /i "%%A"=="Script"      set "d_script=%%B"
        if /i "%%A"=="Elevated"    set "d_elev=%%B"
        if /i "%%A"=="Args"        set "d_args=%%B"
        if /i "%%A"=="NoPrompt"    set "d_noprompt=%%B"
        if /i "%%A"=="PostRun"      set "d_postrun=%%B"
        if /i "%%A"=="AfterLaunch"  set "d_after=%%B"
        if /i "%%A"=="PostRunDelay" set "d_delay=%%B"
    )
)

REM No ini at all -> straight to prompts.
if not exist "%iniFile%" goto interactive

REM Resolve the saved script name against what's actually present now.
set "resolved="
for /l %%I in (1,1,%count%) do (
    if /i "!name[%%I]!"=="!d_script!" (
        set "chosen=!file[%%I]!"
        set "chosenName=!name[%%I]!"
        set "chosenExt=!ext[%%I]!"
        set "resolved=1"
    )
)
if not defined resolved (
    echo Saved default script "!d_script!" is no longer here -- asking instead.
    echo.
    goto interactive
)

REM Apply saved elevate/args/postrun/after.
if /i "!d_elev!"=="yes" ( set "elevate=1" ) else ( set "elevate=" )
set "scriptArgs=!d_args!"
set "postRun=!d_postrun!"
set "afterLaunch=!d_after!"
set "postDelay=!d_delay!"

REM ---- NoPrompt fast-path: run silently, no questions at all -----------------
if /i "!d_noprompt!"=="true" ( set "silent=1" & echo NoPrompt enabled -- launching defaults... & goto setupRunner )
if /i "!d_noprompt!"=="1"    ( set "silent=1" & echo NoPrompt enabled -- launching defaults... & goto setupRunner )

REM ---- otherwise offer the saved defaults ------------------------------------
echo Saved defaults found (run_defaults.ini):
echo   Script   : !d_script!
echo   Elevated : !d_elev!
if defined scriptArgs (echo   Args     : !scriptArgs!) else (echo   Args     : ^(none^))
if defined postRun (echo   PostRun  : !postRun!)
echo.
:useLoop
set "useAns="
set /p "useAns=Run with these saved defaults? [Y/n]: "
if not defined useAns set "useAns=Y"
if /i "!useAns!"=="Y"   goto setupRunner
if /i "!useAns!"=="YES" goto setupRunner
if /i "!useAns!"=="N"   goto interactive
if /i "!useAns!"=="NO"  goto interactive
echo   Please answer y or n.
goto useLoop

REM ===========================================================================
REM Interactive prompts (first run, or when declining saved defaults)
REM ===========================================================================
:interactive

REM ---- choose which script ---------------------------------------------------
if "%count%"=="1" (
    set "chosen=!file[1]!"
    set "chosenName=!name[1]!"
    set "chosenExt=!ext[1]!"
    echo Found one: !chosenName!
    goto gotChoice
)

REM Picker is at top level (NOT inside a ( ) block) so the array index expands
REM at runtime. We also use 'call set ...%%arr[!pick!]%%' so the chosen index is
REM resolved with the typed value, not a parse-time-empty one.
echo Launchable files found:
echo.
for /l %%I in (1,1,%count%) do echo   %%I^) !name[%%I]!
echo.
:pickLoop
set "pick="
set /p "pick=Enter the number to run [1-%count%]: "
if not defined pick goto pickLoop
set "test=!pick!"
for /f "delims=0123456789" %%X in ("!pick!") do set "test=bad"
if "!test!"=="bad" ( echo   Please enter a number. & goto pickLoop )
if !pick! LSS 1 ( echo   Out of range. & goto pickLoop )
if !pick! GTR %count% ( echo   Out of range. & goto pickLoop )
call set "chosen=%%file[!pick!]%%"
call set "chosenName=%%name[!pick!]%%"
call set "chosenExt=%%ext[!pick!]%%"
:gotChoice

echo.
echo Selected: !chosenName!
echo.

REM ---- elevated? -------------------------------------------------------------
set "elevate="
:elevLoop
set "elevAns="
set /p "elevAns=Run elevated (as Administrator)? [y/N]: "
if not defined elevAns set "elevAns=N"
if /i "!elevAns!"=="Y"   ( set "elevate=1" & goto elevDone )
if /i "!elevAns!"=="YES" ( set "elevate=1" & goto elevDone )
if /i "!elevAns!"=="N"   ( set "elevate="  & goto elevDone )
if /i "!elevAns!"=="NO"  ( set "elevate="  & goto elevDone )
echo   Please answer y or n.
goto elevLoop
:elevDone

REM ---- arguments -------------------------------------------------------------
echo.
echo Enter any arguments to pass (leave blank for none).
set "scriptArgs="
set /p "scriptArgs=Arguments: "

REM ---- post-run command ------------------------------------------------------
echo.
echo Enter a command to run in THIS window after launching (leave blank for none).
echo   e.g. a quick test like:  curl.exe -x socks5h://127.0.0.1:11080 https://api.ipify.org
set "postRun="
set /p "postRun=Post-run command: "

REM ---- save choices as the new defaults --------------------------------------
REM Preserve any existing NoPrompt / AfterLaunch values; default them otherwise.
if not defined d_noprompt set "d_noprompt=false"
if defined d_after ( set "afterLaunch=!d_after!" ) else ( set "afterLaunch=countdown" )
if defined d_delay ( set "postDelay=!d_delay!" ) else ( set "postDelay=3" )
if defined elevate ( set "elevState=yes" ) else ( set "elevState=no" )
(
    echo # Run-Script defaults - delete this file to be prompted fresh.
    echo # Set NoPrompt=true to always run these defaults with no prompts.
    echo # AfterLaunch controls this launcher window when done: pause, countdown, or none.
    echo # PostRunDelay = seconds to wait after launch before the PostRun command.
    echo NoPrompt=!d_noprompt!
    echo AfterLaunch=!afterLaunch!
    echo PostRunDelay=!postDelay!
    echo Script=!chosenName!
    echo Elevated=!elevState!
    echo Args=!scriptArgs!
    echo PostRun=!postRun!
) > "%iniFile%"
echo.
echo Saved these choices to run_defaults.ini

REM ===========================================================================
REM Build runner + launch (shared by all paths)
REM ===========================================================================
:setupRunner

REM Elevation is just a flag on the launch - RunAs raises the UAC prompt.
if defined elevate ( set "verb= -Verb RunAs" ) else ( set "verb=" )

REM Interpreter / launch style by extension (independent ifs; one will match).
set "runner="
set "runnerName="
if /i "!chosenExt!"==".ps1" set "runnerName=PowerShell"
if /i "!chosenExt!"==".bat" set "runnerName=Batch (cmd)"
if /i "!chosenExt!"==".exe" set "runnerName=Executable"
if /i "!chosenExt!"==".py" (
    where py >nul 2>&1
    if !errorlevel! EQU 0 ( set "runner=py" ) else ( set "runner=python" )
    set "runnerName=Python (!runner!)"
)

echo.
echo ----------------------------------------------------------------------
echo  File     : !chosenName!
echo  Runner   : !runnerName!
if defined elevate (echo  Elevated : yes) else (echo  Elevated : no)
if defined scriptArgs (echo  Args     : !scriptArgs!) else (echo  Args     : ^(none^))
echo ----------------------------------------------------------------------
echo.

REM ---- run (always a NEW window) ---------------------------------------------
if /i "!chosenExt!"==".ps1" goto runPS
if /i "!chosenExt!"==".py"  goto runPY
if /i "!chosenExt!"==".bat" goto runBAT
goto runEXE

:runPS
if defined scriptArgs (
    powershell -NoProfile -Command "Start-Process powershell.exe!verb! -ArgumentList '-NoExit -ExecutionPolicy Bypass -File \"!chosen!\" !scriptArgs!'"
) else (
    powershell -NoProfile -Command "Start-Process powershell.exe!verb! -ArgumentList '-NoExit -ExecutionPolicy Bypass -File \"!chosen!\"'"
)
goto afterRun

:runPY
if defined scriptArgs (
    powershell -NoProfile -Command "Start-Process cmd.exe!verb! -ArgumentList '/k','!runner! \"!chosen!\" !scriptArgs!'"
) else (
    powershell -NoProfile -Command "Start-Process cmd.exe!verb! -ArgumentList '/k','!runner! \"!chosen!\"'"
)
goto afterRun

:runBAT
if defined scriptArgs (
    powershell -NoProfile -Command "Start-Process cmd.exe!verb! -ArgumentList '/k','\"!chosen!\" !scriptArgs!'"
) else (
    powershell -NoProfile -Command "Start-Process cmd.exe!verb! -ArgumentList '/k','\"!chosen!\"'"
)
goto afterRun

:runEXE
if defined scriptArgs (
    powershell -NoProfile -Command "Start-Process -FilePath \"!chosen!\"!verb! -ArgumentList '!scriptArgs!'"
) else (
    powershell -NoProfile -Command "Start-Process -FilePath \"!chosen!\"!verb!"
)
goto afterRun

:afterRun
REM The script is now in its own window. The rest runs in THIS launcher window:
REM an optional post-run command, then the after-launch behavior.

echo.
if defined elevate (echo Launched in a new elevated window.) else (echo Launched in a new window.)

REM ---- post-run command (runs HERE, after spawning the script) ---------------
if defined postRun (
    REM Give the launched process time to come up (bind its port, etc.) before
    REM the post-run command runs. Seconds come from PostRunDelay (default 3).
    if not defined postDelay set "postDelay=3"
    set "waitN=!postDelay!"
    set "ok="
    for /f "delims=0123456789" %%X in ("!waitN!") do set "ok=bad"
    if defined ok set "waitN=3"
    if !waitN! GTR 0 (
        echo.
        echo Waiting !waitN!s for the process to start...
        REM ping gives ~1s per extra count and never has stdin issues.
        set /a pings=!waitN!+1
        ping -n !pings! 127.0.0.1 >nul
    )
    echo.
    echo Post-run: !postRun!
    echo ----------------------------------------------------------------------
    call !postRun!
    echo ----------------------------------------------------------------------
)

REM ---- after-launch behavior: pause ^| countdown ^| none ----------------------
REM Default to countdown if unset. If a post-run command ran and nothing was
REM explicitly set, prefer pause so its output stays readable.
if not defined afterLaunch (
    if defined postRun ( set "afterLaunch=pause" ) else ( set "afterLaunch=countdown" )
)

if /i "!afterLaunch!"=="none"  goto afterDone
if /i "!afterLaunch!"=="pause" (
    echo.
    pause
    goto afterDone
)

REM countdown (default)
echo.
<nul set /p "=Closing"
for /l %%S in (3,-1,1) do (
    <nul set /p "=...%%S"
    ping -n 2 127.0.0.1 >nul
)
echo .

:afterDone
endlocal
