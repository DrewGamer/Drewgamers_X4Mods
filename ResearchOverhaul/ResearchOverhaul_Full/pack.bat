del /Q /S ..\packed\ResearchOverhaul_Full\*
rmdir /Q /S ..\packed\ResearchOverhaul_Full
for %%I in (.\*.cat .\*.dat) do del /Q "%%I"
"..\XRCatTool.exe" -in subst_01 -out subst_01.cat -dump
"..\XRCatTool.exe" -in ext_01 -out ext_01.cat -dump
mkdir ..\packed\ResearchOverhaul_Full
copy .\content.xml ..\packed\ResearchOverhaul_Full\
for %%I in (.\*.cat .\*.dat) do move "%%I" ..\packed\ResearchOverhaul_Full\
pause