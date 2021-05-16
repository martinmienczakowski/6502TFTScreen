;Program to interface with 2.8" Elegoo Screen
;base setup is ben eater 6502 computer with 6522 VIA D0-D7 on port B, RD,WR,RS,CS,REST on port A7-A5
;definetly imperfect code but a proof of concept!
;scrolls screen with all colours

;set constants which will be used in code
PORTB = $6000   ;Address of port B
PORTA = $6001   ;Address of port A
DDRB  = $6002   ;Data direction register - port B
DDRA  = $6003   ;Data direction register - port A

BLACK   =     $0000   ;Common screen colours - note stored little endian first as otherwise they get flipped when outputting!
BLUE    =     $1F00   ;
RED     =     $00f8
GREEN   =     $e007
CYAN    =     $ff07
MAGNETA =     $1ff8
YELLOW  =     $e0ff
WHITE   =     $ffff

TFT_HEIGHT = $f0          ;height of screen
TFT_WIDTH_DIV = $aa       ;width of screen divided by 2 - to work in 8-bit easily

TFT_H_COUNTER = $1000     ;location of TFT height counter for drawing
TFT_W_COUNTER = $1002     ;location of TFT width counter for drawing
TFT_PIXEL_COLOUR = $1004  ;location of offset of current pixel colour (an increment from black)

TFT_RD = %01111111  ;Control pins for TFT - normally high triggered low for command
TFT_WR = %10111111
TFT_RS = %11011111
TFT_CS = %11101111
TFT_REST = %11110111

  .org $8000

reset:

  lda #%11111111    ;set all lines on port B for output - TFT data bus
  sta DDRB
  lda #%11111000    ;Set D0-D4 on port A for output - TFT control
  sta DDRA
  lda #%11111000    ;set all control pins to high to start
  sta PORTA

  jsr TFT_Init          ;Initialise Screen
  lda #0
  sta TFT_PIXEL_COLOUR  ;set pixel color to black
  jsr TFT_Clear         ;Set screen to black

  jmp loop

loop:
  lda #2
  sta TFT_PIXEL_COLOUR
  jsr TFT_Clear
  lda #4
  sta TFT_PIXEL_COLOUR
  jsr TFT_Clear
  lda #6
  sta TFT_PIXEL_COLOUR
  jsr TFT_Clear
  lda #8
  sta TFT_PIXEL_COLOUR
  jsr TFT_Clear
  lda #10
  sta TFT_PIXEL_COLOUR
  jsr TFT_Clear
  lda #12
  sta TFT_PIXEL_COLOUR
  jsr TFT_Clear
  lda #14
  sta TFT_PIXEL_COLOUR
  jsr TFT_Clear
;scroll_colours:
  ;sta TFT_PIXEL_COLOUR
  ;jsr TFT_Clear
  ;dec TFT_PIXEL_COLOUR
  ;dec TFT_PIXEL_COLOUR
  ;bne scroll_colours
  jmp loop

TFT_Init:

  ;much of this function is opaque to me - copied from example from Elegoo (example 1)
  ;I have used the datasheet to look up what each block does and written defaults in comments if defaults aren't used
  lda TFT_CS
  sta PORTA

  lda #$cb                ;Power control A
  jsr TFT_Write_Com       ;Power on sequence same can be used for software reset
  lda #$39
  jsr TFT_Write_Data
  lda #$2C
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$34
  jsr TFT_Write_Data
  lda #$02
  jsr TFT_Write_Data

  lda #$cf                ;Power control B
  jsr TFT_Write_Com
  lda #$00
  jsr TFT_Write_Data
  lda #$c1                ;says $81 in manual...
  jsr TFT_Write_Data
  lda #$30
  jsr TFT_Write_Data

  lda #$e8                ;Driver timer control A
  jsr TFT_Write_Com
  lda #$85                ;84,11,AA in datasheet
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$78
  jsr TFT_Write_Data

  lda #$ea                ;Driver timer control B
  jsr TFT_Write_Com
  lda #$00                ;66,00 in datasheet
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data

  lda #$ed                ;Power on seqeunce control
  jsr TFT_Write_Com
  lda #$64                ;55,01,23,1 in datasheet
  jsr TFT_Write_Data
  lda #$03
  jsr TFT_Write_Data
  lda #$12
  jsr TFT_Write_Data
  lda #$81
  jsr TFT_Write_Data

  lda #$f7              ;Pump ratio control
  jsr TFT_Write_Com
  lda #$20              ;10 in datasheet
  jsr TFT_Write_Data

  lda #$c0              ;power control VRH[5:0]
  jsr TFT_Write_Com
  lda #$23              ;21 in datasheet
  jsr TFT_Write_Data

  lda #$c1              ;power control SAP[2:0];BT[3:0]
  jsr TFT_Write_Com
  lda #$10              ;as datasheet 
  jsr TFT_Write_Data

  lda #$c5              ;VCOM control contrast
  jsr TFT_Write_Com
  lda #$3e              ;31,3c in datasheet
  jsr TFT_Write_Data
  lda #$28
  jsr TFT_Write_Data

  lda #$c7              ;VCOM control2 
  jsr TFT_Write_Com
  lda #$86              ;C0 in datasheet
  jsr TFT_Write_Data

  lda #$36              ;Memory Access Control 
  jsr TFT_Write_Com
  lda #$48              ;00 in datasheet
  jsr TFT_Write_Data

  lda #$3a              ;COLMOD: pixel format set
  jsr TFT_Write_Com
  lda #$55              ;66 in datasheet
  jsr TFT_Write_Data

  lda #$b1              ;frame rate control
  jsr TFT_Write_Com
  lda #$00              ;00,1B in datasheet
  jsr TFT_Write_Data
  lda #$18
  jsr TFT_Write_Data

  lda #$b6              ;Display Function Control 
  jsr TFT_Write_Com
  lda #$08              ;0A,82,27,XX in datasheet
  jsr TFT_Write_Data
  lda #$82
  jsr TFT_Write_Data
  lda #$27
  jsr TFT_Write_Data

  lda #$11              ;Exit sleep
  jsr TFT_Write_Com     ;datasheet says this takes 120ms  
  ;add delay here - 120ms
  ldy #$ff              ;run 120 times $78
delay:
  ldx #$ff              ;1ms delay $6f
  jsr Delay_ms
  dey
  bne delay
  
  lda #$29              ;display on
  jsr TFT_Write_Com
  lda #$2c              ;memory write
  jsr TFT_Write_Com

  rts

TFT_Clear:
  
  ;setup screen area
  lda #$2a                  ;Column address set
  jsr TFT_Write_Com
  lda #0                    ;write x1
  jsr TFT_Write_Data
  lda #0
  jsr TFT_Write_Data
  lda #0                    ;write x2 MSB first then LSB
  jsr TFT_Write_Data
  lda #$f0                  
  jsr TFT_Write_Data
  lda #$2b                  ;page address set
  jsr TFT_Write_Com
  lda #0                    ;write y1
  jsr TFT_Write_Data
  lda #0
  jsr TFT_Write_Data
  lda #$01                  ;write y2 MSB first then LSB
  jsr TFT_Write_Data
  lda #$40
  jsr TFT_Write_Data
  lda #$2c                  ;memory write - set memory ready to receive data
  jsr TFT_Write_Com

  ;code to write colours to screen
  ;CS Low
  lda #TFT_CS
  sta PORTA
  ldy #2                            ;set number of halves of screen (2)
draw_half_screen:
  lda #TFT_WIDTH_DIV                ;load dimension of half of screen width into memory
  sta TFT_W_COUNTER                 ;store half of width in RAM
draw_one_w:
  lda #TFT_HEIGHT                   ;load dimension of height into register
  sta TFT_H_COUNTER                 ;store height in RAM 
draw_one_h:
  ldx TFT_PIXEL_COLOUR              ;store colour for one pixel
  lda black,x 
  jsr TFT_Write_Data
  inx
  lda black,x
  jsr TFT_Write_Data
  dec TFT_H_COUNTER                 ;decrement counter
  bne draw_one_h                    ;if not at end of column - loop back and draw another pixel
  dec TFT_W_COUNTER                 ;decrement counter
  bne draw_one_w                    ;if not at end of width segment - loop back and draw another column
  dey
  bne draw_half_screen              ;if not drawn second half of screen - loop back and draw another half
  ;CS High
  ;lda #$ff
  ;sta PORTA
  rts 

TFT_Write_Com:

  pha                                 ;put char onto stack
  lda #%11001111                      ;set RS low (TFT_CS & TFT_RS)
  sta PORTA             
  pla                                 ;pull char back off stack

  sta PORTB                           ;output char onto bus
  lda #%10001111                      ;set tft_wr low (TFT_CS & TFT_RS & TFT_WR)
  sta PORTA
  lda #%11001111                      ;put back into previous state (TFT_CS & TFT_RS)
  sta PORTA

  rts

TFT_Write_Data:

  pha                         ;put char onto stack
  lda #%11101111              ;ensure RS High (TFT_CS)
  sta PORTA             
  pla                         ;pull char back off stack

  sta PORTB                   ;output char onto bus
  lda #%10101111              ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111              ;put back into previous state (TFT_CS)
  sta PORTA

  rts

Delay_ms:
  
  ;delay for 1ms
  nop                 ;nops for delay, this isn't the best way, will tidy later
  nop
  nop
  nop
  nop
  nop
  dex                 ;decrement x register - 2 cycles
  bne Delay_ms        ;2 cycles, 3 cycles if looping
  rts

  ;area for constants to be used by code - needs to be moved to more appropriate place later
  .org $9000

black:    .word BLACK
blue:     .word BLUE
red:      .word RED
green:    .word GREEN
cyan:     .word CYAN
magenta:  .word MAGNETA
yellow:   .word YELLOW
white:    .word WHITE

  ;set program start
  .org $fffc
  .word $8000
  .word $0000
