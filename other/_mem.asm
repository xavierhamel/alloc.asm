; This function will allocate a region at a specified address
; params(rdi:addr, rsi:len)
_alloc:
    push rax
    push rdx
    push rcx
    push r10
    push r8
    push r9

    ; rsi and rdi are already defined
    mov rax, 0x20000C5              ; mmap
    mov rdx, PROT_READ | PROT_WRITE ; read, write
    mov r10, 0x0002 | 0x1000            ; private map | anonymous
    mov r8, -1                      ; No file descriptor (because of anonymous flag)
    mov r9, 0                       ; No offsets (because of anonymous flag)
    syscall
    jc .error           ; Checking for an error, on mac it's the carry flag
    mov rdi, rax        ; This is the address of the allocated memory

    pop r9
    pop r8
    pop r10
    pop rcx
    pop rdx
    pop rax
    ret
.error:
    mov rdi, err_alloc  
    call panic          ; Throw the error and exit the program
    ret

; This function will allocate a region
; params(rdi:size) -> (rdi:addr)
alloc:
    add rdi, 8          ; Add 8 bytes because the size will also be stored
    mov rsi, rdi        ; The size to allocate
    xor rdi, rdi        ; The OS will decide where to allocate
    call _alloc
    mov [rdi], rsi      ; Put the size of the allocation in the first spot
    add rdi, 8          ; Move the cursor of the region by one byte
    ret

; This function will deallocate a region
; params(rdi:addr)
dealloc:
    push rax
    push rdx            ; The syscall change rdx and rcx
    push rcx
    push rsi

    sub rdi, 8          ; Move to the begining of the region
    mov rsi, [rdi]      ; This is the size of the buffer
    mov rax, 0x2000049
    syscall
    jc .error           ; Checking for an error, on mac it's the carry flag
    
    pop rsi
    pop rcx
    pop rdx
    pop rax
    ret
.error:
    mov rdi, err_alloc  
    call panic          ; Throw the error and exit the program
    ret

; TODO: If we have an error we reallocating (because the new allocation can't
; be placed after the current allocation), copy the buffer elsewhere
_realloc:
    push rcx
    mov rcx, [rdi - 8]  ; Current size
    add rcx, rdi        
    sub rcx, 7          ; (substract 8 because of the size of the buffer
                        ; (stored at the begining) and add 1 for the next address)
    call print_int
    push rdi
    mov rdi, rcx
    call _alloc
    call print_int
    pop rdi
    mov rcx, [rdi - 8]  ; Current size
    add rcx, rsi
    mov [rdi - 8], rcx
    pop rcx
    ret

; This function will create a new growable array and return it
; (di:element_size) -> (rdi:addr)
arr@new:
    push rsi
    push rdi
    mov rdi, 10         ; 8 for the number of element, 2 for the size of 1 element
    call alloc
    mov qword [rdi], 0
    pop rsi
    mov word [rdi + 8], si
    add rdi, 10         ; Point to the first element
    pop rsi
    ret

; Deallocate the array
; (rdi:addr)
arr@dealloc:
    sub rdi, 10
    call dealloc
    ret

; This function will double the size of the buffer
; (rdi:addr)
arr@grow:
    push rsi
    push rcx
    mov rsi, [rdi - 18]         ; Size of the buffer
    xor rcx, rcx
    mov cx, word [rdi - 2]      ; Size of 1 element
    cmp rcx, rsi
    jle .continue               
    add rsi, rcx                ; If the double would not be enough to store 1 element
.continue:
    sub rdi, 10
    call _realloc
    add rdi, 10
    pop rcx
    pop rsi
    ret

; This function will simply add a new empty element to the array
; (rdi:addr)
arr@push:
    push rsi
    push rdx
    push r8
    xor rcx, rcx
    mov cx, word [rdi - 2]      ; Size of 1 element in the array
    mov rdx, qword [rdi - 10]   ; Element count
    mov rsi, qword [rdi - 18]   ; Size of the buffer
    call arr@is_full
    cmp r8, 0
    je .push
    call arr@grow
.push:
    inc rdx
    mov qword [rdi - 10], rdx   ; Incrementing the element count
    pop r8
    pop rdx
    pop rsi
    ret

; This function will return the number of element in the array
; (rdi:addr) -> (rsi:count)
arr@len:
    xor rsi, rsi
    mov rsi, qword [rdi - 10]
    ret

; Update a value of an element at the offset and with n bytes
; (rdi:addr, rsi:no, rdx:offset, rcx:nb_bytes, r8:value)
arr@update:
    call arr@get
    cmp rcx, 1
    jne .next_2
    mov byte [rsi + rdx], r8b
    ret
.next_2:
    cmp rcx, 2
    jne .next_4
    mov word [rsi + rdx], r8w
    ret
.next_4:
    cmp rcx, 4
    jne .next_8
    mov dword [rsi + rdx], r8d
    ret
.next_8:
    cmp rcx, 8
    jne .end
    mov qword [rsi + rdx], r8
.end:
    ret

;arr@remove:
    ;ret

; This function will return the address of the begining of the element
; (rdi:addr, rsi:no) -> (rsi:addr)
arr@get:
    push rdx
    xor rdx, rdx
    mov dx, word [rdi - 2]      ; Get the size of 1 element
    imul rsi, rdx               ; Mult. by the element number
    add rsi, rdi                ; Get the new address
    pop rdx
    ret

; This function will check if there is enough space to push another element in
; the buffer
; (rdi:addr)
arr@is_full:
    push rsi
    push rdx
    push rcx
    mov rsi, qword [rdi - 18]   ; Size of the buffer
    mov rdx, qword [rdi - 10]   ; Number of element in the buffer
    inc rdx                     ; We want to check if it is full with an element more
    xor rcx, rcx
    mov cx, word [rdi - 2]      ; Size of one element
    imul rdx, rcx               ; Size used by the array
    add rdx, 10                 ; Used by other things
    cmp rdx, rsi
    jg .is_full
    mov r8, 0
    jmp .end
.is_full:
    mov r8, 1
.end:
    pop rcx
    pop rdx
    pop rsi
    ret
