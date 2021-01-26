%define PROT_READ 0x1
%define PROT_WRITE 0x2

global _main

; Arguments : rdi, rsi, rdx, rcx, r8, r9
section .text

%include "io.asm"
%include "mem.asm"
%include "tests.asm"
    
; === === === === === === === === === === === ===  
;                   PROGRAM
; === === === === === === === === === === === ===  
_main:
    call mem@init
    call test@execute
    call mem@uninit

.end:
    call exit



; Dans .data on définie les données
section .data
    new_line:           db  10,0
    ; ERROR MESSAGES
    err_prefix:         db  "ERR:",0
    err_alloc:          db  "While allocating memory",0
    err_alloc_too_big:  db  "The size to allocate was to large",0
    err_read:           db  "While reading the stdin",0
    err_read_too_long:  db  "The input was too long. Maximum number of chars exceeded",0

    ; MESSAGE FOR TESTS
    test_title:         db  "Now doing TEST ",0
    test_success:       db  "...The test succeeded",0
    test_fail:          db  "...The test failed", 0

section .bss
    errno resb 1           ; When we need to print the error number
    io@buffer_char resb 1  ; When we need to print a char
    io@buffer_int resb 64  ; When we need to print a number
    mem@parent_page resb 8 ; Address of the parent page

