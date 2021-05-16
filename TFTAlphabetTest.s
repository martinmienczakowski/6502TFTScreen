;Program to interface with 2.8" Elegoo Screen - clear screen then write all characters to the screen
;base setup is Ben Eater 6502 computer with 6522 VIA D0-D7 on port B, RD,WR,RS,CS,REST on port A7-A5
;definetly imperfect code but a proof of concept!
;by Martin Mienczakowski

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;set constants which will be used in code - the assembler replaces references in the code with the respective number/address when compiling
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PORTB = $6000   ;Address of port B
PORTA = $6001   ;Address of port A
DDRB  = $6002   ;Data direction register - port B
DDRA  = $6003   ;Data direction register - port A

BLACK   = $0000   ;Common screen colours - note stored little endian first as otherwise they get flipped when outputting!
BLUE    = $1F00   
RED     = $00f8
GREEN   = $e007
CYAN    = $ff07
MAGNETA = $1ff8
YELLOW  = $e0ff
WHITE   = $ffff

TFT_HEIGHT          = $f0        ;height of screen
TFT_WIDTH_DIV       = $aa        ;width of screen divided by 2 - to work in 8-bit easily
TFT_CHAR_H          = $10        ;height of one character
TFT_CHAR_H_HALF     = $08        ;half of character height as we use vertical pixels on y axis!
TFT_CHAR_W          = $10        ;width of one character - not happy about why this needs to be one more...
TFT_CURSOR_START_H  = $df        ;cursor start position in height $df - top left
TFT_CURSOR_START_W  = $00        ;cursor start position in width $00 - top left
TFT_CURSOR_H_NUM    = $00        ;set cursor start in number of rows
TFT_CURSOR_W_NUM    = $00        ;set cursor start in number of columns
TFT_CHAR_MAP_LSB    = $10        ;LSB part of char map address - note must change these if the character map is moved!
TFT_CHAR_MAP_MSB    = $b0        ;MSB part of char map address - note must change these if the character map is moved!

TFT_RD   = %01111111  ;Control pins for TFT - normally high triggered low for command
TFT_WR   = %10111111
TFT_RS   = %11011111
TFT_CS   = %11101111
TFT_REST = %11110111

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Memory locations for variables - the assembler replaces these with the respective address when compiling
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CHAR_MAP_LSB    = $80               ;memory locations of MSB and LSB of the character map
CHAR_MAP_MSB    = $81

COUNTER_I   = $0900             ;program counter which can be used independently of x,y registers
COUNTER_J   = $0902             ;program counter which can be used independently of x,y registers

TFT_H_COUNTER       = $1000     ;location of TFT height counter for drawing
TFT_W_COUNTER       = $1002     ;location of TFT width counter for drawing
TFT_PIXEL_COLOUR    = $1004     ;location of offset of current pixel colour foreground (an increment from black)
TFT_PIXEL_COLOUR_BG = $1006     ;location of offset of current pixel colour background (increment from black)
TFT_CURSOR_H        = $1008     ;location of cursor in y
TFT_CURSOR_H_END    = $100a     ;location of cursor end in y (top right of character)
TFT_CURSOR_H_ROW    = $100c     ;location of cursor in number of rows
TFT_CURSOR_W        = $100e     ;location of cursor in x
TFT_CURSOR_W_MSB    = $1010     ;location of cursor in x - MSB
TFT_CURSOR_W_MSB_END= $1012     ;location of cursor in x - MSB - required for column 16
TFT_CURSOR_W_END    = $1014     ;location of cursor end in x (top right of character)
TFT_CURSOR_W_COL    = $1016     ;location of cursor in number of columns
TFT_BYTE            = $1018     ;current byte from character map
TFT_BYTE_OFFSET     = $101a     ;offset to current character from start of character map - (x by 16 to get actual offset)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Main Program Area $8000-$AFFF (12k)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  .org $8000

reset:

  ;Actions to be taken on software reset
  lda #%11111111    ;set all lines on port B for output - TFT data bus
  sta DDRB
  lda #%11111000    ;Set D0-D4 on port A for output - TFT control
  sta DDRA
  lda #%11111000    ;set all control pins to high to start
  sta PORTA

  lda #TFT_CHAR_MAP_LSB                     ;load LSB of character map address 
  sta CHAR_MAP_LSB
  lda #TFT_CHAR_MAP_MSB                     ;load MSB of character map address 
  sta CHAR_MAP_MSB

  lda #TFT_CURSOR_H_NUM                     ;set cursor start position as specified in variables above
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  jsr TFT_Init          ;Initialise Screen
  lda #0
  sta TFT_PIXEL_COLOUR  ;set pixel color to black
  jsr TFT_Clear         ;Set screen to black
  jmp main_loop

main_loop:
  ;The main program loop
  ;code to draw one character!
  lda #14                               ;set foreground pixel colour to white
  sta TFT_PIXEL_COLOUR
  lda #0                                ;set background pixel colour to black
  sta TFT_PIXEL_COLOUR_BG

  lda #1                                ;set offset to character we are trying to print - A
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char                     ;output character
  jsr TFT_Next_Char                     ;move cursor to next position (move on two bytes)
  lda #2                                ;set offset to character we are trying to print - B
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #3                                ;set offset to character we are trying to print - C
  sta TFT_BYTE_OFFSET  
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #4                                ;set offset to character we are trying to print - D
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #5                                ;set offset to character we are trying to print - E
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #6                                ;set offset to character we are trying to print - F
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #7                                ;set offset to character we are trying to print - G
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #8                                ;set offset to character we are trying to print - H
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #9                                ;set offset to character we are trying to print - I
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #10                               ;set offset to character we are trying to print - J
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #11                               ;set offset to character we are trying to print - K
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #12                               ;set offset to character we are trying to print - L
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #13                               ;set offset to character we are trying to print - M
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #14                               ;set offset to character we are trying to print - N
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #15                               ;set offset to character we are trying to print - O
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #16                               ;set offset to character we are trying to print - P
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #17                               ;set offset to character we are trying to print - Q
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #18                               ;set offset to character we are trying to print - R
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #19                               ;set offset to character we are trying to print - S
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #20                               ;set offset to character we are trying to print - T
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #21                               ;set offset to character we are trying to print - U
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #22                               ;set offset to character we are trying to print - V
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #23                               ;set offset to character we are trying to print - W
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #24                               ;set offset to character we are trying to print - X
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #25                               ;set offset to character we are trying to print - Y
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #26                               ;set offset to character we are trying to print - Z
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char

  ;Display hello I am Edgar
  jsr TFT_Next_Line                     ;move cursor to next line, if moving more than a couple of lines would be more efficient to set the
  jsr TFT_Next_Line                     ;address directly (4 commands)
  
  lda #8                                ;set offset to character we are trying to print - H
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #5                                ;set offset to character we are trying to print - E
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #12                                ;set offset to character we are trying to print - L
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #12                                ;set offset to character we are trying to print - L
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #15                                ;set offset to character we are trying to print - O
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #27                                ;set offset to character we are trying to print - Space
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #9                                ;set offset to character we are trying to print - I
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #27                                ;set offset to character we are trying to print - Space
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #1                                ;set offset to character we are trying to print - A
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #13                                ;set offset to character we are trying to print - M
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #27                                ;set offset to character we are trying to print - Space
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #5                                ;set offset to character we are trying to print - E
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #4                                ;set offset to character we are trying to print - D
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #7                                ;set offset to character we are trying to print - G
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #1                                ;set offset to character we are trying to print - A
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #18                                ;set offset to character we are trying to print - R
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char
  jsr TFT_Next_Char

loop:
  jmp loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;BIOS  - $e000 - $fff9 (8k)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  .org $e000

TFT_Init:;Function to initialise the screen

  ;much of this function is opaque to me - copied from example from Elegoo (example 1)
  ;I have used the datasheet to look up what each block does and written defaults in comments if defaults aren't used
  ;I've assumed elegoo know how to setup their own screen but different values may enable more functionality
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
  ldy #$ff              ;run 120 times $78 - delay is currently much bigger than needed but has maarginal effect on performance
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

TFT_Clear:;Function to set the screen a specific colour
  
  ;setup screen area 240 x 320
  lda #$2a                  ;Column address set - note screen rotated 90 degrees so x is y and vice versa
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
  lda #$00
  jsr TFT_Write_Data
  lda #$01                  ;write y2 MSB first then LSB
  jsr TFT_Write_Data
  lda #$40
  jsr TFT_Write_Data
  lda #$2c                  ;memory write - set memory ready to receive data
  jsr TFT_Write_Com

  ;code to write colours to screen
  lda #TFT_CS                       ;CS Low
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
  rts
 
TFT_Draw_Char:;Function to output a character to the screen
  
  ;setup character area
  jsr Get_Cursor_H_Coordinate           ;get h and w coordinates from the column and row addresses
  jsr Get_Cursor_W_Coordinate

  lda TFT_CURSOR_H                      ;set cursor y
  clc                                   ;work out top right, clear carry - note assuming left hand side of screen for noW
  adc #TFT_CHAR_H                       ;add height of character - will always be less than 255
  sta TFT_CURSOR_H_END                  ;store result

  lda TFT_CURSOR_W                      ;set cursor x
  clc                                   ;work out top right, clear carry - note assuming left hand side of screen for noW
  adc #TFT_CHAR_W                       ;add width of character
  bcs second_page                       ;detect when we are drawing column 16 which starts on page 1 and finishes on page 2 of screen! - not the best way of doing this but a fudge for now
  sta TFT_CURSOR_W_END                  ;store result
  jmp set_address

second_page:
  sta TFT_CURSOR_W_END                  ;this code is necessary to fix a bug with drawing column 16
  lda #01
  sta TFT_CURSOR_W_MSB_END

set_address:
  inc TFT_CURSOR_H                      ;carry on with the rest of the code
  inc TFT_CURSOR_W
  
  lda #$2a                  ;Column address set - note screen turned on its side so x is y and vice versa!
  jsr TFT_Write_Com
  lda #0                    ;write x1
  jsr TFT_Write_Data
  lda TFT_CURSOR_H
  jsr TFT_Write_Data
  lda #0                    ;write x2 MSB first then LSB
  jsr TFT_Write_Data
  lda TFT_CURSOR_H_END                 
  jsr TFT_Write_Data
  lda #$2b                  ;page address set
  jsr TFT_Write_Com
  lda TFT_CURSOR_W_MSB      ;write y1
  jsr TFT_Write_Data
  lda TFT_CURSOR_W
  jsr TFT_Write_Data
  lda TFT_CURSOR_W_MSB_END  ;write y2 MSB first then LSB
  jsr TFT_Write_Data
  lda TFT_CURSOR_W_END
  jsr TFT_Write_Data
  lda #$2c                  ;memory write - set memory ready to receive data
  jsr TFT_Write_Com

  ;code to work out where in the character map we are
  lda #TFT_CHAR_MAP_LSB      ;Reset to start of character map
  sta CHAR_MAP_LSB
  lda #TFT_CHAR_MAP_MSB
  sta CHAR_MAP_MSB
  ldx TFT_BYTE_OFFSET       ;load the character number
draw_char_scroll:
  clc
  lda CHAR_MAP_LSB          ;load the LSB
  adc #$10 
  sta CHAR_MAP_LSB          ;store the LSB
  lda CHAR_MAP_MSB          ;load current MSB
  adc #$00
  sta CHAR_MAP_MSB          ;store the MSB
  dex                       ;decrement the counter
  bne draw_char_scroll      ;if reached zero then draw character

draw_char:
  ;code to write character to screen
  lda #TFT_CS                       ;CS low
  sta PORTA
  lda #TFT_CHAR_W                   ;load dimension of character width into memory
  sta TFT_W_COUNTER                 ;store dimension of character width in RAM
  ldy #0                            ;load character offset into memory
draw_char_w:
  lda #TFT_CHAR_H_HALF              ;load dimension of character height into register
  sta TFT_H_COUNTER                 ;store character height in RAM 
  lda (CHAR_MAP_LSB),y              ;load current byte from character map
  sta TFT_BYTE                      ;store current byte
draw_char_h:
  lda TFT_BYTE                      ;load current byte into memory
  and #%10000000                    ;compare with MSB - MSB is bottom of char
  beq draw_char_bg                  ;draw background bits else draw foreground bits

draw_char_fg:
  ldx TFT_PIXEL_COLOUR              ;store colour for one pixel
  lda black,x                       ;load relevant nibble
  jsr TFT_Write_Data                ;write out first nibble
  inx                               ;move to next nibble        
  lda black,x                       ;load relevant nibble
  jsr TFT_Write_Data                ;write out second nibble
  ldx TFT_PIXEL_COLOUR              ;store colour for one pixel
  lda black,x                       ;repeat process for second pixel
  jsr TFT_Write_Data
  inx
  lda black,x
  jsr TFT_Write_Data
  jmp draw_char_finish
draw_char_bg:
  ldx TFT_PIXEL_COLOUR_BG           ;store colour for one pixel
  lda black,x                       ;load relevant nibble
  jsr TFT_Write_Data                ;write out first nibble
  inx                               ;move to next nibble        
  lda black,x                       ;load relevant nibble
  jsr TFT_Write_Data                ;write out second nibble
  ldx TFT_PIXEL_COLOUR_BG           ;store colour for one pixel
  lda black,x                       ;repeat process for second pixel
  jsr TFT_Write_Data
  inx
  lda black,x
  jsr TFT_Write_Data
  jmp draw_char_finish

draw_char_finish:
  rol TFT_BYTE                      ;rotate byte to get next bit
  dec TFT_H_COUNTER                 ;decrement counter
  bne draw_char_h                   ;if not at end of column - loop back and draw another pixel  
  iny                               ;move to next byte for next column
  dec TFT_W_COUNTER                 ;decrement counter
  bne draw_char_w                   ;if not at end of width segment - loop back and draw another column

  rts 
 
Get_Cursor_H_Coordinate:;Function to get H coordinate from cursor reference (row number)
  
  ldx TFT_CURSOR_H_ROW                  ;get cursor h coordinate
  lda text_map_h,x                      ;read from text map address map for rows 
  sta TFT_CURSOR_H

  rts 

Get_Cursor_W_Coordinate:;Function to get W coordinate from cursor reference (column number)
  
  ldx TFT_CURSOR_W_COL                  ;get cursor w coordinate
  lda text_map_w,x                      ;read from text map address map for columns
  sta TFT_CURSOR_W                      ;store lower byte
  inx
  lda text_map_w,x 
  sta TFT_CURSOR_W_MSB                  ;store higher byte
  sta TFT_CURSOR_W_MSB_END              ;required for column 16 problem - needs a more elegant fix later

  rts 

TFT_Next_Char:;Function to move the cursor on one character

  inc TFT_CURSOR_W_COL                  ;move to next column
  inc TFT_CURSOR_W_COL

  clc
  lda TFT_CURSOR_W_COL                  ;check if we are at the end of a line
  sbc #39                               ;needs to be double column width as each column is two bytes - points to first byte
  beq TFT_Next_Line                     ;an efficient way of moving to new line without replecating code in TFT_Next_Line function                  

  rts

TFT_Next_Line:;Function to move the cursor on one line

  inc TFT_CURSOR_H_ROW                ;move to next line
  lda #0
  sta TFT_CURSOR_W_COL                ;move cursor back to leftmost position
  rts

TFT_Write_Com:;Function to write a command to screen bus

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

TFT_Write_Data:;Function to write data to screen bus

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

Delay_ms:;Function to delay for a time
  
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Screen Constants and Character Map - $b000-bfff (4k)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  .org $b000

black:    .word BLACK
blue:     .word BLUE
red:      .word RED
green:    .word GREEN
cyan:     .word CYAN
magenta:  .word MAGNETA
yellow:   .word YELLOW 
white:    .word WHITE
  
char_map:
  ;memory address b010 - note if you move this you need to change the variables at the top of the code, TFT_CHAR_MAP_MSB & TFT_CHAR_MAP_LSB
  ;Null character - character code 0
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  ;A - character code 1
  .byte $00
  .byte $00
  .byte $f0
  .byte $f8
  .byte $1c
  .byte $16
  .byte $13
  .byte $11
  .byte $11
  .byte $13
  .byte $16
  .byte $1c 
  .byte $f8
  .byte $f0
  .byte $00
  .byte $00
  ;B - character code 2
  .byte $00
  .byte $00
  .byte $ff 
  .byte $ff 
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99 
  .byte $66
  .byte $66
  .byte $00
  .byte $00
  ;C - character code 3
  .byte $00
  .byte $00
  .byte $3c 
  .byte $3c 
  .byte $42
  .byte $42
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81 
  .byte $81
  .byte $81
  .byte $00
  .byte $00
  ;D - character code 4
  .byte $00
  .byte $00
  .byte $ff  
  .byte $ff  
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81 
  .byte $7e
  .byte $7e
  .byte $00
  .byte $00
  ;E - character code 5
  .byte $00
  .byte $00
  .byte $ff  
  .byte $ff  
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99 
  .byte $81
  .byte $81
  .byte $00
  .byte $00
  ;F - character code 6
  .byte $00
  .byte $00
  .byte $ff  
  .byte $ff  
  .byte $19
  .byte $19
  .byte $19
  .byte $19
  .byte $19
  .byte $19
  .byte $19
  .byte $19 
  .byte $01
  .byte $01
  .byte $00
  .byte $00
  ;G - character code 7
  .byte $00
  .byte $00
  .byte $3c  
  .byte $3c  
  .byte $42
  .byte $42
  .byte $81
  .byte $81
  .byte $89
  .byte $89
  .byte $89
  .byte $89 
  .byte $79
  .byte $79
  .byte $00
  .byte $00
  ;H - character code 8
  .byte $00
  .byte $00
  .byte $ff  
  .byte $ff  
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18 
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00
  ;I - character code 9
  .byte $00
  .byte $00
  .byte $00  
  .byte $00  
  .byte $81
  .byte $81
  .byte $81
  .byte $ff
  .byte $ff
  .byte $81
  .byte $81
  .byte $81 
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  ;J - character code 10
  .byte $00
  .byte $00
  .byte $c0  
  .byte $c0  
  .byte $81
  .byte $81
  .byte $81
  .byte $ff
  .byte $ff
  .byte $01
  .byte $01
  .byte $01 
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  ;K - character code 11
  .byte $00
  .byte $00
  .byte $00
  .byte $ff  
  .byte $ff  
  .byte $18
  .byte $18
  .byte $24
  .byte $24
  .byte $42
  .byte $42
  .byte $81
  .byte $81 
  .byte $00
  .byte $00
  .byte $00
  ;L - character code 12
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff  
  .byte $80  
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $80 
  .byte $80
  .byte $00
  .byte $00
  ;M - character code 13
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff  
  .byte $02  
  .byte $02
  .byte $04
  .byte $04
  .byte $04
  .byte $04
  .byte $02
  .byte $02
  .byte $ff 
  .byte $ff
  .byte $00
  .byte $00
  ;N - character code 14
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff  
  .byte $01  
  .byte $02
  .byte $04
  .byte $08
  .byte $10
  .byte $20
  .byte $40
  .byte $80
  .byte $ff 
  .byte $ff
  .byte $00
  .byte $00
  ;O - character code 15
  .byte $00
  .byte $00
  .byte $7e
  .byte $7e  
  .byte $81  
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $7e 
  .byte $7e
  .byte $00
  .byte $00
  ;P - character code 16 - last of LSB
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff  
  .byte $09  
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $06 
  .byte $06
  .byte $00
  .byte $00  
  ;Q - character code 17 - first of MSB
  .byte $00
  .byte $00
  .byte $7e
  .byte $7e  
  .byte $81  
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  .byte $fe
  .byte $fe 
  .byte $80
  .byte $00
  .byte $00
  ;R - character code 18
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff  
  .byte $09  
  .byte $09
  .byte $19
  .byte $19
  .byte $29
  .byte $29
  .byte $49
  .byte $49
  .byte $86 
  .byte $86
  .byte $00
  .byte $00
  ;S - character code 19
  .byte $00
  .byte $00
  .byte $86
  .byte $86  
  .byte $99  
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $61 
  .byte $61
  .byte $00
  .byte $00 
  ;T - character code 20
  .byte $00
  .byte $00
  .byte $01
  .byte $01  
  .byte $01  
  .byte $01
  .byte $01
  .byte $ff
  .byte $ff
  .byte $01
  .byte $01
  .byte $01
  .byte $01 
  .byte $01
  .byte $00
  .byte $00
  ;U - character code 21
  .byte $00
  .byte $00
  .byte $7f
  .byte $7f  
  .byte $80  
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $80
  .byte $7f 
  .byte $7f
  .byte $00
  .byte $00
  ;V - character code 22
  .byte $00
  .byte $00
  .byte $01
  .byte $07  
  .byte $1e   
  .byte $78
  .byte $60
  .byte $80
  .byte $80
  .byte $60
  .byte $78
  .byte $1e
  .byte $07 
  .byte $01
  .byte $00
  .byte $00
  ;W - character code 23
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff  
  .byte $40  
  .byte $40
  .byte $20
  .byte $20
  .byte $20
  .byte $20
  .byte $40
  .byte $40
  .byte $ff 
  .byte $ff
  .byte $00
  .byte $00
  ;X - character code 24
  .byte $00
  .byte $00
  .byte $00
  .byte $81  
  .byte $c3  
  .byte $66
  .byte $3c
  .byte $18
  .byte $18
  .byte $3c
  .byte $66
  .byte $c3
  .byte $81 
  .byte $00
  .byte $00
  .byte $00
  ;Y - character code 25
  .byte $00
  .byte $00
  .byte $00
  .byte $01  
  .byte $03  
  .byte $06
  .byte $0c
  .byte $f8
  .byte $f8
  .byte $0c
  .byte $06
  .byte $03
  .byte $01 
  .byte $00
  .byte $00
  .byte $00
  ;Z - character code 26
  .byte $00
  .byte $00
  .byte $c1
  .byte $c1  
  .byte $a1  
  .byte $a1
  .byte $91
  .byte $91
  .byte $89
  .byte $89
  .byte $85
  .byte $85
  .byte $83 
  .byte $83
  .byte $00
  .byte $00
  ;Space - character code 27
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  
text_map_h:
  ;cursor coordinates h
  .byte $df
  .byte $cf
  .byte $bf
  .byte $af
  .byte $9f
  .byte $8f
  .byte $7f
  .byte $6f
  .byte $5f
  .byte $4f
  .byte $3f
  .byte $2f
  .byte $1f
  .byte $0f
  .byte $00

text_map_w:
  ;cursor coordinates w
  .word $0000
  .word $0010
  .word $0020
  .word $0030
  .word $0040
  .word $0050
  .word $0060
  .word $0070
  .word $0080
  .word $0090
  .word $00a0
  .word $00b0
  .word $00c0
  .word $00d0
  .word $00e0
  .word $00f0
  .word $0100
  .word $0110
  .word $0120
  .word $0130

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Interupt handlers and software reset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  .org $fffa
  .word $0000
  .word $8000
  .word $0000
