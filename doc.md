# DOC
# mem@init () -> ()
# mem@mmap () -> (rdi:addr)
# mem@new_page () -> (rdi:addr, rsi:page_no)

# mem@find_free_space (rdi:size) -> (rdi:addr, rsi:offset, rdx:page_no)
# mem@is_free_space_at (rdi:addr, rsi:size) -> (rdi:bool)

# mem@get_page_from_no (rdi:page_no) -> (rdi:addr)
# mem@get_page_from_addr (rdi:addr) -> (rdi:page_no, rsi:offset)
# mem@_get_page_count () -> (rdi:count)
# mem@_print_page (rdi:no) -> ()

# mem@_map (rdi:page, rsi:offset, rdx:size) -> ()
# mem@_unmap (rdi:addr, rsi:size) -> ()
# mem@_put (rdi:addr, esi:count, rdx:value) -> ()
# mem@_put_bits (rdi:addr, rsi:offset_bits, rdx:count, cl:value) -> ()
# mem@_upper_divisible_16 (rdi:number) -> (rdi:number)

# mem@alloc (rdi:size) -> (rdi:addr)
# mem@dealloc (rdi:addr) -> ()
# mem@realloc (rdi:addr, rsi:size) -> (rdi:addr) (the address may be new)

