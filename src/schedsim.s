.section .bss
input_buf:      .space 256
output_buf:     .space 1024
temp_buf:       .space 256
proc_buf:       .space 160
process_count:  .space 4
current_time:   .space 4
quantum:        .space 4
out_len:        .space 4 
algo_type:      .space 1

# Round Robin helpers (optional)
rr_queue:       .space 64
rr_head:        .space 4
rr_tail:        .space 4

.section .data
newline:        .asciz "\n"
str_fcfs:       .asciz "FCFS "
str_sjf:        .asciz "SJF "
str_srtf:       .asciz "SRTF "
str_pf:         .asciz "PF "
str_rr:         .asciz "RR "

.section .text
.global _start

_start:
    # READ INPUT
    mov     $0, %rax
    mov     $0, %rdi
    lea     input_buf(%rip), %rsi
    mov     $256, %rdx
    syscall

    mov %rax, %rcx
    lea input_buf(%rip), %rdi
    add %rcx, %rdi
    movb $0, (%rdi)

    # FCFS CHECK
    leaq input_buf(%rip), %rsi
    leaq str_fcfs(%rip), %rdi
    call check_string_match
    cmp $1, %rax
    je is_fcfs

    # SJF CHECK
    leaq input_buf(%rip), %rsi
    leaq str_sjf(%rip), %rdi
    call check_string_match
    cmp $1, %rax
    je is_sjf

    # SRTF CHECK
    leaq input_buf(%rip), %rsi
    leaq str_srtf(%rip), %rdi
    call check_string_match
    cmp $1, %rax
    je is_srtf

    # PF CHECK
    leaq input_buf(%rip), %rsi
    leaq str_pf(%rip), %rdi
    call check_string_match
    cmp $1, %rax
    je is_pf

    # RR CHECK
    leaq input_buf(%rip), %rsi
    leaq str_rr(%rip), %rdi
    call check_string_match
    cmp $1, %rax
    je is_rr

    jmp .exit

# ==========================================
# ISMATCHED JUMPS
# ==========================================

is_fcfs:
    movb $0, algo_type(%rip)
    jmp parse_processes

is_sjf:
    movb $1, algo_type(%rip)
    jmp parse_processes

is_srtf:
    movb $2, algo_type(%rip)
    jmp parse_processes

is_pf:
    movb $3, algo_type(%rip)
    jmp parse_processes

is_rr:
    movb $4, algo_type(%rip)
    jmp parse_processes

# ==========================================
# DATA PARSING LOOPS
# ==========================================

parse_processes:
    leaq proc_buf(%rip), %rdi
    movl $0, process_count(%rip)

.process_loop:
    movb (%rsi), %al
    cmpb $0, %al
    je start_simulation
    cmpb $10, %al
    je start_simulation
    cmpb $' ', %al
    je .skip_space

    cmpb $'A', %al
    jl parse_quantum_rr

    # PROCESS ID READ
    movb %al, (%rdi)
    incq %rsi

    incq %rsi

    # BURST TIME PARSE
    xor %rax, %rax

parse_burst:
    movb (%rsi), %bl
    cmpb $'0', %bl
    jl burst_done
    cmpb $'9', %bl
    jg burst_done

    subb $'0', %bl
    imul $10, %rax
    add %rbx, %rax

    incq %rsi
    jmp parse_burst

burst_done:
    movb %al, 1(%rdi)
    movb %al, 4(%rdi)
    
    movb (%rsi), %bl
    cmpb $'-', %bl
    jne .save_process

    incq %rsi

    # ARRIVAL TIME PARSE
    xor %rax, %rax

parse_arrival:
    movb (%rsi), %bl
    cmpb $'0', %bl
    jl arrival_done
    cmpb $'9', %bl
    jg arrival_done

    subb $'0', %bl
    imul $10, %rax
    add %rbx, %rax

    incq %rsi
    jmp parse_arrival

arrival_done:
    movb %al, 2(%rdi)
    
    # PF CHECK
    movb (%rsi), %al
    cmpb $'-', %al
    jne .save_process

    # IF HAS DASH
    incq %rsi
    movb (%rsi), %al
    subb $48, %al
    movb %al, 3(%rdi)
    incq %rsi

.save_process:
    addq $5, %rdi
    
    movl process_count(%rip), %eax
    addl $1, %eax
    movl %eax, process_count(%rip)

.skip_space:
    incq %rsi
    jmp .process_loop

parse_quantum_rr:
    xor %rax, %rax
.parse_q_loop:
    movb (%rsi), %bl
    cmpb $'0', %bl
    jl q_done
    cmpb $'9', %bl
    jg q_done

    subb $'0', %bl
    imul $10, %rax
    add %rbx, %rax

    incq %rsi
    jmp .parse_q_loop
q_done:
    movl %eax, quantum(%rip)
    jmp start_simulation

# ==========================================
# SIMULATION ENGINE
# ==========================================

start_simulation:
    movl $0, out_len(%rip)
    movl $0, current_time(%rip)

    movb algo_type(%rip), %al
    cmpb $4, %al
    jne .clock_tick             # if its not rr return to standart loop

    # add all process to queue
    movl $0, %eax              
    movl process_count(%rip), %ecx
    lea rr_queue(%rip), %rdx
    movl $0, rr_head(%rip)      # Head = 0
    movl $0, rr_tail(%rip)      # Tail = 0

.rr_init_loop:
    cmpl %eax, %ecx
    je .clock_tick
    
    movb %al, (%rdx, %rax)      # save index
    incl %eax
    movl %eax, rr_tail(%rip)    # update tail
    jmp .rr_init_loop

.clock_tick:
    movl out_len(%rip), %eax
    
    cmpl $1000, %eax
    jge print_results_and_exit

    call check_all_done
    cmp $1, %rax
    je print_results_and_exit


# ==========================================
# ALGORITHMS
# ==========================================

    movb algo_type(%rip), %al
    cmpb $0, %al
    je run_fcfs
    cmpb $1, %al
    je run_sjf
    cmpb $2, %al  
    je run_srtf
    cmpb $3, %al
    je run_pf
    cmpb $4, %al
    je run_rr
    jmp .tick_end

# ------------------------------------------
# FCFS (First Come First Serve)
# ------------------------------------------
run_fcfs:
    leaq proc_buf(%rip), %rdi
    movl process_count(%rip), %ecx
    movl current_time(%rip), %edx

    movb $'X', %r8b     
    movq $0, %r9        
    movl $9999, %r10d

.fcfs_find:
    cmpl $0, %ecx
    je .execute_process

    movb 4(%rdi), %bl   
    cmpb $0, %bl
    jle .fcfs_next

    movzbl 2(%rdi), %ebx
    cmpl %edx, %ebx         
    jg .fcfs_next

    # Non-Preemptive
    movb 1(%rdi), %bh
    movb 4(%rdi), %bl
    cmpb %bh, %bl       
    jne .fcfs_force_pick    

    # Finding smallest Arrival Time
    movzbl 2(%rdi), %ebx
    cmpl %r10d, %ebx
    jge .fcfs_next

    movl %ebx, %r10d        
    movb (%rdi), %r8b   
    movq %rdi, %r9      

.fcfs_next:
    addq $5, %rdi
    decl %ecx
    jmp .fcfs_find

.fcfs_force_pick:
    movb (%rdi), %r8b
    movq %rdi, %r9
    jmp .execute_process

# ------------------------------------------
# SJF (Shortest Job First)
# ------------------------------------------
run_sjf:
    leaq proc_buf(%rip), %rdi
    movl process_count(%rip), %ecx

    movb $'X', %r8b
    movq $0, %r9
    movl $9999, %r10d

.sjf_find:
    cmpl $0, %ecx
    je .execute_process

    movb 4(%rdi), %bl
    cmpb $0, %bl
    jle .sjf_next           

    # Non-Preemptive
    movb 1(%rdi), %bh
    movb 4(%rdi), %bl
    cmpb %bh, %bl
    jne .sjf_force_pick     

    # Finding smallest Burst Time
    movzbl 1(%rdi), %ebx    
    cmpl %r10d, %ebx
    jge .sjf_next

    movl %ebx, %r10d        
    movb (%rdi), %r8b
    movq %rdi, %r9

.sjf_next:
    addq $5, %rdi
    decl %ecx
    jmp .sjf_find

.sjf_force_pick:
    movb (%rdi), %r8b
    movq %rdi, %r9
    jmp .execute_process
# ------------------------------------------
# SRTF (Shortest Remaining Time First)
# ------------------------------------------
run_srtf:
    leaq proc_buf(%rip), %rdi       
    movl process_count(%rip), %ecx  
    movl current_time(%rip), %edx   

    movb $'X', %r8b                 
    movq $0, %r9                    
    movl $9999, %r10d               
    # iseverything done?
.srtf_loop:
    cmpl $0, %ecx                   
    je .execute_process             

    # checks arrival time
    movzbl 2(%rdi), %ebx            
    cmpl %edx, %ebx
    jg .srtf_next                   

    # remaining burst > 0 ?
    movb 4(%rdi), %bl              
    cmpb $0, %bl
    jle .srtf_next                 

    # checks shortest time
    movzbl 4(%rdi), %ebx           
    cmpl %r10d, %ebx                
    jge .srtf_next                  

    # new min
    movl %ebx, %r10d               
    movb (%rdi), %r8b              
    movq %rdi, %r9                  

.srtf_next:
    addq $5, %rdi                   
    decl %ecx
    jmp .srtf_loop
# ------------------------------------------
# PF (Priority First)
# ------------------------------------------
run_pf:
    leaq proc_buf(%rip), %rdi       
    movl process_count(%rip), %ecx  
    movl current_time(%rip), %edx   

    movb $'X', %r8b                 
    movq $0, %r9                    
    movl $9999, %r10d               
    movl $9999, %r11d               

.pf_loop:
    cmpl $0, %ecx
    je .execute_process

    # Arrival time <= current time ?
    movzbl 2(%rdi), %ebx            
    cmpl %edx, %ebx
    jg .pf_next

    # remaining burst >  0 ?
    movb 4(%rdi), %bl               
    cmpb $0, %bl
    jle .pf_next

    # prioriaty check
    movzbl 3(%rdi), %ebx            
    cmpl %r10d, %ebx
    jl .pf_new_best                 
    jg .pf_next                     

    # ifprioraties == , check time
    movzbl 4(%rdi), %ebx            
    cmpl %r11d, %ebx
    jl .pf_new_best                 
    jmp .pf_next                     

.pf_new_best:
    movzbl 3(%rdi), %r10d           
    movzbl 4(%rdi), %r11d           
    movb (%rdi), %r8b               
    movq %rdi, %r9                  

.pf_next:
    addq $5, %rdi
    decl %ecx
    jmp .pf_loop

# ------------------------------------------
# RR (Round Robin)
# ------------------------------------------
run_rr:
    # 
    movl rr_head(%rip), %eax
    movl rr_tail(%rip), %ebx
    cmpl %eax, %ebx
    je .rr_idle                 

    # get process
    lea rr_queue(%rip), %rsi
    movzbl (%rsi, %rax), %r10d  
    incl %eax
    andl $63, %eax              
    movl %eax, rr_head(%rip)

    # find process address
    imul $5, %r10d, %eax
    lea proc_buf(%rip), %r9
    addq %rax, %r9
    
    movb (%r9), %r8b            # r8b = process id
    movzbl quantum(%rip), %r11d # r11d = remaining quantum

.rr_quantum_loop:
    movl out_len(%rip), %eax
    lea output_buf(%rip), %rdi
    movb %r8b, (%rdi, %rax)
    incl out_len(%rip)

    # decrease remaining time
    decb 4(%r9)
    decl %r11d                  
    incl current_time(%rip)

    # is process finished
    cmpb $0, 4(%r9)
    je .rr_pad_x

    # is quantum finished
    cmpl $0, %r11d
    je .rr_reenqueue
    jmp .rr_quantum_loop

.rr_pad_x:
    # if process early done, get x
    cmpl $0, %r11d
    je .clock_tick              
.rr_x_loop:
    movl out_len(%rip), %eax
    lea output_buf(%rip), %rdi
    movb $'X', (%rdi, %rax)
    incl out_len(%rip)
    incl current_time(%rip)
    decl %r11d
    jnz .rr_x_loop
    jmp .clock_tick

.rr_reenqueue:
    # if process is not finished, add to queue
    movl rr_tail(%rip), %ebx
    lea rr_queue(%rip), %rsi
    movb %r10b, (%rsi, %rbx)
    incl %ebx
    andl $63, %ebx
    movl %ebx, rr_tail(%rip)
    jmp .clock_tick

.rr_idle:
    # if queue is empty
    movb $'X', %r8b
    jmp .execute_process        


# ------------------------------------------
# EXECUTION PROCESS
# ------------------------------------------
.execute_process:
    movl out_len(%rip), %eax
    lea output_buf(%rip), %rdi
    movb %r8b, (%rdi,%rax,1)

    cmpq $0, %r9
    je .tick_end
    
    movb 4(%r9), %bl
    decb %bl
    movb %bl, 4(%r9)

.tick_end:
    incl out_len(%rip)
    
    movl current_time(%rip), %eax
    addl $1, %eax
    movl %eax, current_time(%rip)
    
    jmp .clock_tick

print_results_and_exit:
    call write_output
    jmp .exit
    
# ==========================================
# EXIT SYSCALL
# ==========================================

.exit:
    mov     $60, %rax
    xor     %rdi, %rdi
    syscall

# ==========================================
# FUNCTIONS
# ==========================================

check_all_done:
    leaq proc_buf(%rip), %rdi
    movl process_count(%rip), %ecx
    mov $1, %rax

    cmpl $0, %ecx
    je .done_check_end

.done_loop:
    movb 4(%rdi), %bl
    cmpb $0, %bl
    jg .not_all_done

    addq $5, %rdi
    decl %ecx
    cmpl $0, %ecx
    jg .done_loop

.done_check_end:
    ret

.not_all_done:
    mov $0, %rax
    ret

# ==========================================
# CHECK STRING MATCH FUNCTION
# ==========================================

check_string_match:
.match_loop:
    movb (%rdi), %bl
    testb %bl, %bl
    je .matched_success
    movb (%rsi), %al
    cmpb %al, %bl
    jne .matched_fail
    incq %rsi
    incq %rdi
    jmp .match_loop

.matched_success:
    mov $1, %rax
    ret

.matched_fail:
    mov $0, %rax
    ret

# ==========================================
# OUTPUT FUNCTION
# ==========================================

write_output:
    mov     $1, %rax
    mov     $1, %rdi
    lea     output_buf(%rip), %rsi
    movl    out_len(%rip), %edx
    syscall
 
do_exit:
    mov     $60, %rax
    xor     %rdi, %rdi
    syscall