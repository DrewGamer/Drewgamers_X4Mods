del /Q /S ..\packed\ResearchOverhaul_Medium\*
del /Q /S ..\packed\ResearchOverhaul_Medium.zip
rmdir /Q /S ..\packed\ResearchOverhaul_Medium
for %%I in (.\*.cat .\*.dat) do del /Q "%%I"
REM "..\XRCatTool.exe" -in subst_01 -out subst_01.cat -dump
"..\XRCatTool.exe" -in ext_01 -out ext_01.cat -dump
mkdir ..\packed\ResearchOverhaul_Medium
mkdir ..\packed\ResearchOverhaul_Medium\ResearchOverhaul
copy .\content.xml ..\packed\ResearchOverhaul_Medium\ResearchOverhaul\
copy .\ResearchOverhaul.lua ..\packed\ResearchOverhaul_Medium\ResearchOverhaul\
for %%I in (.\*.cat .\*.dat) do move "%%I" ..\packed\ResearchOverhaul_Medium\ResearchOverhaul\
"..\7z\7za.exe" a ..\packed\ResearchOverhaul_Medium.zip ..\packed\ResearchOverhaul_Medium\*
pause