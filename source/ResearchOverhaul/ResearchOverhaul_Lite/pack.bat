del /Q /S ..\packed\ResearchOverhaul_Lite\*
del /Q /S ..\packed\ResearchOverhaul_Lite.zip
rmdir /Q /S ..\packed\ResearchOverhaul_Lite
for %%I in (.\*.cat .\*.dat) do del /Q "%%I"
REM "..\XRCatTool.exe" -in subst_01 -out subst_01.cat -dump
"..\XRCatTool.exe" -in ext_01 -out ext_01.cat -dump
mkdir ..\packed\ResearchOverhaul_Lite
mkdir ..\packed\ResearchOverhaul_Lite\ResearchOverhaul
copy .\content.xml ..\packed\ResearchOverhaul_Lite\ResearchOverhaul\
copy .\ResearchOverhaul.lua ..\packed\ResearchOverhaul_Lite\ResearchOverhaul\
for %%I in (.\*.cat .\*.dat) do move "%%I" ..\packed\ResearchOverhaul_Lite\ResearchOverhaul\
"..\7z\7za.exe" a ..\packed\ResearchOverhaul_Lite.zip ..\packed\ResearchOverhaul_Lite\*
pause