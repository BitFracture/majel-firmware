@ECHO off

cd source
rasm_win64 "majel_firmware_v1.asmz80" -I"." -ob "..\output\majel_firmware_v1.bin" -s -sq -sv -sl -os "..\output\majel_firmware_v1.sym"
pause
