;BIOS and System Test Rom
;
;Version 2
;
;Base setup is Ben Eater 6502 computer with 6522 VIA on $6000+
;8MHz clock frequency
;TFT screen 480 x 320: D0-D7 on port B, RD,WR,RS,CS on port A A7-A4 
;4 push buttons: on port A A3-A0 also wired to 4 interupts
;
;by Martin Mienczakowski

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;set constants which will be used in code - the assembler replaces references in the code with the respective number/address when compiling
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;System Specific
PORTB = $6000                     ;Address of port B
PORTA = $6001                     ;Address of port A
DDRB  = $6002                     ;Data direction register - port B
DDRA  = $6003                     ;Data direction register - port A
PCR   = $600c                     ;Pehiperal control register - controls positive or negative edges for interupts
IFR   = $600d                     ;Interupt flag register
IER   = $600e                     ;Interupt enable register

BLACK   = $0000                   ;Common screen colours - note stored little endian first as otherwise they get flipped when outputting!
WHITE   = $ffff
RED     = $00f8
CYAN    = $ff07
MAGNETA = $1ff8
GREEN   = $e007
BLUE    = $1F00                  
YELLOW  = $e0ff
ORANGE  = $00fd
BROWN   = $c059
LRED    = $71fc
DGREY   = $eb5a
LGREY   = $d7bd
LGREEN  = $cf07
LBLUE   = $1ea5
LLGREY  = $dbde
LBROWN  = $c0b3

TFT_HEIGHT_MSB      = $01         ;MSB for height of screen for 240 - $00, for 320 - $01 (also comment out H rows which aren't used in text_map_h)
TFT_HEIGHT_LSB      = $40         ;LSB for height of screen for 240 - $f0, for 320 - $40 (also comment out H rows which aren't used in text_map_h)
TFT_WIDTH_MSB       = $01         ;MSB for width of screen for 320 - $01, for 480 - $01
TFT_WIDTH_LSB       = $e0         ;LSB for width of screen for 320 - $40, for 480 - $E0
TFT_HEIGHT_DIV      = $a0         ;height of screen divided by 2 - to work in 8-bit easily - for 240 - $78, for 320 - $a0
TFT_WIDTH_DIV       = $f0         ;width of screen divided by 2 - to work in 8-bit easily - for 320 - $a0, for 480 - $f0
TFT_CHAR_H          = $0f         ;height of one character
TFT_CHAR_H_HALF     = $08         ;half of character height as we use vertical pixels on y axis!
TFT_CHAR_W          = $10         ;width of one character - not happy about why this needs to be one more...
TFT_CURSOR_H_NUM    = $00         ;set cursor start in number of rows
TFT_CURSOR_W_NUM    = $00         ;set cursor start in number of columns
TFT_CHAR_MAP_LSB    = $00         ;LSB part of char map address - note must change these if the character map is moved!
TFT_CHAR_MAP_MSB    = $c0         ;MSB part of char map address - note must change these if the character map is moved!

TFT_RD          = %01111111       ;Control pins for TFT - normally high, triggered low for command
TFT_WR          = %10111111
TFT_RS          = %11011111
TFT_CS          = %11101111
TFT_REST        = %11110111       ;hardware note - since we don't software reset the screen we tie this to 5V and get an extra input pin...

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Memory locations for variables - the assembler replaces these with the respective address when compiling
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;System Specific
CHAR_MAP_LSB        = $80         ;memory locations of LSB and MSB of the character map
CHAR_MAP_MSB        = $81        
CURRENT_MAP_LSB     = $82         ;Stored version of where current char map LSB is - used for character map switching
CURRENT_MAP_MSB     = $83         ;Stored version of where current char map MSB is - used for character map switching
LEVEL_LSB           = $84         ;memory location of LSB and MSB of the level map - used to look at tiles within a level
LEVEL_MSB           = $85
STRING_LSB          = $86         ;memory location of LSB and MSB of a string for printing
STRING_MSB          = $87 

COUNTER_I           = $0200       ;program counter which can be used independently of x,y registers
COUNTER_J           = $0201       ;program counter which can be used independently of x,y registers

TFT_H_COUNTER       = $0202       ;location of TFT height counter for drawing
TFT_W_COUNTER       = $0203       ;location of TFT width counter for drawing
TFT_HALF_COUNTER_H  = $0204       ;counter for faster TFT drawing counts half the screen for H
TFT_HALF_COUNTER_W  = $0205       ;counter for faster TFT drawing counts half the screen for W
TFT_PIXEL_COLOUR    = $0206       ;location of offset of current pixel colour foreground (an increment from black)
TFT_PIXEL_COLOUR_BG = $0207       ;location of offset of current pixel colour background (increment from black)
TFT_CURSOR_H        = $0208       ;location of cursor in y
TFT_CURSOR_H_MSB    = $0209       ;location of cursor in y - MSB
TFT_CURSOR_H_MSB_END= $020a       ;location of cursor end in y - required for row 4
TFT_CURSOR_H_END    = $020b       ;location of cursor end in y (top right of character)
TFT_CURSOR_H_ROW    = $020c       ;location of cursor in number of rows
TFT_CURSOR_W        = $020d       ;location of cursor in x
TFT_CURSOR_W_MSB    = $020e       ;location of cursor in x - MSB
TFT_CURSOR_W_MSB_END= $020f       ;location of cursor end in x - MSB - required for column 16
TFT_CURSOR_W_END    = $0210       ;location of cursor end in x (top right of character)
TFT_CURSOR_W_COL    = $0211       ;location of cursor in number of columns
TFT_BYTE            = $0212       ;current byte from character map
TFT_BYTE_OFFSET     = $0213       ;offset to current character from start of character map - (x by 16 to get actual offset)

STRING_LENGTH       = $0214       ;length of a string for printing

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;String table for the program
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .org $a000

  ;EDGAR SYSTEM TEST 
  .byte $05
  .byte $04
  .byte $07
  .byte $01
  .byte $12
  .byte $1b
  .byte $13
  .byte $19
  .byte $13
  .byte $14
  .byte $05
  .byte $0d
  .byte $1b
  .byte $14
  .byte $05
  .byte $13
  .byte $14
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b

  ;BIOS Version 2
  .byte $02
  .byte $09
  .byte $0f
  .byte $13
  .byte $1b
  .byte $16
  .byte $05
  .byte $12
  .byte $13
  .byte $09
  .byte $0f
  .byte $0e
  .byte $1b
  .byte $1d
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b

  ;Alphabet Test
  .byte $01
  .byte $02
  .byte $03
  .byte $04
  .byte $05
  .byte $06
  .byte $07
  .byte $08
  .byte $09
  .byte $0a
  .byte $0b
  .byte $0c
  .byte $0d
  .byte $0e
  .byte $0f
  .byte $10
  .byte $11
  .byte $12
  .byte $13
  .byte $14
  .byte $15
  .byte $16
  .byte $17
  .byte $18
  .byte $19
  .byte $1a
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b

  ;Number Test
  .byte $1c
  .byte $1d
  .byte $1e
  .byte $1f
  .byte $20
  .byte $21
  .byte $22
  .byte $23
  .byte $24
  .byte $25
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b

  ;Last Button Pressed
  .byte $0c
  .byte $01
  .byte $13
  .byte $14
  .byte $1b
  .byte $02
  .byte $15
  .byte $14
  .byte $14
  .byte $0f
  .byte $0e
  .byte $1b
  .byte $10
  .byte $12
  .byte $05
  .byte $13
  .byte $13
  .byte $05
  .byte $04
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Tile table for the program - Change TILE_MAP_LSB and TILE_MAP_MSB if this is moved in memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .org $a100

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Colour and property tables for tiles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .org $a400

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Level map for the program - Change LEVEL_MAP_LSB and LEVEL_MAP_MSB if this is moved in memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .org $a500

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Main Program Area $8000-$BFFF (16k), every EDGAR program must have a reset, NMI and IRQ label - need to work out addresses of these for program cartirages
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  .org $8000

reset:

  ;Actions to be taken on software reset
  ;System Specific
  lda #$9b                                  ;enable interupts on 6522
  sta IER
  lda #$00                                  ;Set negative edge for interupts
  sta PCR
  
  lda #%11111111                            ;set all lines on port B for output - TFT data bus
  sta DDRB
  lda #%11110000                            ;Set D0-D3 on port A for output - TFT control (note removed one line to add in additional button)
  sta DDRA
  lda #%11110000                            ;set all control pins to high to start (note RESET is hard wired high!)
  sta PORTA

  lda #TFT_CHAR_MAP_LSB                     ;load LSB of character map address 
  sta CURRENT_MAP_LSB
  lda #TFT_CHAR_MAP_MSB                     ;load MSB of character map address 
  sta CURRENT_MAP_MSB

  lda #TFT_CURSOR_H_NUM                     ;set cursor start position as specified in variables above
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  jsr TFT_Init                              ;Initialise Screen

  ;System check code - remove before programming your own code
  lda #$00                                  ;black - fast fill only works for black
  sta TFT_PIXEL_COLOUR
  jsr TFT_Fill_Data                         ;Fast fill screen - replacement function for TFT_Clear    

  lda #$02                                  ;set foreground pixel colour to white
  sta TFT_PIXEL_COLOUR
  lda #0                                    ;set background pixel colour to black
  sta TFT_PIXEL_COLOUR_BG

  ;display messages
  lda #$1e                                  ;store string length
  sta STRING_LENGTH
  lda #$00                                  ;store memory location of string - Edgar Bios Test
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen
  
  lda #4                                    ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #$1e                                  ;store string length
  sta STRING_LENGTH
  lda #$1e                                  ;store memory location of string - BIOS Version 2
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen      

  lda #8                                    ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #$1e                                  ;store string length
  sta STRING_LENGTH
  lda #$3c                                  ;store memory location of string - Alphabet Test
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen         

  lda #10                                    ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #$1e                                  ;store string length
  sta STRING_LENGTH
  lda #$5a                                  ;store memory location of string - Number Test
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen   

  ;check colours
  lda #14                                    ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #1
  sta TFT_BYTE_OFFSET
  
  lda #0
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #2
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #4
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #6
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #8
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #10
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #12
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #14
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #16
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #18
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #20
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #22
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #24
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #28
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #30
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #32
  sta TFT_PIXEL_COLOUR
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  
  ;Test background colours
  lda #16                                    ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #$1b                                  ;space (just show background colour)
  sta TFT_BYTE_OFFSET
  lda #2
  sta TFT_PIXEL_COLOUR
  
  lda #0
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #2
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #4
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #6
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #8
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #10
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #12
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #14
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #16
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #18
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #20
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #22
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #24
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #28
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #30
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char
  lda #32
  sta TFT_PIXEL_COLOUR_BG
  jsr TFT_Draw_Char
  jsr TFT_Next_Char

  ;display message for button test
  lda #$02                                  ;set foreground pixel colour to white
  sta TFT_PIXEL_COLOUR
  lda #0                                    ;set background pixel colour to black
  sta TFT_PIXEL_COLOUR_BG

  lda #20                                    ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #$1e                                  ;store string length
  sta STRING_LENGTH
  lda #$78                                  ;store memory location of string - Last button pressed
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen
  
  cli                                       ;clear interupt disable flag  
  
  ;End of system check code

  ;Program Specific - your program code here
  jmp main_loop
  
main_loop:
  ;The main program loop

loop:
  jmp loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Program specific functions - in this case used for level setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Interupt Handlers - these sort out player movement and game play
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IRQ:

  sei                                       ;disable interupt till we have completed this function
  pha                                       ;store what was in a register to stack

  lda PORTA                                 ;read from port a to reset the interupt
  and #%00000001                            ;see if it was button A
  beq irq_button_A                          ;button A was pressed
  lda PORTA                                 ;read from port a to reset the interupt
  and #%00000010                            ;see if it was button B
  beq irq_button_B                          ;button B was pressed
  lda PORTA                                 ;read from port a to reset the interupt
  and #%00000100                            ;see if it was button C
  beq irq_button_C                          ;button C was pressed
  lda PORTA                                 ;read from port a to reset the interupt
  and #%00001000                            ;see if it was button D
  beq irq_button_D                          ;button D was pressed
  jmp irq_return                            ;if no button could be read return anyway

irq_button_A:
  
  lda #20                                   ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #40
  sta TFT_CURSOR_W_COL

  lda #1
  sta TFT_BYTE_OFFSET
  
  jsr TFT_Draw_Char
  jmp irq_return

irq_button_B:
  
  lda #20                                   ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #40
  sta TFT_CURSOR_W_COL

  lda #2
  sta TFT_BYTE_OFFSET
  
  jsr TFT_Draw_Char
  jmp irq_return

irq_button_C:
  
  lda #20                                   ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #40
  sta TFT_CURSOR_W_COL

  lda #3
  sta TFT_BYTE_OFFSET
  
  jsr TFT_Draw_Char
  jmp irq_return

irq_button_D:
  
  lda #20                                   ;move cursor to new position
  sta TFT_CURSOR_H_ROW
  lda #40
  sta TFT_CURSOR_W_COL

  lda #4
  sta TFT_BYTE_OFFSET
  
  jsr TFT_Draw_Char
  jmp irq_return

irq_return:

  pla                                       ;put a register into previous state
  cli                                       ;enable interupts again
  rti

NMI:

  rti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;BIOS  - $e000 - $fff9 (8k)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  .org $e000

TFT_Init:;Function to initialise the screen

  ;Initialise larger screen which uses a different controller ILI9486
  ;No comments in initialisation code so copying one for one from Adafruit
  lda TFT_CS
  sta PORTA

  lda #$f9                
  jsr TFT_Write_Com       
  lda #$00
  jsr TFT_Write_Data
  lda #$08
  jsr TFT_Write_Data

  lda #$c0                
  jsr TFT_Write_Com       
  lda #$19
  jsr TFT_Write_Data
  lda #$1a
  jsr TFT_Write_Data

  lda #$c1                
  jsr TFT_Write_Com       
  lda #$45
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data

  lda #$c2                
  jsr TFT_Write_Com       
  lda #$33
  jsr TFT_Write_Data

  lda #$c5                
  jsr TFT_Write_Com       
  lda #$00
  jsr TFT_Write_Data
  lda #$28
  jsr TFT_Write_Data

  lda #$b1                
  jsr TFT_Write_Com       
  lda #$90
  jsr TFT_Write_Data
  lda #$11
  jsr TFT_Write_Data

  lda #$b4                
  jsr TFT_Write_Com       
  lda #$02
  jsr TFT_Write_Data

  lda #$b6                
  jsr TFT_Write_Com       
  lda #$00
  jsr TFT_Write_Data
  lda #$02                  ;note change from manufacturers so that screen goes from left to right like old screen $42 was original value
  jsr TFT_Write_Data
  lda #$3b
  jsr TFT_Write_Data

  lda #$b7                
  jsr TFT_Write_Com       
  lda #$07
  jsr TFT_Write_Data

  lda #$e0                
  jsr TFT_Write_Com       
  lda #$1f
  jsr TFT_Write_Data
  lda #$25
  jsr TFT_Write_Data
  lda #$22
  jsr TFT_Write_Data
  lda #$0b
  jsr TFT_Write_Data
  lda #$06
  jsr TFT_Write_Data
  lda #$0a
  jsr TFT_Write_Data
  lda #$4e
  jsr TFT_Write_Data
  lda #$c6
  jsr TFT_Write_Data
  lda #$39
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data

  lda #$e1                
  jsr TFT_Write_Com       
  lda #$1f
  jsr TFT_Write_Data
  lda #$3f
  jsr TFT_Write_Data
  lda #$3f
  jsr TFT_Write_Data
  lda #$0f
  jsr TFT_Write_Data
  lda #$1f
  jsr TFT_Write_Data
  lda #$0f
  jsr TFT_Write_Data
  lda #$46
  jsr TFT_Write_Data
  lda #$49
  jsr TFT_Write_Data
  lda #$31
  jsr TFT_Write_Data
  lda #$05
  jsr TFT_Write_Data
  lda #$09
  jsr TFT_Write_Data
  lda #$03
  jsr TFT_Write_Data
  lda #$1c
  jsr TFT_Write_Data
  lda #$1a
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data

  lda #$f1                
  jsr TFT_Write_Com       
  lda #$36
  jsr TFT_Write_Data
  lda #$04
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$3c
  jsr TFT_Write_Data
  lda #$0f
  jsr TFT_Write_Data
  lda #$0f
  jsr TFT_Write_Data
  lda #$a4
  jsr TFT_Write_Data
  lda #$02
  jsr TFT_Write_Data

  lda #$f2                
  jsr TFT_Write_Com       
  lda #$18
  jsr TFT_Write_Data
  lda #$a3
  jsr TFT_Write_Data
  lda #$12
  jsr TFT_Write_Data
  lda #$02
  jsr TFT_Write_Data
  lda #$32
  jsr TFT_Write_Data
  lda #$12
  jsr TFT_Write_Data
  lda #$ff
  jsr TFT_Write_Data
  lda #$32
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data

  lda #$f4                
  jsr TFT_Write_Com       
  lda #$40
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #$08
  jsr TFT_Write_Data
  lda #$91
  jsr TFT_Write_Data
  lda #$04
  jsr TFT_Write_Data

  lda #$f8                
  jsr TFT_Write_Com       
  lda #$21
  jsr TFT_Write_Data
  lda #$04
  jsr TFT_Write_Data

  lda #$36                
  jsr TFT_Write_Com       
  lda #$48
  jsr TFT_Write_Data

  lda #$3a                
  jsr TFT_Write_Com       
  lda #$55
  jsr TFT_Write_Data

  lda #$11              ;Exit sleep
  jsr TFT_Write_Com     ;datasheet says this takes 120ms  

  ;need to pause 120ms as per datasheet
  lda #$78              ;run 120 times $78 - results in just over 120ms
  sta COUNTER_I
delay:
  jsr Delay_ms
  dec COUNTER_I
  bne delay
  
  lda #$29              ;display on
  jsr TFT_Write_Com
  lda #$2c              ;memory write
  jsr TFT_Write_Com

  rts

TFT_Draw_Char:;Function to output a character to the screen
  
  ;setup character area
  jsr Get_Cursor_H_Coordinate       ;get h and w coordinates from the column and row addresses
  jsr Get_Cursor_W_Coordinate

  lda TFT_CURSOR_H                  ;set cursor y
  clc                               ;work out top right, clear carry - note assuming left hand side of screen for noW
  adc #TFT_CHAR_H                   ;add height of character 
  bcs second_page_h                 ;detect when we are drawing row 4 which starts on page 1 and finishes on page 2 of screen
  sta TFT_CURSOR_H_END              ;store result
  jmp set_cursor_w
  
second_page_h:
  lda #$00
  sta TFT_CURSOR_H_END              ;this code is necessary to fix a bug with drawing row 4
  lda #$01
  sta TFT_CURSOR_H_MSB_END

set_cursor_w:
  lda TFT_CURSOR_W                  ;set cursor x
  clc                               ;work out top right, clear carry - note assuming left hand side of screen for noW
  adc #TFT_CHAR_W                   ;add width of character
  bcs second_page_w                 ;detect when we are drawing column 16 which starts on page 1 and finishes on page 2 of screen! - not the best way of doing this but a fudge for now
  sta TFT_CURSOR_W_END              ;store result
  jmp set_address

second_page_w:
  sta TFT_CURSOR_W_END              ;this code is necessary to fix a bug with drawing column 16
  lda #$01
  sta TFT_CURSOR_W_MSB_END

set_address:
  ;inc TFT_CURSOR_H                  ;carry on with the rest of the code
  ;inc TFT_CURSOR_W
  
  lda #$2a                          ;Column address set - note screen turned on its side so x is y and vice versa!
  jsr TFT_Write_Com
  lda TFT_CURSOR_H_MSB              ;write x1
  jsr TFT_Write_Data
  lda TFT_CURSOR_H
  jsr TFT_Write_Data
  lda TFT_CURSOR_H_MSB_END          ;write x2 MSB first then LSB
  jsr TFT_Write_Data
  lda TFT_CURSOR_H_END                 
  jsr TFT_Write_Data
  lda #$2b                          ;page address set
  jsr TFT_Write_Com
  lda TFT_CURSOR_W_MSB              ;write y1
  jsr TFT_Write_Data
  lda TFT_CURSOR_W
  jsr TFT_Write_Data
  lda TFT_CURSOR_W_MSB_END          ;write y2 MSB first then LSB
  jsr TFT_Write_Data
  lda TFT_CURSOR_W_END
  jsr TFT_Write_Data
  lda #$2c                          ;memory write - set memory ready to receive data
  jsr TFT_Write_Com

  ;code to work out where in the character map we are
  lda CURRENT_MAP_LSB               ;Reset to start of current map
  sta CHAR_MAP_LSB
  lda CURRENT_MAP_MSB
  sta CHAR_MAP_MSB
  ldx TFT_BYTE_OFFSET               ;load the character number
draw_char_scroll:
  clc
  lda CHAR_MAP_LSB                  ;load the LSB
  adc #$10 
  sta CHAR_MAP_LSB                  ;store the LSB
  lda CHAR_MAP_MSB                  ;load current MSB
  adc #$00
  sta CHAR_MAP_MSB                  ;store the MSB
  dex                               ;decrement the counter
  bne draw_char_scroll              ;if reached zero then draw character

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
  ;write out first nibble
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  inx                               ;move to next nibble        
  lda black,x                       ;load relevant nibble
  ;write out second nibble
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  dex
  lda black,x                       ;repeat process for second pixel
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  inx
  lda black,x
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  jmp draw_char_finish
draw_char_bg:
  ldx TFT_PIXEL_COLOUR_BG           ;store colour for one pixel
  lda black,x                       ;load relevant nibble
  ;write out first nibble
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  inx                               ;move to next nibble        
  lda black,x                       ;load relevant nibble
  ;write out second nibble
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  dex
  lda black,x                       ;repeat process for second pixel
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  inx
  lda black,x
  sta PORTB                         ;output char onto bus
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  jmp draw_char_finish

draw_char_h_jmp:                    ;These are needed as BNE can't jmp far enough with the code for the fast routine!
  jmp draw_char_h
draw_char_w_jmp:
  jmp draw_char_w

draw_char_finish:
  rol TFT_BYTE                      ;rotate byte to get next bit
  dec TFT_H_COUNTER                 ;decrement counter
  bne draw_char_h_jmp               ;if not at end of column - loop back and draw another pixel  
  iny                               ;move to next byte for next column
  dec TFT_W_COUNTER                 ;decrement counter
  bne draw_char_w_jmp               ;if not at end of width segment - loop back and draw another column

  rts

TFT_Print_String:;Function to print a string - slower than printing each char individually but more flexible  
  
  lda STRING_LENGTH                     ;load in the length of the string
  sta COUNTER_J                         ;store in counter
  lda #0                                ;reset counter_I
  sta COUNTER_I

print_string_loop:

  ldy COUNTER_I
  lda (STRING_LSB),y                    ;set offset to character we are trying to print
  sta TFT_BYTE_OFFSET
  jsr TFT_Draw_Char                     ;output character
  jsr TFT_Next_Char                     ;move cursor to next position (move on two bytes)
  inc COUNTER_I                         ;move to next character
  clc
  dec COUNTER_J                         ;decrease counter J
  bne print_string_loop                 ;if not at zero carry on

  rts
 
Get_Cursor_H_Coordinate:;Function to get H coordinate from cursor reference (row number)
  
  ldx TFT_CURSOR_H_ROW                  ;get cursor h coordinate
  lda text_map_h,x                      ;read from text map address map for rows 
  sta TFT_CURSOR_H                      ;store lower byte
  inx
  lda text_map_h,x                      ;read from text map address map for rows 
  sta TFT_CURSOR_H_MSB                  ;store higher byte
  sta TFT_CURSOR_H_MSB_END              ;required for row 16 problem - needs a more elegant fix later

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
  sbc #59                               ;needs to be double column width as each column is two bytes - points to first byte
  beq TFT_Next_Line                     ;an efficient way of moving to new line without replecating code in TFT_Next_Line function                  

  rts

TFT_Next_Line:;Function to move the cursor on one line

  inc TFT_CURSOR_H_ROW                ;move to next line
  inc TFT_CURSOR_H_ROW
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

TFT_Fill_Data:;Function to fill the screen with one specific colour for faster clearing / drawing rectangles

  ;setup screen area parameters are set above
  lda #$2a                  ;Column address set - note screen rotated 90 degrees so x is y and vice versa
  jsr TFT_Write_Com
  lda #0                    ;write x1 - one corner of rectangle
  jsr TFT_Write_Data
  lda #0
  jsr TFT_Write_Data
  lda #TFT_HEIGHT_MSB        ;write x2 MSB first then LSB - opposite corner of rectangle
  jsr TFT_Write_Data
  lda #TFT_HEIGHT_LSB                 
  jsr TFT_Write_Data
  lda #$2b                  ;page address set
  jsr TFT_Write_Com
  lda #0                    ;write y1 - one corner of rectangle
  jsr TFT_Write_Data
  lda #$00
  jsr TFT_Write_Data
  lda #TFT_WIDTH_MSB         ;write y2 MSB first then LSB - opposite corner of rectangle
  jsr TFT_Write_Data
  lda #TFT_WIDTH_LSB
  jsr TFT_Write_Data
  lda #$2c                  ;memory write - set memory ready to receive data
  jsr TFT_Write_Com

  ;code to write colours to screen
  lda #TFT_CS                       ;CS Low
  sta PORTA

  ldx TFT_PIXEL_COLOUR              ;store colour for first pixel
  lda black,x 
  jsr TFT_Write_Data
  inx
  lda black,x
  jsr TFT_Write_Data
  
  ;write the rest of the screen
  lda #$02                          ;set number of halves of screen (2)
  sta TFT_HALF_COUNTER_W 
fill_half_screen:
  ldx #TFT_WIDTH_DIV                ;load dimension of half of screen width into memory
fill_one_w:
  ldy #TFT_HEIGHT_DIV               ;load dimension of height into register
fill_one_h:
  ;Strobe screen
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA 
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  ;Strobe screen - again - a very quick way of doing the complete height without logic (we are effectively multiplying the 1/2 height by 2!)
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA 
  lda #%10101111                    ;set tft_wr low (TFT_CS & TFT_WR)
  sta PORTA
  lda #%11101111                    ;put back into previous state (TFT_CS)
  sta PORTA
  dey                               ;decrement counter
  bne fill_one_h                    ;if not at end of column - loop back and draw another pixel
  dex                               ;decrement counter
  bne fill_one_w                    ;if not at end of width segment - loop back and draw another column
  dec TFT_HALF_COUNTER_W
  bne fill_half_screen              ;if not drawn second half of screen - loop back and draw another half

  rts

Delay_ms:;Function to delay for 1ms - 8MHz processor
  
  ldy #$0a                          ;1ms delay $0a - 10 times 0.1ms
delay_ms_outer:  
  ldx #$64                          ;0.1ms delay $64 - 100 times
delay_ms_loop:
  nop                               ;nops for delay, this isn't the best way, will tidy later
  nop
  nop
  nop
  dex                               ;decrement x register - 2 cycles
  bne delay_ms_loop                 ;2 cycles, 3 cycles if looping
  dey                               ;decrement y register - 2 cycles
  bne delay_ms_outer                ;2 cycles, 3 cycles if looping
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Screen Constants and Character Map - $c000-cfff (4k)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  .org $c000
  
char_map:
  ;memory address c000 - note if you move this you need to change the variables at the top of the code, TFT_CHAR_MAP_MSB & TFT_CHAR_MAP_LSB
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
  ;1 - character code 28
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $01
  .byte $01
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  ;2 - character code 29
  .byte $00
  .byte $00
  .byte $83
  .byte $83
  .byte $c1
  .byte $c1
  .byte $a1
  .byte $a1
  .byte $91
  .byte $91
  .byte $89
  .byte $89 
  .byte $87
  .byte $87
  .byte $00
  .byte $00
  ;3 - character code 30
  .byte $00
  .byte $00
  .byte $81
  .byte $81
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99
  .byte $99 
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00
  ;4 - character code 31
  .byte $00
  .byte $00
  .byte $10
  .byte $18
  .byte $1c
  .byte $14
  .byte $12
  .byte $13
  .byte $11
  .byte $ff
  .byte $ff
  .byte $10 
  .byte $10
  .byte $10
  .byte $00
  .byte $00
  ;5 - character code 32
  .byte $00
  .byte $00
  .byte $cf
  .byte $cf
  .byte $c9
  .byte $c9
  .byte $c9
  .byte $c9
  .byte $c9
  .byte $c9
  .byte $c9
  .byte $c9 
  .byte $f9
  .byte $f9
  .byte $00
  .byte $00
  ;6 - character code 33
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff
  .byte $89
  .byte $89
  .byte $89
  .byte $89
  .byte $89
  .byte $89
  .byte $89
  .byte $89 
  .byte $f9
  .byte $f9
  .byte $00
  .byte $00
  ;7 - character code 34
  .byte $00
  .byte $00
  .byte $83
  .byte $83
  .byte $43
  .byte $43
  .byte $23
  .byte $23
  .byte $13
  .byte $13
  .byte $0b
  .byte $0b 
  .byte $07
  .byte $07
  .byte $00
  .byte $00
  ;8- character code 35
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
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00
  ;9 - character code 36
  .byte $00
  .byte $00
  .byte $0f
  .byte $0f
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $09
  .byte $09 
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00
  ;0 - character code 37
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
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00
  
text_map_h:
  ;cursor coordinates h
  .word $0130
  .word $0120
  .word $0110
  .word $0100       
  .word $00f0
  .word $00e0
  .word $00d0
  .word $00c0
  .word $00b0
  .word $00a0
  .word $0090
  .word $0080
  .word $0070
  .word $0060
  .word $0050
  .word $0040
  .word $0030
  .word $0020
  .word $0010
  .word $0000

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
  .word $0140
  .word $0150
  .word $0160
  .word $0170
  .word $0180
  .word $0190
  .word $01a0
  .word $01b0
  .word $01c0
  .word $01d0

;16 colours
black:    .word BLACK   
white:    .word WHITE
red:      .word RED 
cyan:     .word CYAN  
magenta:  .word MAGNETA
green:    .word GREEN   
blue:     .word BLUE               
yellow:   .word YELLOW  
orange:   .word ORANGE
brown:    .word BROWN 
lred:     .word LRED
dgrey:    .word DGREY
lgrey:    .word LGREY
lgreen:   .word LGREEN 
lblue:    .word LBLUE
llgrey:   .word LLGREY
lbrown:   .word LBROWN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Interupt handlers and software reset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  .org $fffa
  .word NMI
  .word reset
  .word IRQ