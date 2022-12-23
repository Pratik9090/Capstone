/*********** PRATIK PATEL ************/
    
## Link to your recording: https://photos.app.goo.gl/Qp2QqQe1ezBhm1cLA
    
## EECE.3170: Microprocessors I
## UMass Lowell
## Spring 2022 final exam programming problem
## You are open to having your design of the solution based on your interpretation
/*****
    MODIFICATIONS TO MAKE:
     You must change this program so that:
      - Initially, the LEDs blink simultaneously every 1.0 seconds.
      - Pressing switches will change the timer period by 0.5 seconds, either faster (by pressing S1) or slower (by pressing S2).
          - Given the timer configuration and 0.5 seconds of the adjustment period, the smallest period is 0.5 seconds whereas the maximum period is 2 seconds.
*****/
    
// Including xc.h allows use of SFR names, bit masks, etc.
#include <xc.h>

    // Interrupt vector setup
    .globl  __vector_dispatch_9    ## Port B change notification = vector #9
    .section .vector_9, code, keep
    .align 2
    .set nomips16
    .ent __vector_dispatch_9
__vector_dispatch_9:
    j  isrvector9	    ## Jump to actual ISR code, which is in text section
    nop
    .end __vector_dispatch_9
    .size __vector_dispatch_9, .-__vector_dispatch_9
    
    .globl  __vector_dispatch_11    ## Timer 1 interrupt = vector #11
    .section .vector_11, code, keep
    .align 2
    .set nomips16
    .ent __vector_dispatch_11
__vector_dispatch_11:
    j  isrvector11	    ## Jump to actual ISR code, which is in text section
    nop
    .end __vector_dispatch_11
    .size __vector_dispatch_11, .-__vector_dispatch_11
    
    // Start of text section       
    .text		## Text section contains code
    .set noreorder	## Disable instruction reordering
    .globl main		## Define main label as a global entity
    .ent main		##   and an entry point    

main:
    
    // Configure port A for output
    sw	    zero, TRISA		    ## TRISA = 0  --> all PORTA bits = output
    sw	    zero, ANSELA	    ## ANSELA = 0 --> all PORTA bits digital
    li	    t0, _PORTB_RB7_MASK
    ori	    t0, t0, _PORTB_RB13_MASK
    sw	    t0, TRISB		    ## TRISB = 0x00002080 --> pins 7 & 13 inputs
    sw	    zero, ANSELB	    ## ANSELB = 0 --> all PORTB bits digital  
    sw	    zero, TRISC		    ## TRISC = 0  --> all PORTC bits = output
    sw	    zero, ANSELC	    ## ANSELC = 0 --> all PORTC bits digital
    
    sw	    t0, LATASET		    ## LED1 ON
    sw	    t1, LATCSET		    ## LED2 ON
    
    li	   s1, 0		    ## Track MODE.
    
    // Configure Timer 1
    sw	    zero, T1CON		    ## Clear T1CON--disables timer to allow setup

    ori	    t1, zero, 0x7F21	    ## Set t1 = 0x8000 = initial PR1 value
    sw	    t1, PR1		    ##   (clock period--32545 cycles)
    
    li	    t2, _IFS0_T1IF_MASK	    ## t2 = bit mask for checking Timer 1 interrupt flag
    
    
    li	    t3, _T1CON_TCKPS_MASK  ## Prescale by factor of 256 (TCKPS = 11) BITMASK = 0x00000030
    sw	    t3, T1CONSET
    
    // Configure interrupts
    lui	    t3, 0x0001			## Want INTCON bit 16 (VS<0>) = 1
					##   so vectors 8 bytes apart
    ori	    t3, t3, _INTCON_MVEC_MASK   ## Enable multivectored interrupt mode
    sw	    t3, INTCON
    
    li	    t3, _IPC2_T1IP_MASK	    ## Set T1 interrupt priority level to 7
    sw	    t3, IPC2		    ## Implicitly sets subpriority level to 0
    
    li	    t3, _IPC2_CNBIP_MASK
    sw	    t3, IPC2SET
    
    li	    t2, _IFS0_T1IF_MASK	    ## t2 = bit mask for checking Timer 1 interrupt flag
    sw	    t2, IEC0		    ## Enable Timer 1 interrupts (uses
				    ##   same bit mask as T1 interrupt flag)
    li	    t2, _IEC0_CNBIE_MASK
    sw	    t2, IEC0SET
    
    add	    t3, t4, zero	    ## Set bits in CNEN1B = 1 and CNEN0B = 0
    or	    t3, t3, t6		    ##   corresponding to switch positions
    sw	    t3, CNEN1B		    ##   (t4 = S1 bit mask; t6 = S2 bit mask)
    sw	    zero, CNEN0B	    ## Will detect falling edges on these pins
    
    li	    t3, _CNCONB_ON_MASK		    ## Enables Port B change notification
    ori	    t3, t3, _CNCONB_CNSTYLE_MASK    ## Enables edge detection
    sw	    t3, CNCONB
    				    
    ei				    ## Enable interrupts globally
				    
    li	    t3, _T1CON_TON_MASK	    ## Enable Timer 1 by setting "ON" bit in T1CON
    sw	    t3, T1CONSET
      
    // Main loop: doing nothing, just waiting for an interrupt
mainloop:
    j	mainloop
    nop
    .end main
    
    //////////////////////////////////////////////////////////////////////////
    // Delay loop for switch debouncing
    .global delay
    .ent delay
    
delay:
    li	    t7, 0x61A8		    ## Set delay counter to 0x61A8 = 25,000
				    ## Since loop body has 3 instructions,
				    ##   loop takes 25,000 * 3 = 75,000
				    ##   cycles
				    ## Remaining 3 instructions take 3 cycles
				    ##  ~75,000 cycles / 8 MHz clock ~ 0.009375 sec delay
loop:
    addi    t7, t7, -1		    ## Decrement counter
    bne	    t7, zero, loop	    ##  and continue doing that until we hit 0
    nop				    
    jr	    ra
    nop

    .end delay
    
    //////////////////////////////////////////////////////////////////////////
    // Handle Port B change interrupt--check switches and toggle appropriate LEDs
    .global isrvector9
    .ent isrvector9
    
  
isrvector9:   
    li	    t4, _PORTB_RB7_MASK	    ## t4 = 0x00000080 --> mask for S1
    li	    t6, _PORTB_RB13_MASK    ## t6 = 0x00002000 --> mask for S2
    
    // Check S1
    lw	    t8, CNFB
    and	    t9, t8, t4
    beq	    t9, zero, checkS2	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t4, CNFBCLR		    ## Clear flag for S1
    jal	    delay		    ## Delay to debounce
    nop
    lw	    t2, PORTB		    
    and	    t2, t2, t4		    ## Is button still pressed?
    bne	    t2, zero, checkS2	    ## If not, leave LED alone and check S2
    nop
    

    sub	    s1, s1, 1		    ## Decrement the current state of LED blinking, from 2sec to 1.5 sec and so on
    beq	    s1, -1, checkS2   ## goes to checks2 when compiler reaches to 1 sec 
    nop
   	    
       
    // Check S2
checkS2:
    and	    t9, t8, t6
    beq	    t9, zero, int9done	    ## If bit 13 = 0, S2 wasn't pressed
    nop
    
    // S2 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t6, CNFBCLR		    ## Clear flag for S2
    jal	    delay		    ## Delay to debounce
    nop
    lw	    t2, PORTB		    
    and	    t2, t2, t6		    ## Is button still pressed?
    bne	    t2, zero, int9done	    ## If not, leave LED alone and check S2
    nop

   
    addi    s1, s1, 1		    ## Increments the mode going to change the mode from 1 sec to 1.5 sec 
    beq	    s1, 3, int9done	    ## mode 3 is the last mode (2sec) when the compiler it goes directly to int9done
    nop
    sub	    s1, s1, 1	

int9done:
    li	    t3, _IFS0_CNBIF_MASK    ## Clear Port B change notification flag
    sw	    t3, IFS0CLR		    ##    in IFS0
    eret		    ## Return from interrupt
    .end isrvector9
    
    //////////////////////////////////////////////////////////////////////////
    // Handle Timer1 interrupt--clear interrupt flag and toggle LED
    .global isrvector11
    .ent isrvector11
isrvector11:
    li	    t2, _IFS0_T1IF_MASK    
    sw	    t2, IFS0CLR		    ## Clear T1IF in software!
    
    li	    t0, _PORTA_RA0_MASK
    li	    t1, _PORTC_RC9_MASK
    
    /*** MODIFY THE LED BEHAVIOR TO IMPLEMENT THE LED STATES DESCRIBED ABOVE ***/
    
    // Flip LEDs
    sw	    t0, LATAINV		    ## Flip LED1
    sw	    t1, LATCINV		    ## Flip LED2
    
    beq	    s1, 0, part1
    nop
    beq	    s1, 1, part2
    nop
    beq	    s1, 2, part3
    nop
    
        
 part1:
    ori	    t1, zero, 0x7F21	    ## initial PR1 value 
    sw	    t1, PR1		    
    
    li	    t2, _IFS0_T1IF_MASK	    
    li	    t3, _T1CON_TCKPS_MASK  
    sw	    t3, T1CONSET
    eret
     
part2:
    ori	    t1, zero, 0xBA00	    
    sw	    t1, PR1		    ##   clock period -- 47616
    
    li	    t2, _IFS0_T1IF_MASK	   
    li	    t3, _T1CON_TCKPS_MASK  
    sw	    t3, T1CONSET
    eret

part3:
    ori	    t1, zero, 0xFFFF	    
    sw	    t1, PR1		   ## Set t1 = 0xFFFF = initial PR1 value
				    ##   (maximum possible clock period--65,535 cycles)
    li	    t2, _IFS0_T1IF_MASK	   
    li	    t3, _T1CON_TCKPS_MASK  
    sw	    t3, T1CONSET
    eret

int11done:
    eret		    ## Return from interrupt
    .end isrvector11
