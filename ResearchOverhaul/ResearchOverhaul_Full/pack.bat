del /Q /S ..\packed\ResearchOverhaul_Full\*
del /Q /S ..\packed\ResearchOverhaul_Full.zip
rmdir /Q /S ..\packed\ResearchOverhaul_Full
for %%I in (.\*.cat .\*.dat) do del /Q "%%I"
REM "..\XRCatTool.exe" -in subst_01 -out subst_01.cat -dump
"..\XRCatTool.exe" -in ext_01 -out ext_01.cat -dump
mkdir ..\packed\ResearchOverhaul_Full
mkdir ..\packed\ResearchOverhaul_Full\ResearchOverhaul
copy .\content.xml ..\packed\ResearchOverhaul_Full\ResearchOverhaul\
copy .\ResearchOverhaul.lua ..\packed\ResearchOverhaul_Full\ResearchOverhaul\
for %%I in (.\*.cat .\*.dat) do move "%%I" ..\packed\ResearchOverhaul_Full\ResearchOverhaul\
"..\7z\7za.exe" a ..\packed\ResearchOverhaul_Full.zip ..\packed\ResearchOverhaul_Full\*
pause