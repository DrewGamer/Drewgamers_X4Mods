del /Q /S ..\..\crystal_rarities\*
del /Q /S ..\..\crystal_rarities.zip
rmdir /Q /S ..\..\crystal_rarities
for %%I in (.\*.cat .\*.dat) do del /Q "%%I"
"..\XRCatTool.exe" -in subst_01 -out subst_01.cat -dump
"..\XRCatTool.exe" -in ext_01 -out ext_01.cat -dump
mkdir ..\..\crystal_rarities
copy .\content.xml ..\..\crystal_rarities\
for %%I in (.\*.cat .\*.dat) do move "%%I" ..\..\crystal_rarities\
"..\7z\7za.exe" a ..\..\crystal_rarities.zip ..\..\crystal_rarities\*
pause