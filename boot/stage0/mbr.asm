[BITS 16]           ; Tell the assembler we are in 16-bit Real Mode
[ORG 0x7C00]        ; Tell the assembler that this code will be loaded at 0x7C00 by the BIOS

start:
    ; 1. Standardize our environment
    ; The BIOS doesn't guarantee the state of segment registers, so we must set them.
    cli             ; Clear interrupts (disable them while we mess with stack/segments)
    xor ax, ax      ; AX = 0
    mov ds, ax      ; Data Segment = 0
    mov es, ax      ; Extra Segment = 0
    
    ; Set up a safe stack
    mov ss, ax      ; Stack Segment = 0
    mov sp, 0x7C00  ; Stack Pointer starts at 0x7C00 and grows downwards (safe area)
    sti             ; Re-enable interrupts

    ; 2. Save the boot drive number
    ; The BIOS passes the ID of the drive we booted from in the DL register.
    mov [BOOT_DRIVE], dl

    ; 3. Print a welcome message
    mov si, msg_loading
    call print_string

    ; 4. Load Stage 1 from disk into memory
    ; We will load the next sector (Sector 2) into memory at 0x7E00 (right after our MBR)
    mov ah, 0x02    ; BIOS Int 13h, AH=02h: Read Sectors
    mov al, 1       ; How many sectors to read (1 for now, Stage 1)
    mov ch, 0       ; Cylinder 0
    mov dh, 0       ; Head 0
    mov cl, 2       ; Sector 2 (Sector 1 is our MBR, so we read the next one)
    mov bx, 0x7E00  ; Destination address: [ES:BX] -> 0x0000:0x7E00
    mov dl, [BOOT_DRIVE] ; Drive number
    
    int 0x13        ; Call BIOS disk interrupt
    jc disk_error   ; If the Carry Flag (CF) is set, an error occurred. Jump to error handler.

    ; 5. Jump to Stage 1!
    ; We've successfully loaded the next part of the bootloader. Hand over control.
    jmp 0x0000:0x7E00

; ------------------------------------------------------------------
; Helper Functions
; ------------------------------------------------------------------

print_string:
    mov ah, 0x0E    ; BIOS Int 10h, AH=0Eh: Teletype output
.loop:
    lodsb           ; Load byte at [DS:SI] into AL, increment SI
    test al, al     ; Check if AL is 0 (end of string)
    jz .done        ; If zero, we are done
    int 0x10        ; Print the character in AL
    jmp .loop
.done:
    ret

disk_error:
    mov si, msg_error
    call print_string
    jmp halt

halt:
    cli             ; Disable interrupts
    hlt             ; Halt the CPU
    jmp halt        ; Infinite loop if an interrupt wakes us up

; ------------------------------------------------------------------
; Data Section
; ------------------------------------------------------------------

BOOT_DRIVE  db 0
msg_loading db "GodMode OS: Stage 0 initialized...", 0x0D, 0x0A, 0
msg_error   db "GodMode OS: Disk read error!", 0x0D, 0x0A, 0

; ------------------------------------------------------------------
; MBR Magic Signature
; ------------------------------------------------------------------
; The BIOS requires the 511th and 512th bytes to be 0x55 and 0xAA.
times 510 - ($ - $$) db 0   ; Pad the rest of the 512 bytes with zeroes
dw 0xAA55                   ; 16-bit Boot Signature (Little Endian: 0x55, 0xAA)
