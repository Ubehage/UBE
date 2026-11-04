.data
.globl relocation_values
relocation_values:
.rept 65536
.quad external_value
.endr
