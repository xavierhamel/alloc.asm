; Token
; TokKind   : u8
; Start     : u32
; End       : u32

; This function will scan 
; (rdi:chars)
init_scanner:
    mov rsi, rdi 
    call toks@new       ; rdi has the addr of the buffer
    call scan_chars
    ;mov rsi, 8
    ;mov edx, 10
    ;mov ecx, 16
    ;call toks@push
    mov rsi, 1
    call toks@get_end
    call print_int_rsi 
    
    call arr@dealloc
    ret 

; (rdi:buff, rsi:chars)
scan_chars:
    push r8             
    push r9             
    push r10
    push rax            
    push rdx
    push rcx
    xor eax, eax        ; The counter
.loop:
    xor r8, r8  
    mov r8b, byte [rsi + rax]   ; Get the character ascii code
    cmp r8b, 0                  ; Check if we are at the end of the string
    je .end                     
    call scan_char              ; Get the type of the char
    cmp r9, TOK_NUM             ; Handle the num if it's a number
    je .handle_num
    push rsi
    mov rsi, r9
    mov edx, eax
    mov ecx, eax
    call toks@push              ; Else push the char in the array
    pop rsi
    inc eax
    jmp .loop
.handle_num:
    mov r10d, eax                ; Save the starting positon of the num    
.loop_num:    
    inc eax                     
    mov r8b, byte [rsi + rax]   ; Get the character ascii code
    call scan_char              ; Get the type of the char
    cmp r9, TOK_NUM
    jne .end_num                ; If it's not a number end the number
    jmp .loop_num               ; If it's a number, continue the loop to find the end
.end_num:
    dec eax     
    push rsi
    mov rsi, TOK_NUM            
    mov edx, r10d
    mov ecx, eax
    call toks@push              ; Add the number to the array
    pop rsi
    inc eax
    jmp .loop
.end:
    pop rcx
    pop rdx
    pop rax
    pop r10
    pop r9
    pop r8
    ret

scan_char:
    cmp r8, 43
    je .is_plus
    cmp r8, 45
    je .is_minus
    cmp r8, 42
    je .is_star
    cmp r8, 47
    je .is_slash
    cmp r8, 40
    je .is_l_paren
    cmp r8, 41
    je .is_r_paren
    cmp r8, 32
    je .is_space
    cmp r8, 46
    je .is_dot
    cmp r8, 57      ; If greater than 57 and less than 48 (between 48 and 57 is numbers)
    jg .is_other
    cmp r8, 48
    jl .is_other
    jmp .is_num     
.is_plus:
    mov r9, TOK_PLUS
    ret
.is_minus:
    mov r9, TOK_MINUS
    ret
.is_star:
    mov r9, TOK_STAR
    ret
.is_slash:
    mov r9, TOK_SLASH
    ret
.is_l_paren:
    mov r9, TOK_L_PAREN
    ret
.is_r_paren:
    mov r9, TOK_R_PAREN
    ret
.is_num:
    mov r9, TOK_NUM
    ret
.is_space:
    mov r9, TOK_SPACE
    ret
.is_dot:
    mov r9, TOK_DOT
    ret
.is_other:
    mov r9, TOK_OTHER
    ret
