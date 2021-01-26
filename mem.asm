; The first part of the first page will hold the data about the allocations. The
; first 32 bytes of every pages will hold data about which part are free and
; which part are not in that page. This is in resolution of 16 bytes at the
; time. A 1 means used and a 0 means free. The next byte of the first page will
; hold the number of pages. The next 1024 bytes will hold the addresses to each
; pages.
; 
; For the first page, the first 1057 bytes are filled with data (the first 67
; bits (rounded to 9 bytes) will be set to ones)
;
; Because of the design, it can only allocate up to 1 megabyte of memory and
; 3480 bytes at a time maximum per allocation
;
; This function will init the heap
; () -> ()
mem@init:
    call mem@mmap               ; Get the first page where the data about the
                                ; allocation will be put
    ; Set the bytes used in this page
    mov qword [rdi], -1
    mov byte [rdi + 8], -1

    mov qword [rdi + 9], 0
    mov qword [rdi + 17], 0
    mov qword [rdi + 25], 0     ; We are writing a little bit further than the
                                ; area for the mapping but it doesn't matter
    mov byte [rdi + 32], 1      ; Set the number of pages present
    mov [rdi + 33], rdi         ; Set the address of this page

    mov [rel mem@parent_page], rdi
    ret

; This function will free everything that was allocated with this library
; () -> ()
mem@uninit:
    push rdi
    call mem@get_page_count
    dec rdi
.loop:                          ; This loop remove all the pages
    cmp rdi, 0
    je .end
    call mem@remove_page
    dec rdi
    jmp .loop
.end:
    mov rdi, [rel mem@parent_page]
    call mem@munmap             ; Remove the parent page
    pop rdi
    ret
    
; This function do a syscall and call mmap to get the 4kb page (4kb is the
; maximum)
; () -> (rdi:addr)
mem@mmap:
    push rsi
    push rax
    push rdx
    push rcx
    push r10
    push r8
    push r9

    ; rsi and rdi are already defined
    mov rax, 0x20000C5              ; mmap
    mov rdx, PROT_READ | PROT_WRITE ; read, write
    mov r10, 0x0002 | 0x1000        ; private map | anonymous
    mov r8, -1                      ; No file descriptor (because of anonymous flag)
    mov r9, 0                       ; No offsets (because of anonymous flag)
    mov rdi, 0                      ; The OS decide where to put the memory
    mov rsi, 4096                   ; Get 4kb
    syscall
    jc .error                       ; Checking for an error, on mac it's the carry flag
    mov rdi, rax                    ; This is the address of the allocated memory
    
    ; Indicating the used space in this page
    mov dword [rdi], 0x000000C0
    mov dword [rdi + 4], 0
    mov qword [rdi + 8], 0
    mov qword [rdi + 16], 0
    mov qword [rdi + 24], 0

    pop r9
    pop r8
    pop r10
    pop rcx
    pop rdx
    pop rax
    pop rsi
    ret
.error:
    mov rdi, err_alloc  
    call panic          ; Throw the error and exit the program
    ret

; This function will unmap a page at a given address
; (rdi:addr) -> ()
mem@munmap:
    push rdi
    push rax
    push rdx            ; The syscall change rdx and rcx
    push rcx
    push rsi

    mov esi, [rdi]      ; This is the size of the buffer
    mov rax, 0x2000049
    syscall
    jc .error           ; Checking for an error, on macos it's the carry flag
    
    pop rsi
    pop rcx
    pop rdx
    pop rax
    pop rdi
    ret
.error:
    mov rdi, err_alloc  
    call panic          ; Throw the error and exit the program
    ret

; This call mem@mmap and initialize the page returned
; () -> (rdi:addr, rsi:page_no)
mem@new_page:
    push rax
    call mem@mmap
    push rdi
    mov rax, [rel mem@parent_page] 
    ; Updating the information about available pages on the first one
    xor rsi, rsi
    mov sil, byte [rax + 32]        ; The current number of pages
    push rsi
    imul rsi, 8
    add rsi, 33
    add rsi, rax
    mov [rsi], rdi                  ; Save the address of this page at the next free location
    pop rsi
    inc rsi
    mov byte [rax + 32], sil        ; Set the new correct number of pages
    dec rsi                         ; This is the page no

    pop rdi
    pop rax
    ret

; This function will delete a page. It will update the page count in the parent
; page and align all the addresses of the other pages
; TODO TEST THIS FUNCTION
; (rdi:page_no)
mem@remove_page:
    push rsi
    push rcx
    push rdx

    push rdi
    call mem@get_page_from_no
    call mem@munmap                 ; Remove the page
    pop rdi
                                    ; Update the parent page
    mov rsi, [rel mem@parent_page]  
    add rsi, 32                     ; Skip the map
    mov cl, byte [rsi]  
    dec cl
    mov byte [rsi], cl              ; Updating the page count
    inc rsi
    inc rcx
.loop:
    mov rdx, qword [rsi + rdi * 8 + 8]
    mov qword [rsi + rdi * 8], rdx  ; Shift the next addresses by one
    inc rdi
    cmp rdi, rcx
    jl .loop

    pop rsi
    pop rcx
    pop rdx
    ret


; This function will check if the given page is empty and delete it if it is.
; It will update the page count in the parent page and align all the addresses
; of the other pages
; TODO TEST THIS FUNCTION
; (rdi:page_no)
mem@remove_if_page_empty:
    push rax
    push rdi

    call mem@get_page_from_no
    xor rax, rax                    ; Sum of the content of the map of the page
    add rax, qword [rdi]            
    add rax, qword [rdi + 8]
    add rax, qword [rdi + 16]
    add rax, qword [rdi + 24]
    pop rdi

    cmp rax, 192                    ; If 192, this is the part used internaly so it's empty
    jne .end
    call mem@remove_page
.end:
    pop rax
    ret


; This function will allocate an amount of memory and map it on the heap. 4
; will be added to the given size (to store it size) and rounded up to the
; closest multiple of 16 (memory is allocated in block of 16). It will find
; enough free space (with mem@find_free_space) and return the corresponding
; address
; (rdi:size) -> (rdi:addr)
mem@alloc:
    push rax 
    add rdi, 4                      ; The size of the allocated memory is
                                    ; stored in the first for bytes of the buffer
    call mem@_upper_divisible_16    ; Find the closest upper dividor by 16
    mov rax, rdi
    call mem@find_free_space
    push rdi
    mov rdi, rdx
    mov rdx, rax
    call mem@_map                   ; rsi is already set by find_free_space
    pop rdi                         ; return the address of the allocated space
    mov [rdi], eax                  ; put the size of the allocated memory in the first 4 bytes
    pop rax
    ret

; This function will free the space found at the corresponding address. This is
; done only by saying that this memory can be reused again in the map of the
; memory at the begining of the page.
; (rdi:addr)
mem@dealloc:
    push rsi
    mov esi, dword [rdi]            ; Get the size of the buffer
    call mem@_unmap                 ; The only thing needed is to tell that the
                                    ; space can be reused which is done by unmap
    pop rsi
    ret


; This function will resize the allocated space. It will first check if their
; is enough space following the current allocated space, if not, it will
; reallocate a new space and move the data
; (rdi:addr, rsi:new_len)
mem@realloc:
    push rdx
    push rsi

    mov r8, rsi
    mov r9, rdi

    mov rdi, r8
    add rdi, 4
    call mem@_upper_divisible_16    ; Compute the new size
    mov r8, rdi
    mov rdi, r9

    mov ecx, dword [rdi]            ; Get the current size
    cmp r8, rcx
    jl .smaller
    je .end

    mov dword [rdi], r8d            ; Update the size
    
    add rdi, rcx
    sub r8, rcx                     ; Difference in size, (new_size - old_size)
    mov rsi, r8
    call mem@is_free_space_at       ; If there is enough space after
    cmp rdi, 0
    je .move

    mov rdi, r9
    add rdi, rcx
    call mem@get_page_from_addr
    mov rdx, r8
    call mem@_map                   ; Tell that more space is used on the map
    mov rdi, r9
    jmp .end
.smaller:
    mov rdi, r9
    sub rdx, rsi
    add rdi, rsi
    mov rsi, rdx
    call mem@_unmap                 ; Tell that some space was freeed on the map
    mov rdi, r9
    jmp .end
.move:
    add r8, rcx
    mov rdi, r8
    call mem@alloc                  ; Allocate a new object
    mov rsi, rdi
    mov rdi, r9
    call mem@move_buff              ; Move from one object to the other all the data
    call mem@dealloc                ; Dealloc the old object
    mov rdi, rsi
.end:
    pop rsi
    pop rdx
    ret

; This function will move the data of the first buffer to the second buffer
; (rdi:source_addr, rsi:dest_addr)
mem@move_buff:
    push rax
    push rbx
    push rdx
    mov edx, dword [rdi]            ; Size of the source buffer
    mov rax, 4                      ; Counter, first 4 is the length and is not transfered
.loop:
    mov rbx, qword [rdi + rax]      ; Move from the source...
    mov qword [rsi + rax], rbx      ; ...to the destination
    add rax, 8
    cmp rdx, rax
    jl .loop
    pop rdx
    pop rbx
    pop rax
    ret
; This function will return if their is enough space at the given address for
; the given size
; (rdi:addr, rsi:size) -> (rdi:bool)
mem@is_free_space_at:
    push rcx
    push rdx
    push rsi
    call mem@get_page_from_addr
    mov rcx, rdi
    pop rdi
    mov rdx, rsi
    shr rsi, 4                      ; Divide by 16
    push rdx
    mov rdx, 1                      ; When rdx = 1, _find_free_space will not
                                    ; create a new page
    call mem@_find_free_space       ; Try to find space without creating a new page
    mov rdi, 1
    cmp rdx, rcx
    pop rdx
    jne .no_space
    cmp rdx, rsi
    je .end
.no_space:                          ; Return if we have space (1) or not (0)
    xor rdi, rdi
.end:
    pop rdx
    pop rcx
    ret

; This function is a wrapper for _find_free_space without the offset
; (rdi:size, rsi:_, rdx:do_create_page) -> (rdi:addr, rsi:offset, rdx:page_no)
mem@find_free_space:                
    xor rsi, rsi
    call mem@_find_free_space
    ret

; This function will find an empty block of space on the heap and return the
; address to it. It will search the map of each page for a big enough empty
; space.
; TODO Rework this function, this looks ugly...
; (rdi:size, rsi:offset, rdx:do_create_page) -> (rdi:addr, rsi:offset, rdx:page_no)
mem@_find_free_space:
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14

    mov r14, rdx
    cmp rdi, 4064                   ; Max size to allocate (4064 bytes)
    jg .error
    shr rdi, 4                      ; Divide by 16
    push rdi                        ; This is used to reset the counter later
    and esi, 7
    mov r12, rsi                    ; Set the inner counter to the inner offset
    shr rsi, 3                      ; Set the outer counter to the outer offset
    mov r9, [rel mem@parent_page]   ; Current page (addr)
    xor r8, r8                      ; Current page (no)
    xor r10, r10
    xor r11, r11
.loop_byte:                         ; This will loop for the 4 available 
    cmp rsi, 32                     ; Number of bytes to check that map the free space in each pages
    je .next_page
    mov r10b, byte [r9 + rsi]
    mov r11b, 10000000b             ; Template to match where we want to find a free space
.loop_bit:
    push r11
    and r11b, r10b                  ; If the result is zero, the place we are checking is free
    cmp r11b, 0
    pop r11                         ; Return to the template
    je .free                     
    mov rdi, [rsp]                  ; If the place was not free, reset the counter
.continue_loop:
    inc r12
    shr r11b, 1
    cmp r12, 8                      ; If the template is checking the last bit in the byte
    jne .loop_bit
    inc rsi
    xor r12, r12
    jmp .loop_byte
.free:
    cmp rdi, [rsp]
    jne .continue_free
    mov rdx, rsi
    mov r13, r12
.continue_free:
    dec rdi
    cmp rdi, 0                      ; If we have found enough space, goto the end
    je .end
    jmp .continue_loop
.next_page:
    inc r8
    push rdi
    mov rdi, r8
    call mem@get_page_from_no       ; Get the address of the next page and stores it in r9
    cmp rdi, -1
    jne .continue_next_page         ; If the pages are all full, create a new one
    cmp r14, 1
    je .end_check                   ; If we don't create a new page (it's a check in the current page)
    push rsi
    call mem@new_page
    pop rsi
.continue_next_page:
    mov r9, rdi                     
    pop rdi
    xor rsi, rsi                    ; Reset the current page counter
    mov rdi, [rsp]                  ; Allocation can't be between different pages (FOR NOW ! TODO)
    xor r12, r12
    jmp .loop_byte
.end_check:
    pop rdi
.end:
    imul rdx, 128                   ; Compute the address of the free space found
    mov rsi, rdx                    ; This is useful to indicate that it's not free anymore
    imul r13, 16                    ; TODO: Should be shl
    add rsi, r13
    add rdx, r13
    add rdx, r9
    mov rdi, rdx
    mov rdx, r8                     

    pop r14
    pop r13
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    ret
.error:
    mov rdi, err_alloc_too_big  
    call panic          ; Throw the error and exit the program
    ret

; This function will return the number of pages already allocated. This is find
; in the parent page before all the addresses
; () -> (rdi:no)
mem@get_page_count:
    push rcx
    xor rdi, rdi
    mov rcx, qword [rel mem@parent_page]
    mov dil, byte [rcx + 32]        ; Get the page count from the parent page
    pop rcx
    ret

; This function will return the page specified by rdi, if the page does not
; exist, it is created.
; TODO create a page if not existant 
; (rdi:page_no) -> (rdi:addr)
mem@get_page_from_no:
    push rsi
    mov rsi, rdi
    call mem@get_page_count         ; The address is found in the data save in
                                    ; the parent page
    cmp rsi, rdi
    mov rdi, -1
    jge .end
    shl rsi, 3                      ; Multiplying by 8
    add rsi, [rel mem@parent_page]
    mov rdi, [rsi + 33]
.end:
    pop rsi
    ret

; This function will return the page where this memory address is located and
; the offset to the start of that page
; (rdi:addr) -> (rdi:page_no, rsi:offset)
mem@get_page_from_addr:
    push rax
    push rcx
    mov rcx, rdi
    call mem@get_page_count         ; Get the number of pages
    mov rax, rdi
.loop:
    cmp rax, 0                      ; Another page left to check ?
    je .end
    dec rax
    mov rdi, rax
    call mem@get_page_from_no       ; Get the address of the page
    push rcx
    sub rcx, rdi
    cmp rcx, 4096                   ; If the address is in the range of address
                                    ; contained in that page
    pop rcx
    jg .loop
    sub rcx, rdi
    mov rsi, rcx
    mov rdi, rax
.end:
    pop rcx
    pop rax
    ret

; This function will indicate that a location is taken in a page
; (rdi:page, rsi:offset, rdx:size)
mem@_map:
    push rdx
    call mem@get_page_from_no   ; Get the address of the page
    shr rsi, 4                  ; Divide by 16. Offset in bytes in the page to
                                ; the offset in bits in the map
    shr rdx, 4                  ; Divide by 16, each block of memory is map in 16 bytes at a time
    mov rcx, 1
    call mem@_put_bits
    pop rdx
    ret

; This function will indicate that a location is now free in a page
; (rdi:addr, rsi:size)
mem@_unmap:
    push rdx
    push rsi
    push rdi
    ;push rdi
    mov rdx, rsi
    call mem@get_page_from_addr
    push rdi
    call mem@get_page_from_no

    shr rsi, 4                  ; Divide by 16, Offset in bytes in the page to the offset in bits in the map
    shr rdx, 4                  ; Divide by 16, each block of memory is map in 16 bytes at a time
    xor rcx, rcx
    call mem@_put_bits
    pop rdi
    call mem@remove_if_page_empty ; Check if the page is empty, if so delete it
    pop rdi
    pop rsi
    pop rdx
    ret

; This function will print the map of the page (what is used and what is not
; used)
; (rdi:page_no)
mem@_print_page:
    push rdi
    push rax
    push rbx
    xor rax, rax
    mov rdi, 1
    call mem@get_page_from_no
    mov rbx, rdi
.loop:
    mov rdi, 10
    call print_char
    mov dil, byte [rbx + rax]
    call print_binary
    inc rax
    cmp rax, 32
    jne .loop
    pop rbx
    pop rax
    pop rdi
    ret


; (rdi:page_addr, rsi:offset_bits, rdx:count, cl:value)
mem@_put_bits:
    push rax
    push rcx
    push rsi
    push r8
    push r9
    push r10

    mov r8b, cl
    mov al, 10000000b   ; Mask
    mov rcx, rsi         
    and rcx, 7          ; offset to start writing in the row
    shr rsi, 3          ; current row (counter) (div by 8)
    shr al, cl
    xor r10, r10        ; counter
    mov r9b, byte [rdi + rsi] ; Get the value of the row
.loop:
    cmp r8b, 0          ; Put a 0 or a 1
    je .put_0
    or r9b, al          ; 100 | 010 = 110
    jmp .continue
.put_0:
    xor r9b, al
.continue:
    mov byte [rdi + rsi], r9b ; Get the next byte
    shr al, 1           ; Shift the mask by 1
    inc r10
    cmp r10, rdx        ; Compare with the counter
    je .end
    cmp al, 0           ; Compare if we are at the end of the byte
    jne .loop
    mov al, 10000000b
    inc rsi
    mov r9b, byte [rdi + rsi] ; Get the value of the row
    jmp .loop
.end: 
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rcx
    pop rax
    ret

; This function will return a number equal or bigger than the given one that is
; dividible by 16. upper_divisible = (rdi + 16) - (rdi % 16)
; (rdi:number) -> (rdi:number)
mem@_upper_divisible_16:
    mov rsi, rdi
    and rsi, 15         ; Modulo 16
    cmp rsi, 0          ; If we have already a divisible by 16 number
    je .end
    add rdi, 16
    sub rdi, rsi
.end:
    ret
