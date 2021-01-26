test@title:
    push rdi
    mov rdi, test_title
    call print
    pop rdi
    call print_int
    ret

test@success:
    push rdi
    mov rdi, test_success
    call println
    pop rdi
    ret

test@fail:
    push rdi
    mov rdi, test_fail
    call println
    pop rdi
    ret

test@execute:
    call test@alloc
    call test@dealloc
    call test@realloc
    call test@alloc_max_size
    call test@remove_page
    ret

; () -> (rdi:addr)
test@alloc:
    push rsi
    push rdx
    mov rdi, 0 
    call test@title
    mov rdi, 20
    call mem@alloc               ; This should return an allocation of 32 bytes in size
    push rdi
    ; Checking if the correct size was allocated
    cmp dword [rdi], 32
    jne .failed
    ; Checking if it was mapped correctly
    mov rsi, 32
    call mem@is_free_space_at
    cmp rdi, 1
    je .failed
    mov rdi, [rsp]
    add rdi, 32
    call mem@is_free_space_at
    cmp rdi, 1
    jne .failed
    call test@success
    jmp .end
.failed:
    call test@fail
.end:
    pop rdi
    pop rdx
    pop rsi
    ret

; (rdi:addr)
test@dealloc:
    push rsi
    push rdi
    mov rdi, 1
    call test@title
    pop rdi
    ; The allocation of the previous test is used
    call mem@dealloc
    ; Checking if the space is free at the location
    mov rsi, 32
    call mem@is_free_space_at
    cmp rdi, 1
    jne .failed
    call test@success
    jmp .end
.failed:
    call test@fail
.end:
    pop rsi
    ret

test@realloc:
    push rdi
    push rsi
    mov rdi, 2
    call test@title
    mov rdi, 20
    call mem@alloc
    mov rsi, 248
    call mem@realloc
    ; Checking if the correct size was allocated
    cmp dword [rdi], 256
    jne .failed
    ; Checking if it was mapped correctly
    push rdi
    mov rsi, 256
    call mem@is_free_space_at
    cmp rdi, 1
    je .failed
    pop rdi
    add rdi, 256
    call mem@is_free_space_at
    cmp rdi, 1
    jne .failed
    call test@success
    jmp .end
.failed:
    call test@fail
.end:
    pop rsi
    pop rdi
    ret

test@alloc_max_size:
    push rsi
    mov rdi, 3
    call test@title
    mov rdi, 4060
    call mem@alloc
    push rdi
    call mem@get_page_count
    cmp rdi, 2 
    jne .failed
    mov rdi, [rsp]
    mov rsi, 4060
    call mem@is_free_space_at
    cmp rdi, 1
    je .failed
    call test@success
    jmp .end
.failed:
    call test@fail
.end:
    pop rdi
    pop rsi
    ret

test@remove_page:
    push rdi
    mov rdi, 4
    call test@title
    pop rdi

    call mem@dealloc
    call mem@get_page_count
    cmp rdi, 1
    jne .failed
    call test@success
    jmp .end
.failed:
    call test@fail
.end:
    ret

