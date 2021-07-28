# Majel-1 Zilog Z80 64K Retrocomputer
Firmware assembly source and common libraries

This repository provides several reusable libraries along with the Majel-1 firmware. Those libraries include:
 - Mathematics extensions for long numbers
 - String manipulation routines
 - Serial card driver
 - Majel-FS SD card driver


## Purpose

Majel-1 is a custom-built 64K Z80 retrocomputer with an optional 32K onboard ROM page. This rom page can be enabled 
using a toggle switch and holds the firmware defined in this repository. Using this firmware with the right set of 
I/O cards, a user can load programs from SD cards, test RAM, and a few other functions.


## Dependencies

This project uses RASM for assembling, which can be found here: https://github.com/EdouardBERGE/rasm
The batch file in the root of this project provides the necessary command line arguments.
