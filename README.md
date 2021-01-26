## dalloc.asm 
This is only a toy project. The goal was to learn assembler and how malloc worked internaly.
This is a dynamic memory allocation library (like malloc) written in assembler for granular memory allocation. The implementation has some limitations, the maximum allocation for an object is 4060 bytes and the maximum amount of memory allocated for all the objects is around 1 megabyte. It is also only supported on macOS.

The memory used is tracked in block of 16 bytes, therefore memory is allocated in block of 16 bytes and no less.

All the dynamic memory allocation things are located inside `mem.asm`, all the functions for io (print and read from terminal) inside of `io.asm`.

### Build the project
```sh
nasm -f macho64 main.asm
ld -macosx_version_min 10.8 -lSystem -o main main.o 
```

### Usage
**The prefix for all functions is `mem@`**

### `mem@init`
This function will initialize the library. Must be called before any other functions

```nasm
call mem@init
```

### `mem@uninit`
This function will free all the memory allocated previously by the library

```nasm
call mem@uninit
```

### `mem@alloc`
This function will find a free space and return the address to that space. The first 4 bytes of the returned address contains the actual size of the allocated size. If there is not enough space in the current page, a new page will be created. 

**Parameter**

`rdi`: The size of the object. 4 bytes will be added to the given size and it will be rounded up to the nearest divisible number by 16. Eg. : 20 + 4 = 24 => 32 bytes. The 4 bytes added are used to indicate the size of the object and are located in the first 4 bytes of the allocation. It is important to not overwrite this number.

**Returned value**

`rdi`: The address to the object

```nasm
mov rdi, 20             ; Size of the object to be returned
call mem@alloc
mov esi, dword [rdi]    ; Actual size of the object
```

### `mem@dealloc`
This function will free the space used by the object. If it was the last object in a page, the page is removed.

**Parameter**

`rdi`: The address of the object

```nasm
mov rdi, [rel address_to_object]
call mem@dealloc
```

### `mem@realloc`
This function will allocate more space for the given object. If there is not enough space after the current object for the growth, the object is moved where enough space is free.

**Parameter**

`rdi`: The address of the object
`rsi`: The new size wanted for the given object (the size may change, see `mem@alloc`)

**Returned value**

`rdi`: The address of the object. The address may have changed in some cases.

```nasm
mov rdi, [rel address_to_object]
mov rsi, 40             ; Wanted size of the object
call mem@realloc
mov esi, dword [rdi]    ; The new actual size
```
