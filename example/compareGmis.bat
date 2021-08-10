@echo off
echo comparing pandocGmi.md -^> html -^> gmi
echo to pandocGmi.md -^> gmi
echo assuming pandoc on your PATH
pandoc -s ..\doc\pandocGmi.md > pd.html
pandoc -f html -t ..\filters\gmi.lua --template ..\templates\default.gmi pd.html > pd.html.gmi
pandoc -t ..\filters\gmi.lua --template ..\templates\default.gmi ..\doc\pandocGmi.md > pd.gmi
diff pd.gmi pd.html.gmi
