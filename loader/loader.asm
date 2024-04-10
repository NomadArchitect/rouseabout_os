bits 16
%include "kernel/x86inc.asm"
org 0x7c00

start:
    mov [read_sector.dl + 1], dl ; boot device

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov si, zsetup
    call printz

    mov dword [dap.lba], 1
    mov word [dap.dest], 0x7e00
    mov word [dap.blocks], SETUP_SECTORS
    call read_sector

    mov si, zkernel
    call printz

    mov ecx, KERNEL_SECTORS
    mov ebx, 0x100000
    call read_sectors_high

    mov si, zinitrd
    call printz

    mov ecx, INITRD_SECTORS
    mov ebx, 0x200000
    call read_sectors_high

    mov si, znewline
    call printz

    mov ebx, 0x200000
    mov [0x7c00 + 0x218], ebx
    mov ebx, INITRD_SECTORS * 512
    mov [0x7c00 + 0x21c], ebx

    mov ax, 0x7c0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0xfffc
    jmp 0x7e0:0 ; -> linear 0x7e00


read_sectors_high:
    mov word [dap.dest], 0x9000 ; staging
    mov word [dap.blocks], 1

.loop:
    push ebx ; not all bios preserve ebx across int 0x10
    call read_sector
    pop ebx

    ; memcpy
    push ecx
    cli
    lgdt [gdt_ptr]

    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp short $+2

    mov ax, 0x8
    mov ds, ax
    mov es, ax

    mov esi, 0x9000
    mov edi, ebx
    mov ecx, 512

    rep o32 a32 movsb

    mov eax, cr0
    and al, 0xFE
    mov cr0, eax
    jmp short $+2

    sti
    pop ecx
    mov ax, 0
    mov ds, ax
    mov es, ax
    ; memcpy done

    add ebx, 512
    dec ecx
    jnz .loop

    ret


read_sector:
    mov si, dap
    mov ah, 0x42
.dl:
    mov dl, 0x80
    int 0x13
    jc .error
    movzx eax, word [dap.blocks]
    add dword [dap.lba], eax
    ret

.error:
    mov si, zerror
    call printz
    jmp short $


printz:
.loop:
    lodsb
    test al, al
    jz .ret
    mov ah, 0xe
    int 0x10
    jmp short .loop
.ret:
    ret

zsetup: db "setup...", 0, 0
zkernel: db 0xd, 0xa, "kernel...", 0, 0
zinitrd: db 0xd, 0xa, "initrd...", 0, 0
znewline: db 0xd, 0xa, 0
zerror: db " error", 0xd, 0xa, 0

align 4
dap:
    db 0x10
    db 0
.blocks:
    dw 1
.dest:
    dw 0x7d00
    dw 0
.lba:
    dd 0
    dd 0

align 4
gdt:
align 4
gdt:
    GDT_ENTRY32 0, 0, 0, 0
    GDT_ENTRY32 0, 0xFFFFFFFF, 0x92, GRAN_32_BIT_MODE | GRAN_4KIB_BLOCKS
.end:

gdt_ptr:
    dw gdt.end - gdt - 1
    dd gdt

times 510 - ($ - $$) db 0
db 0x55, 0xAA
