; This function will return the length of the string present in the rdi
; register
; (rdi:str) -> rsi:len
string_len:
    xor rsi, rsi
.loop:
    cmp byte [rdi + rsi], 0
    je .end
    inc rsi
    jmp .loop
.end:
    ret

; This function will print the str
; (rdi:str)
print:
    push rax
    push rsi
    push rdx
    push rdi
    push rcx

    call string_len
    mov rdx, rsi
    mov rsi, rdi
    mov rax, 0x2000004  ; This is the syscall to print
    mov rdi, 1          ; Print to the stdout
    syscall
    
    pop rcx
    pop rdi
    pop rdx
    pop rsi
    pop rax
    ret


; This function will call print the str and add a new line at the end of the
; string.
; (rdi:str)
println:
    call print
    push rdi
    mov rdi,10 
    call print_char
    pop rdi
    ret

; This function will print only one character
; (rdi:char)
print_char:
    push rax
    push rdx
    push rsi
    push rcx

    mov byte [rel io@buffer_char], dil
    mov rdx, 1          ; The length to print
    mov rsi, io@buffer_char ; The char to print
    mov rax, 0x2000004  ; syscall no
    mov rdi, 1          ; Print to the stdout
    syscall

    pop rcx
    pop rsi
    pop rdx
    pop rax
    ret

; This function will print a number as a 8-bit binary number
; (dil:int)
print_binary:
    push rax
    push rcx
    push rdi
    mov al, 10000000b
    mov cl, dil
.loop:
    mov dil, cl
    and dil, al
    cmp dil, 0
    mov rdi, 48
    je .continue
.print_one:
    mov rdi, 49
.continue:
    call print_char
    cmp al, 1
    shr al, 1
    jne .loop
    pop rdi
    pop rcx
    pop rax
    ret
; This function will print a number stored in the rdi register
; (rdi:int)
print_int:
    cmp rdi, 0
    je .zero

    push rax
    push rcx
    push rdx
    push r8
    push r9
    push rdi

    mov rax, rdi
    mov rcx, 10         ; Set the divisor
    lea r8, [rel io@buffer_int + 63]  
    lea r9, [rel io@buffer_int]
.loop:
    xor rdx, rdx        ; Setting rdx to 0, needed for the division
    cmp rax, 0          ; Checking if we are at the end of the number
    je .fill            
    div rcx             ; Getting the last digit of the remaining number
    add rdx, 48         ; Converting the number to the ascii value
    mov byte [r8], dl   ; Saving the digit
    dec r8
    jmp .loop
.fill:
    mov byte [r8], 2    ; Filling the remaining of 64 with a "start of text" char
    cmp r8, r9          ; Checking if we are at the end
    je .end
    dec r8
    jmp .fill
.end:
    mov rdi, io@buffer_int
    call print          ; Actually printing the number
    mov rdi, 32
    call print_char

    pop rdi
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret
.zero:
    push rdi
    push rcx
    mov rdi, 48
    call print_char
    mov rdi, 32
    call print_char
    pop rcx
    pop rdi
    ret

print_int_rax:
    push rdi
    mov rdi, rax
    call print_int
    pop rdi
    ret
print_int_rbx:
    push rdi
    mov rdi, rbx
    call print_int
    pop rdi
    ret
print_int_rcx:
    push rdi
    mov rdi, rcx
    call print_int
    pop rdi
    ret
print_int_rdx:
    push rdi
    mov rdi, rdx
    call print_int
    pop rdi
    ret
print_int_rsp:
    push rdi
    mov rdi, rsp
    call print_int
    pop rdi
    ret
print_int_rsi:
    push rdi
    mov rdi, rsi
    call print_int
    pop rdi
    ret
; This function will read the terminal and return it in the given buffer. If
; the buffer is too small, it will reallocate a bigger buffer. It will add a
; NULL byte at the end of the buffer. This function return nothing
; (rdi:buff) -> rdi:buff, rsi:char_read
read:
    push rax
    push rsi
    push rdx
    push rdi

    mov rsi, rdi        ; Move the buffer to the correct register
    mov rdx, [rsi - 8]  ; This is the size of the buffer
    sub rdx, 8          ; The first 8 bytes are used for the size of the buffer
    mov rax, 0x2000003  ; Read from the offset
    mov rdi, 0          ; Read the stdin
    syscall
    jc .error           ; If error is on the carry flag
    pop rdi             ; Get the pointer to the buffer
    mov byte [rdi + rax], 0 ; Add a NULL byte at the end of the string
    cmp rax, [rsi - 8]
    je .too_long

    pop rdx
    pop rsi
    ret                 ; return the address of the buffer in rdi and size in rsi
.too_long:
    mov rdi, err_read_too_long
    call panic
    ret
.error:
    mov rdi, err_read  
    call panic          ; Throw the error and exit the program
    ret
; This function will read the stderr for an error code and return it
; () -> rdi:int
read_err:
    push rax
    push rdi
    push rsi
    push rdx

    mov rax, 0x2000003  ; This is the syscall to read
    mov rdi, 2          ; Read the stderr
    mov rsi, errno      ; The buffer
    mov rdx, 1          ; The number of byte to write to the buffer
    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

; This function will print the error message and exit the program
; (rdi:err) ->
panic: 
    push rdi

    mov rdi, err_prefix
    call print
    pop rdi
    call println

    mov rax, -1
    ret

; This function will exit the program
exit:
    mov rax, 0x2000001  ; exit
    mov rdi, 0          ; exit code 0, success
    syscall
    ret
