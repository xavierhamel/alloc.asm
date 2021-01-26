; This will create an array containing tokens
; () -> (rdi:addr)
toks@new:
    mov rdi, 9
    call arr@new
    ret

; (rdi:addr, sil:kind, edx:start, ecx:end)
toks@push: 
    push rcx
    push rdx
    push rsi
    call arr@push
    call arr@len    
    dec rsi           ; We want the last element not the length

    mov rdx, 0
    mov rcx, 1
    pop r8
    call arr@update
    mov rdx, 1
    mov rcx, 4
    pop r8
    call arr@update
    mov rdx, 5
    pop r8
    call arr@update
    ret

; These functions will return, the kind, the starting position or the ending
; position of the token
; (rdi:arr, rsi:element) -> (rsi:value)
toks@get_kind:
    push rdx
    call arr@get
    mov rdx, rsi
    xor rsi, rsi
    mov sil, byte [rdx]
    pop rdx
    ret
toks@get_start:
    push rdx
    call arr@get
    mov rdx, rsi
    xor rsi, rsi
    mov esi, dword [rdx + 1]
    pop rdx
    ret
toks@get_end:
    push rdx
    call arr@get
    mov rdx, rsi
    xor rsi, rsi
    mov esi, dword [rdx + 5]
    pop rdx
    ret
; This function will create a growable "array" containing tokens
; () -> (rdi:addr)
;toks_new:
    ;mov rdi, 16         ; 8 for the size of the buffer, 8 for the number of elements
    ;call alloc          
    ;mov qword [rdi], 0  ; This is the number of elements in the array
    ;add rdi, 8          ; Move the cursor to the first element (none existent here)
    ;ret

;toks_dealloc:
    ;sub rdi, 8
    ;call dealloc
    ;ret
;; This function will push an element into a buffer
;; (rdi:arr, rsi:kind, edx:start, ecx:end)
;toks_push:
    ;push rax
    ;push r9
    ;push r8
    ;call _toks_is_full
    ;cmp r8, 0
    ;je .push
    ;push rsi
    ;mov rsi, [rdi - 16] ; Get the size of the buffer
    ;imul rsi, 2         ; Double the size of the buffer
    ;sub rdi, 8          ; point the pointer of the buffer at the correct position
    ;call realloc
    ;add rdi, 8
    ;pop rsi
;.push:
    ;mov rax, [rdi - 8]      ; Get the number of element in the buffer
    ;imul rax, 9             ; Compute the position of the next element
    ;mov r9, rdi 
    ;add r9, rax
    ;mov byte [r9], sil      ; Set the kind of the token
    ;mov dword [r9 + 1], edx ; Set the start of the token
    ;mov dword [r9 + 5], ecx ; Set the end of the token
    ;inc rax
    ;mov [rdi - 8], rax      ; Set the new number of element in the list
    ;pop r8
    ;pop r9
    ;pop rax
    ;ret

;; This function will return elements at a specified position
;; (rdi:arr, rsi:element) -> (rsi:addr_element)
;toks_get:
    ;imul rsi, 9
    ;add rsi, rdi
    ;ret

;; These functions will return, the kind, the starting position or the ending
;; position of the token
;; (rdi:arr, rsi:element) -> (rsi:value)
;toks_get_kind:
    ;push rdx
    ;call toks_get
    ;xor rdx, rdx
    ;mov dl, byte [rsi]
    ;mov rsi, rdx
    ;pop rdx
    ;ret
;toks_get_start:
    ;push rdx
    ;call toks_get
    ;xor rdx, rdx
    ;mov edx, dword [rsi + 1]
    ;mov rsi, rdx
    ;pop rdx
    ;ret
;toks_get_end:
    ;push rdx
    ;call toks_get
    ;xor rdx, rdx
    ;mov edx, dword [rsi + 5]
    ;mov rsi, rdx
    ;pop rdx
    ;ret
;; This function will check if there is enough space to add a new element in the
;; buffer
;; (rdi:addr)    
;_toks_is_full:
    ;push rcx
    ;push rsi
    ;mov rsi, [rdi - 16] ; Get the size of the buffer
    ;mov rcx, [rdi - 8]  ; Get the number of element in the buffer
    ;inc rcx
    ;imul rcx, 9         ; Get the number of bytes used (9 bytes per element)
    ;add rcx, 16         ; Number of bytes used for metadata of the buffer
    ;cmp rcx, rsi
    ;jg .is_full
    ;mov r8, 0
    ;pop rsi
    ;pop rcx
    ;ret
;.is_full:
    ;mov r8, 1          ; The array is full
    ;pop rsi
    ;pop rcx
    ;ret
