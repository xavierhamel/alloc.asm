#!/bin/zsh
nasm -f macho64 main.asm
#nasm -f macho64 io.asm
ld -macosx_version_min 10.8 -lSystem -o main main.o 
