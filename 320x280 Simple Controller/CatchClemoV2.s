;Catch Clemo - a game of cat and...man!
;
;Version 2 
;16 colours like C64 - done
;Colour tiles -done
;Random start locations - done
;Full level design - done
;Improved wall detection through use of property_table - done
;Improved redraw of background when moving - draw the actual tile! - done
;Improved Clemo AI - do same only when player close in W AND H - done
;Faster drawing routines TFT_DRAW_CHAR and TFT_Fill_Data (BIOS CHANGE!) - more code but much faster - done
;Sorted delay_ms (BIOS CHANGE!) - done
;
;Version 1
;First attempt at a game, displays player, Clemo and level, allows movement, tests for catching Clemo, moves Clemo 
;
;Base setup is Ben Eater 6502 computer with 6522 VIA on $6000+
;TFT: D0-D7 on port B, RD,WR,RS,CS ]on port A A7-A4, 
;4 push buttons: on A3-A0 also wired to 4 interupts
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

TFT_HEIGHT          = $f0         ;height of screen
TFT_WIDTH_DIV       = $aa         ;width of screen divided by 2 - to work in 8-bit easily
TFT_CHAR_H          = $10         ;height of one character
TFT_CHAR_H_HALF     = $08         ;half of character height as we use vertical pixels on y axis!
TFT_CHAR_W          = $10         ;width of one character - not happy about why this needs to be one more...
TFT_CURSOR_START_H  = $df         ;cursor start position in height $df - top left
TFT_CURSOR_START_W  = $00         ;cursor start position in width $00 - top left
TFT_CURSOR_H_NUM    = $00         ;set cursor start in number of rows
TFT_CURSOR_W_NUM    = $00         ;set cursor start in number of columns
TFT_CHAR_MAP_LSB    = $00         ;LSB part of char map address - note must change these if the character map is moved!
TFT_CHAR_MAP_MSB    = $b0         ;MSB part of char map address - note must change these if the character map is moved!

TFT_RD          = %01111111       ;Control pins for TFT - normally high triggered low for command
TFT_WR          = %10111111
TFT_RS          = %11011111
TFT_CS          = %11101111
TFT_REST        = %11110111       ;hardware note - since we don't software reset the screen we tie this to 5V and get an extra input pin...

;Program Specific
TILE_MAP_LSB    = $00             ;LSB and MSB of tile map
TILE_MAP_MSB    = $a1
LEVEL_MAP_LSB   = $00             ;LSB and MSB of level map
LEVEL_MAP_MSB   = $a5

PLAYER_BYTE_OFFSET      = $01     ;tile number for player character
CLEMO_BYTE_OFFSET       = $02     ;tile number for Clemo
BACKGROUND_BYTE_OFFSET  = $03     ;tile number for blank background
WALL_BYTE_OFFSET        = $04     ;tile number for standard wall

CLEMO_CLOSENESS         = $04     ;How close we can get to Clemo before she starts to run away!
CLEMO_START_OFFSET      = $7f     ;what the offset is on the 'random' number generator used to spawn Clemo

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

COUNTER_I           = $0300       ;program counter which can be used independently of x,y registers
COUNTER_J           = $0301       ;program counter which can be used independently of x,y registers

TFT_H_COUNTER       = $0302       ;location of TFT height counter for drawing
TFT_W_COUNTER       = $0303       ;location of TFT width counter for drawing
TFT_HALF_COUNTER    = $0304       ;counter for faster TFT drawing counts half the screen
TFT_PIXEL_COLOUR    = $0305       ;location of offset of current pixel colour foreground (an increment from black)
TFT_PIXEL_COLOUR_BG = $0306       ;location of offset of current pixel colour background (increment from black)
TFT_CURSOR_H        = $0307       ;location of cursor in y
TFT_CURSOR_H_END    = $0308       ;location of cursor end in y (top right of character)
TFT_CURSOR_H_ROW    = $0309       ;location of cursor in number of rows
TFT_CURSOR_W        = $030a       ;location of cursor in x
TFT_CURSOR_W_MSB    = $030b       ;location of cursor in x - MSB
TFT_CURSOR_W_MSB_END= $030c       ;location of cursor in x - MSB - required for column 16
TFT_CURSOR_W_END    = $030d       ;location of cursor end in x (top right of character)
TFT_CURSOR_W_COL    = $030e       ;location of cursor in number of columns
TFT_BYTE            = $030f       ;current byte from character map
TFT_BYTE_OFFSET     = $0310       ;offset to current character from start of character map - (x by 16 to get actual offset)

STRING_LENGTH       = $0311       ;length of a string for printing

;Program Specific
CHARACTER_CURRENT_W = $0400       ;Character w location
CHARACTER_CURRENT_H = $0401       ;Character h location
CHARACTER_NEXT_W    = $0402       ;Character next w location - used to test for a legal move
CHARACTER_NEXT_H    = $0403       ;Character next h location
CLEMO_CURRENT_W     = $0404       ;Clemo w location
CLEMO_CURRENT_H     = $0405       ;Clemo h location
CLEMO_NEXT_W        = $0406       ;Clemo w location
CLEMO_NEXT_H        = $0407       ;Clemo h location

TILE_NUMBER_LSB     = $0408       ;Current tile number (could be more than 256 so we need LSB and MSB!), used to determine if a move is legal
TILE_NUMBER_MSB     = $0409
BG_TILE_NUMBER_LSB  = $040a       ;Current background tile number (could be more than 256 so we need LSB and MSB!), used when moving player/Clemo
BG_TILE_NUMBER_MSB  = $040b
MULTIPLICATION_F1   = $040c       ;Multiplication factor 1
MULTIPLICATION_F2   = $040d       ;Multiplication factor 2
TEMP_1              = $040e       ;Temporary variable 1 - used in Get_Tile_Number
TEMP_2              = $040f       ;Temporary variable 1 - used in Get_Tile_Number
TEMP_3              = $0410       ;Temporary variable 4 - used in clemo movement routine so character movement routines can be reused
TEMP_4              = $0411       ;Temporary variable 4 - used in clemo movement routine so character movement routines can be reused

NEXT_TILE_STATUS    = $0412       ;Status of proposed move - 1 = wall or Clemo
PLAYER_LAST_MOVE    = $0413       ;Last player move direction - 0 = left, 1 = right, 2 = up, 3 = down
BG_BYTE_OFFSET      = $0414       ;Offset to the current background tile - used for moving player/Clemo

GAME_STARTED        = $0415       ;Have Clemo and the player been spawned? 0 = no, 1 = yes, used when spawning Clemo / player
PLAYER_RND          = $0416       ;The player random number - populated when spawning
CLEMO_RND           = $0417       ;Clemo random number - populated when spawning

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;String table for the program
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .org $a000

  ;Catch Clemo 
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $03
  .byte $01
  .byte $14
  .byte $03
  .byte $08
  .byte $1b
  .byte $03
  .byte $0c
  .byte $05
  .byte $0d
  .byte $0f
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b

  ;You caught her
  .byte $19
  .byte $0f
  .byte $15
  .byte $1b
  .byte $03
  .byte $01
  .byte $15
  .byte $07
  .byte $08
  .byte $14
  .byte $1b
  .byte $08
  .byte $05
  .byte $12
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b
  .byte $1b

  ;Loading
  .byte $0c
  .byte $0f
  .byte $01
  .byte $04
  .byte $09
  .byte $0e
  .byte $07
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

  ;Press buttoon
  .byte $10
  .byte $12
  .byte $05
  .byte $13
  .byte $13
  .byte $1b
  .byte $02
  .byte $15
  .byte $14
  .byte $14
  .byte $0f
  .byte $0e
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

  ;Null Character
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

  ;Player Character - 01
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $d2
  .byte $d5
  .byte $3d
  .byte $3d
  .byte $d5
  .byte $d2
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00

  ;Clemo - 02
  .byte $00
  .byte $00
  .byte $07
  .byte $06
  .byte $7e
  .byte $1f
  .byte $78
  .byte $18
  .byte $78
  .byte $18
  .byte $78
  .byte $18 
  .byte $04
  .byte $02
  .byte $00
  .byte $00
  
  ;Blank Background - 03
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
    
  ;Full Wall - 04
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff 
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff

  ;Window - 05
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00

  ;Bricks - 06
  .byte $24
  .byte $24
  .byte $24
  .byte $e7
  .byte $24
  .byte $24
  .byte $24
  .byte $3c
  .byte $24
  .byte $24
  .byte $24
  .byte $e7 
  .byte $24
  .byte $24
  .byte $24
  .byte $3c

  ;Grass Background 1 - 07
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

  ;Grass Background 2 - 08
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
  
  ;Fire Left - 09
  .byte $e0
  .byte $f0
  .byte $f8
  .byte $f8
  .byte $f0
  .byte $e0
  .byte $f0
  .byte $f0
  .byte $f8
  .byte $fc
  .byte $fc
  .byte $f8 
  .byte $f0
  .byte $f8
  .byte $f0
  .byte $e0
  
  ;Fire right - 0a
  .byte $c0
  .byte $80
  .byte $80
  .byte $c0
  .byte $e0
  .byte $e0
  .byte $c0
  .byte $80
  .byte $c0
  .byte $e0
  .byte $f0
  .byte $f8 
  .byte $f8
  .byte $f0
  .byte $e0
  .byte $c0

  ;Door - 0b
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff
  .byte $40
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00

  ;Picture Left - 0c
  .byte $ff
  .byte $ff
  .byte $81
  .byte $81
  .byte $81
  .byte $b1
  .byte $b9
  .byte $bd
  .byte $bd
  .byte $b9
  .byte $b1
  .byte $81 
  .byte $81
  .byte $81
  .byte $ff
  .byte $ff

  ;Picture Right - 0d
  .byte $ff
  .byte $ff
  .byte $81
  .byte $81
  .byte $89
  .byte $a9
  .byte $b9
  .byte $9d
  .byte $9d
  .byte $b9
  .byte $a9
  .byte $89 
  .byte $81
  .byte $81
  .byte $ff
  .byte $ff

  ;Fence Horizontal - 0e
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18 
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  
  ;Fence Corner - 0f
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $18
  .byte $f8
  .byte $f8
  .byte $f8
  .byte $f8
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00

  ;Fence Vertical 1 - 10
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00

  ;Fence Vertical 2 - 11
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00

  ;Conservatory Window Horiztonal - 12
  .byte $ff
  .byte $ff
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $c3
  .byte $ff
  .byte $ff
  
  ;Conservatory Window Vertical - 13
  .byte $ff
  .byte $ff
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
  .byte $ff
  .byte $ff

  ;Sofa Horizontal 1 - 14
  .byte $ff
  .byte $ff
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
  .byte $80
  .byte $80

  ;Sofa Horizontal 2 - 15
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
  .byte $80
  .byte $80
  .byte $ff
  .byte $ff
  
  ;Sofa Horizontal 3 - 16
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
  .byte $80
  .byte $80 
  .byte $ff
  .byte $ff
  .byte $ff
  .byte $ff

  
  ;Sofa Vertical 1 - 17
  .byte $ff
  .byte $ff
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03 
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  
  ;Sofa Vertical 2 - 18
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
  .byte $81
  .byte $81 
  .byte $81
  .byte $81
  .byte $81
  .byte $81
  
  ;Sofa Vertical 3 - 19
  .byte $ff
  .byte $ff
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0 
  .byte $c0
  .byte $c0
  .byte $c0
  .byte $c0

  ;Table 1 - 1a
  .byte $07
  .byte $03
  .byte $01
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
  .byte $01
  .byte $03
  .byte $07
  
  ;Table 2 - 1b
  .byte $e0
  .byte $c0
  .byte $80
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
  .byte $80
  .byte $c0
  .byte $e0
  
  ;Fish Tank 1 - 1c
  .byte $00
  .byte $00
  .byte $0c
  .byte $1e
  .byte $1a
  .byte $1a
  .byte $1e
  .byte $1e
  .byte $1e
  .byte $1e
  .byte $0c
  .byte $0c 
  .byte $1e
  .byte $1e
  .byte $00
  .byte $00
    
  ;Fish Tank 2 - 1d
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $88
  .byte $88
  .byte $20
  .byte $20
  .byte $00
  .byte $00 
  .byte $00
  .byte $00
  .byte $00
  .byte $00
    
  ;Oven - 1e
  .byte $00
  .byte $00
  .byte $66
  .byte $66
  .byte $66
  .byte $66
  .byte $00
  .byte $00
  .byte $00
  .byte $00
  .byte $66
  .byte $66 
  .byte $66
  .byte $66
  .byte $00
  .byte $00
    
  ;Fridge - 1f
  .byte $7f
  .byte $7f
  .byte $ff
  .byte $ff
  .byte $7f
  .byte $7f
  .byte $7f
  .byte $7f
  .byte $7f
  .byte $7f
  .byte $7f
  .byte $7f 
  .byte $7f
  .byte $7f
  .byte $7f
  .byte $7f  

  ;Counter Top - 20
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

  ;Table 3 - 21
  .byte $07
  .byte $03
  .byte $01
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
  .byte $01
  .byte $03
  .byte $07
  
  ;Table 4 - 22
  .byte $e0
  .byte $c0
  .byte $80
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
  .byte $80
  .byte $c0
  .byte $e0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Colour and property tables for tiles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .org $a400

colour_table:
  ;Format is background colour number then foreground colour number - stored as a word
  ;0 - black, 2 - white, 4 - red, 6 - cyan, 8 - magenta, a - green, c - blue, e - yellow, 10 - orange, 12 - brown, 14 - light red
  ;16 - dark grey, 18 - light grey, 1a - dark green, 1c - light blue, 1e - very light grey, 20 - light brown
  .word $0000                   ;00 - null tile - black, black
  .word $0002                   ;01 - player - black, white
  .word $0002                   ;02 - Clemo - black, white
  .word $0000                   ;03 - Blank background - black, black
  .word $0016                   ;04 - Solid wall - black, dark grey
  .word $0006                   ;05 - window - black, cyan
  .word $0402                   ;06 - bricks - red, white
  .word $0a00                   ;07 - grass 1 - green, black
  .word $1a00                   ;08 - grass 2 - dark green, black
  .word $0010                   ;09 - fire left - black, orange
  .word $0010                   ;0a - fire right - black, orange
  .word $0012                   ;0b - door - black, brown
  .word $000c                   ;0c - picture left - black, blue
  .word $000e                   ;0d - picture right - black, yellow
  .word $1a12                   ;0e - fence horizontal - dark green, brown
  .word $1a12                   ;0f - fence corner - dark green, brown
  .word $0a12                   ;10 - fence vertical 1 - green, brown
  .word $1a12                   ;11 - fence vertical 2 - dark green, brown
  .word $0c12                   ;12 - conservatory window horizontal - blue, brown
  .word $0c12                   ;13 - conservatory window vertical - blue, brown
  .word $1816                   ;14 - sofa horizontal 1 - light grey, dark grey
  .word $1816                   ;15 - sofa horizontal 2 - light grey, dark grey
  .word $1816                   ;16 - sofa horizontal 3 - light grey, dark grey
  .word $1816                   ;17 - sofa vertical 1 - light grey, dark grey
  .word $1816                   ;18 - sofa vertical 2 - light grey, dark grey
  .word $1816                   ;19 - sofa vertical 3 - light grey, dark grey
  .word $1200                   ;1a - table 1 - brown, black
  .word $1200                   ;1b - table 2 - brown, black
  .word $0c10                   ;1c - fish tank 1 - blue, orange
  .word $0c02                   ;1d - fish tank 2 - blue, white
  .word $0002                   ;1e - oven - black, white
  .word $0002                   ;1f - fridge - black, white
  .word $1200                   ;20 - counter top - brown, black
  .word $2000                   ;21 - table 3 - lbrown, black
  .word $2000                   ;22 - table 4 - lbrown, black

property_table:
  ;Property of tile
  .byte $01                     ;00 - null tile
  .byte $01                     ;01 - player - can't move on top of
  .byte $00                     ;02 - Clemo - can move on top of
  .byte $00                     ;03 - blank background - can move on top of
  .byte $01                     ;04 - solid wall - can't move on top of
  .byte $01                     ;05 - window - can't move on top of
  .byte $01                     ;06 - bricks - can't move on top of
  .byte $00                     ;07 - grass 1 - can move on top of
  .byte $00                     ;08 - grass 2 - can move on top of
  .byte $01                     ;09 - fire left - can't move on top of
  .byte $01                     ;0a - fire right - can't move on top of
  .byte $01                     ;0b - door - can't move on top of
  .byte $01                     ;0c - picture left - can't move on top of
  .byte $01                     ;0d - picture right - can't move on top of
  .byte $01                     ;0e - fence horizontal - can't move on top of
  .byte $01                     ;0f - fence corner - can't move on top of
  .byte $01                     ;10 - fence vertical 1 - can't move on top of
  .byte $01                     ;11 - fence vertical 2 - can't move on top of
  .byte $01                     ;12 - conservatory window horizontal - can't move on top of
  .byte $01                     ;13 - conservatory window vertical - can't move on top of
  .byte $01                     ;14 - sofa horizontal 1 - can't move on top of
  .byte $01                     ;15 - sofa horizontal 2 - can't move on top of
  .byte $01                     ;16 - sofa horizontal 3 - can't move on top of
  .byte $01                     ;17 - sofa vertical 1 - can't move on top of
  .byte $01                     ;18 - sofa vertical 2 - can't move on top of
  .byte $01                     ;19 - sofa vertical 3 - can't move on top of
  .byte $01                     ;1a - table 1 - can't move on top of
  .byte $01                     ;1b - table 2 - can't move on top of
  .byte $01                     ;1c - fish tank 1 - can't move on top of
  .byte $01                     ;1d - fish tank 2 - can't move on top of
  .byte $01                     ;1e - oven - can't move on top of
  .byte $01                     ;1f - fridge - can't move on top of
  .byte $01                     ;20 - counter top - can't move on top of
  .byte $01                     ;21 - table 3 - can't move on top of
  .byte $01                     ;22 - table 4 - can't move on top of

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Level map for the program - Change LEVEL_MAP_LSB and LEVEL_MAP_MSB if this is moved in memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .org $a500

  ;Row 1
  .byte $06
  .byte $0c
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $0d
  .byte $06
  .byte $0e
  .byte $0e
  .byte $0e
  .byte $0e 
  .byte $0e
  .byte $0e
  .byte $0e
  .byte $0e
  .byte $0e
  .byte $0e
  .byte $0e
  .byte $0f
  ;Row 2
  .byte $06
  .byte $06
  .byte $06
  .byte $09
  .byte $0a
  .byte $06
  .byte $06
  .byte $06
  .byte $07
  .byte $07
  .byte $07
  .byte $07 
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $10
  ;Row 3
  .byte $05
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $08
  .byte $08
  .byte $08
  .byte $08 
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $11
  ;Row 4
  .byte $05
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $07
  .byte $07
  .byte $07
  .byte $07 
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $10
  ;Row 5
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $06
  .byte $08
  .byte $08
  .byte $08
  .byte $08 
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $08
  .byte $11
  ;Row 6
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $06
  .byte $07
  .byte $07
  .byte $07
  .byte $07 
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $07
  .byte $10
  ;Row 7
  .byte $0b
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06 
  .byte $06
  .byte $06
  .byte $12
  .byte $12
  .byte $03
  .byte $03
  .byte $12
  .byte $12
  ;Row 8
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $1d
  .byte $06
  .byte $1f
  .byte $1e
  .byte $1e
  .byte $20 
  .byte $20
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $13
  ;Row 9
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $1c
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03 
  .byte $03
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $13
  ;Row 10
  .byte $06
  .byte $17
  .byte $03
  .byte $1a
  .byte $03
  .byte $03
  .byte $03
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03 
  .byte $03
  .byte $06
  .byte $03
  .byte $03
  .byte $21
  .byte $03
  .byte $03
  .byte $13
  ;Row 11
  .byte $05
  .byte $18
  .byte $03
  .byte $1b
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03 
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $22
  .byte $03
  .byte $03
  .byte $13
  ;Row 12
  .byte $05
  .byte $19
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03 
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $13
  ;Row 13
  .byte $06
  .byte $03
  .byte $14
  .byte $15
  .byte $16
  .byte $03
  .byte $03
  .byte $06
  .byte $20
  .byte $20
  .byte $20
  .byte $20 
  .byte $20
  .byte $06
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $03
  .byte $13
  ;Row 14
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06
  .byte $06 
  .byte $06
  .byte $06
  .byte $12
  .byte $12
  .byte $12
  .byte $12
  .byte $12
  .byte $12

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Main Program Area $8000-$AFFF (12k), every EDGAR program must have a reset, NMI and IRQ label - need to work out addresses of these for program cartirages
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

  lda #LEVEL_MAP_LSB                        ;load LSB of level map address 
  sta LEVEL_LSB
  lda #LEVEL_MAP_MSB                        ;load MSB of level map address 
  sta LEVEL_MSB

  lda #TFT_CURSOR_H_NUM                     ;set cursor start position as specified in variables above
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  jsr TFT_Init                              ;Initialise Screen

  ;Set the screen to black before drawing in level - not used currently
  ;lda $00                                   ;Set colour to black
  ;sta TFT_PIXEL_COLOUR
  ;jsr TFT_Fill_Data                         ;Fast fill screen - replacement function for TFT_Clear           

  jmp main_loop

  ;Program Specific
  

main_loop:
  ;The main program loop

  lda #$02                                  ;set foreground pixel colour to white
  sta TFT_PIXEL_COLOUR
  lda #0                                    ;set background pixel colour to black
  sta TFT_PIXEL_COLOUR_BG

  ;display the loading message
  lda #$14                                  ;store string length
  sta STRING_LENGTH
  lda #$28                                  ;store memory location of string - loading string
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen 

  ;Switch to tile map and draw level including characters
  ;note if you wish to use the text characters again you need to reset the char map LSB and MSB addresses!
  lda #TILE_MAP_LSB                         ;load LSB of tile map address and set to current character map address 
  sta CURRENT_MAP_LSB
  lda #TILE_MAP_MSB                         ;load MSB of tile map address and set to current character map address 
  sta CURRENT_MAP_MSB

  jsr Draw_Level                            ;routine to draw the level

  ;reset to character map not level tile map!
  lda #TFT_CHAR_MAP_LSB                     ;load LSB of character map address 
  sta CURRENT_MAP_LSB
  lda #TFT_CHAR_MAP_MSB                     ;load MSB of character map address 
  sta CURRENT_MAP_MSB
  
  lda #TFT_CURSOR_H_NUM                     ;set cursor start position as specified in variables above
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #$02                                  ;set foreground pixel colour to white
  sta TFT_PIXEL_COLOUR
  lda #0                                    ;set background pixel colour to black
  sta TFT_PIXEL_COLOUR_BG

  ;display the instruction
  lda #$14                                  ;store string length
  sta STRING_LENGTH
  lda #$3c                                  ;store memory location of string - press button string
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen 

  ;reset to level map
  lda #TILE_MAP_LSB                         ;load LSB of tile map address and set to current character map address 
  sta CURRENT_MAP_LSB
  lda #TILE_MAP_MSB                         ;load MSB of tile map address and set to current character map address 
  sta CURRENT_MAP_MSB

  cli                                       ;clear interupt disable flag

  ;setup counters for random start locations
  lda #$00
  sta GAME_STARTED                          ;indicate that we haven't started the game
  ldx #$00                                  ;used for player start location random variable
  ldy #CLEMO_START_OFFSET                   ;used for clemo start location

loop:
  inx                                       ;effectively do a random number by constantly scrolling x register until player starts game
  dey                                       ;effectively do a random number by constantly scrolling y register until player starts game
  jmp loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Program specific functions - in this case used for level setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Draw_Level:;function to draw an entire level
  
  ;loop to print level 
  ;first set the cursor to top left
  lda #$00                                  ;move cursor to a location - top left of level
  sta TFT_CURSOR_W_COL
  lda #$01
  sta TFT_CURSOR_H_ROW

  ;Draw level in 2 parts - the first 255 tiles then the remaining tiles, must be a more efficient way than this but this works!
  lda #$ff                                  ;set counter for number of tiles in level
  sta COUNTER_I
  lda #$00                                  ;set offset to tile
  sta COUNTER_J

draw_level_loop_first:
  ldy COUNTER_J                             ;need to do this this way as y register used by other functions
  lda (LEVEL_LSB),y                         ;set byte offset to current tile
  sta TFT_BYTE_OFFSET                       ;store current tile for drawing
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  jsr TFT_Next_Char                         ;move cursor on one - automatically moves to next line
  inc COUNTER_J                             ;increment counter - move to next tile
  dec COUNTER_I                             ;decrement counter
  bne draw_level_loop_first                 ;if positive (we haven't drawn 256 tiles) 

  ;draw tile 256
  ldy #$ff
  lda (LEVEL_LSB),y                         ;set byte offset to current tile
  sta TFT_BYTE_OFFSET                       ;store current tile for drawing
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  jsr TFT_Next_Char                         ;move cursor on one - automatically moves to next line

  ;draw second portion of level
  inc LEVEL_MSB                             ;move on MSB by 1
  lda #$18                                  ;set counter for number of tiles in level
  sta COUNTER_I
  lda #$00                                  ;set offset to tile
  sta COUNTER_J

draw_level_loop_second:
  ldy COUNTER_J                             ;need to do this this way as y register used by other functions
  lda (LEVEL_LSB),y                         ;set byte offset to current tile
  sta TFT_BYTE_OFFSET                       ;store current tile for drawing
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  jsr TFT_Next_Char                         ;move cursor on one - automatically moves to next line
  inc COUNTER_J                             ;increment counter - move to next tile
  dec COUNTER_I                             ;decrement counter
  bne draw_level_loop_second                ;if not at zero draw next tile 

  dec LEVEL_MSB                             ;return MSB to start of level table

  rts

Get_Tile_Number:;function to get a tile number from H and W coordinates

  lda CHARACTER_NEXT_H                       ;set up multiplication factors
  sta TEMP_1                                 ;temporary variable used to preserve character next move coordinates
  dec TEMP_1                                 ;minus 1 to translate into level coordinates (first line of screen is text)
  lda TEMP_1
  sta MULTIPLICATION_F1
  lda #$14                                  ;number of tiles in a row
  sta MULTIPLICATION_F2

  ;use multiplication to get tile number - if successful implement into BIOS - function works
  lda #$00
  ldx #$08
get_tile_number_loop_1:                     ;routine from - https://llx.com/Neil/a2/mult.html#:~:text=The%20best%20way%20to%20get%20fast%20multiplication%20or,it%20looks%20up%20the%20answer%20in%20the%20table.
  lsr MULTIPLICATION_F2
  bcc get_tile_number_loop_2
  clc
  adc MULTIPLICATION_F1
get_tile_number_loop_2:
  ror
  ror TILE_NUMBER_LSB
  dex
  bne get_tile_number_loop_1
  sta TILE_NUMBER_MSB

  lda CHARACTER_NEXT_W
  sta TEMP_2                                ;temporary variables used to preserve character next coordinates
  lsr TEMP_2                                ;divide by 2
  clc                                       ;above routine works out start of row we are on - now work out tile number by adding on W coordinate
  lda TILE_NUMBER_LSB
  adc TEMP_2
  sta TILE_NUMBER_LSB
  lda TILE_NUMBER_MSB
  adc #00
  sta TILE_NUMBER_MSB

  rts

Set_Background_Tile_Offset:;function to set the byteoffset for the background tile we are replacing the player with

  lda CHARACTER_CURRENT_H                       ;set up multiplication factors
  sta TEMP_1                                 ;temporary variable used to preserve character next move coordinates
  dec TEMP_1                                 ;minus 1 to translate into level coordinates (first line of screen is text)
  lda TEMP_1
  sta MULTIPLICATION_F1
  lda #$14                                  ;number of tiles in a row
  sta MULTIPLICATION_F2

  ;use multiplication to get tile number - if successful implement into BIOS - function works
  lda #$00
  ldx #$08
get_bg_tile_number_loop_1:                     ;routine from - https://llx.com/Neil/a2/mult.html#:~:text=The%20best%20way%20to%20get%20fast%20multiplication%20or,it%20looks%20up%20the%20answer%20in%20the%20table.
  lsr MULTIPLICATION_F2
  bcc get_bg_tile_number_loop_2
  clc
  adc MULTIPLICATION_F1
get_bg_tile_number_loop_2:
  ror
  ror BG_TILE_NUMBER_LSB
  dex
  bne get_bg_tile_number_loop_1
  sta BG_TILE_NUMBER_MSB

  lda CHARACTER_CURRENT_W
  sta TEMP_2                                ;temporary variables used to preserve character next coordinates
  lsr TEMP_2                                ;divide by 2
  clc                                       ;above routine works out start of row we are on - now work out tile number by adding on W coordinate
  lda BG_TILE_NUMBER_LSB
  adc TEMP_2
  sta BG_TILE_NUMBER_LSB
  lda BG_TILE_NUMBER_MSB
  adc #00
  sta BG_TILE_NUMBER_MSB

  ;set offset to tile we wish to check
  clc
  lda #LEVEL_MAP_LSB
  adc BG_TILE_NUMBER_LSB
  sta LEVEL_LSB 
  lda #LEVEL_MAP_MSB
  adc BG_TILE_NUMBER_MSB
  sta LEVEL_MSB

  ldy #$00
  lda (LEVEL_LSB),y                      ;load in the tile of interest
  sta BG_BYTE_OFFSET

  rts


Check_For_Wall:;function to test if a tile is a wall - sets NEXT_TILE_STATUS to 1 if wall is present

  lda #$00
  sta NEXT_TILE_STATUS                    ;set for no wall initially

  ;set offset to tile we wish to check
  clc
  lda #LEVEL_MAP_LSB
  adc TILE_NUMBER_LSB
  sta LEVEL_LSB 
  lda #LEVEL_MAP_MSB
  adc TILE_NUMBER_MSB
  sta LEVEL_MSB

  ldy #$00
  lda (LEVEL_LSB),y                      ;load in the tile of interest
  tax                                    ;transfer tile number to x register
  lda property_table,x                   ;load property
  sta NEXT_TILE_STATUS                   ;store the value

check_for_wall_finish:
  ;reset LEVEL_LSB and LEVEL_MSB to start of the level map
  lda #LEVEL_MAP_LSB                     ;load LSB of level map address 
  sta LEVEL_LSB
  lda #LEVEL_MAP_MSB                     ;load MSB of level map address 
  sta LEVEL_MSB

  rts

Check_For_Clemo:;function to test if a tile is Clemo - sets NEXT_TILE_STATUS to 1 if Clemo is present

  lda #$00
  sta NEXT_TILE_STATUS                    ;set for no Clemo initially

  lda CHARACTER_NEXT_H                    ;see if Clemo is in the spot we want to move to!
  eor CLEMO_CURRENT_H                     ;XOR with Clemo h location
  beq check_for_clemo_w                   ;she is in h test for w
  jmp check_for_clemo_return

 check_for_clemo_w: 
  lda CHARACTER_NEXT_W                    ;see if Clemo is in the spot we want to move to!
  eor CLEMO_CURRENT_W                     ;XOR with Clemo w location
  beq check_for_clemo_found               ;she is!
  jmp check_for_clemo_return              ;she isn't in h or w

check_for_clemo_found
  lda #$01
  sta NEXT_TILE_STATUS                    ;set flag for clemo found

check_for_clemo_return:

  rts

Move_Clemo:;function to act as AI unit - moves Clemo depending on what the player's move was!

 move_clemo_check_w:;see how close we are - w check
  lda CHARACTER_CURRENT_W
  cmp CLEMO_CURRENT_W
  bcs move_clemo_clemo_low_w                ;clemo is to left of character - deal with that
  clc                                       ;Clemo is right of character
  lda CLEMO_CURRENT_W                       ;calculate horizontal seperation and then test
  sbc CHARACTER_CURRENT_W
  cmp #CLEMO_CLOSENESS                      ;check if horizontal seperation is 5 or less
  bcs move_clemo_opposite                   ;we are far away so do the opposite to player
  jmp move_clemo_check_h                    ;we are close so see if we are also close in h

move_clemo_clemo_low_w:
  clc
  lda CHARACTER_CURRENT_W                   ;calculate horizontal seperation and then test
  sbc CLEMO_CURRENT_W
  cmp #CLEMO_CLOSENESS                      ;check if horizontal seperation is 5 or less
  bcs move_clemo_opposite                   ;we are far away so do the opposite to player
  jmp move_clemo_check_h                    ;we are close so see if we are also close in h

 move_clemo_check_h:;see how close we are - h check
  lda CHARACTER_CURRENT_H
  cmp CLEMO_CURRENT_H
  bcs move_clemo_clemo_low_h                ;clemo is above character - deal with that
  clc                                       ;Clemo is below character
  lda CLEMO_CURRENT_H                       ;calculate vertical seperation and then test
  sbc CHARACTER_CURRENT_H
  cmp #CLEMO_CLOSENESS                      ;check if vertical seperation is 5 or less
  bcs move_clemo_opposite                   ;we are far away so do the opposite to player
  jmp move_clemo_same                       ;we are close so do the same movement as player

move_clemo_clemo_low_h:
  clc
  lda CHARACTER_CURRENT_H                   ;calculate vertical seperation and then test
  sbc CLEMO_CURRENT_H
  cmp #CLEMO_CLOSENESS                      ;check if vertical seperation is 5 or less
  bcs move_clemo_opposite                   ;we are far away so do the opposite to player
  jmp move_clemo_same                       ;we are close so do the same movement as player

move_clemo_same:  
  ldx PLAYER_LAST_MOVE                      ;load player last move and test what direction it was
  beq move_clemo_1                          ;do the same as the player - when we are close
  dex
  beq move_clemo_2
  dex
  beq move_clemo_3
  jmp move_clemo_4

move_clemo_opposite:  
  ldx PLAYER_LAST_MOVE                      ;load player last move and test what direction it was
  beq move_clemo_2                          ;do the opposite of the player - when we are far away
  dex
  beq move_clemo_1
  dex
  beq move_clemo_4
  jmp move_clemo_3

move_clemo_1:;move Clemo left
  lda CLEMO_CURRENT_H
  sta CLEMO_NEXT_H
  lda CLEMO_CURRENT_W
  sta CLEMO_NEXT_W
  dec CLEMO_NEXT_W                          ;do twice as 2 bytes per column
  dec CLEMO_NEXT_W
  jmp move_clemo_test

move_clemo_2:;move Clemo right
  lda CLEMO_CURRENT_H
  sta CLEMO_NEXT_H
  lda CLEMO_CURRENT_W
  sta CLEMO_NEXT_W
  inc CLEMO_NEXT_W                          ;do twice as 2 bytes per column
  inc CLEMO_NEXT_W
  jmp move_clemo_test

move_clemo_3:;move Clemo up
  lda CLEMO_CURRENT_W
  sta CLEMO_NEXT_W
  lda CLEMO_CURRENT_H
  sta CLEMO_NEXT_H
  dec CLEMO_NEXT_H
  jmp move_clemo_test

move_clemo_4:;move Clemo down
  lda CLEMO_CURRENT_W
  sta CLEMO_NEXT_W
  lda CLEMO_CURRENT_H
  sta CLEMO_NEXT_H
  inc CLEMO_NEXT_H
  jmp move_clemo_test

move_clemo_test:
  lda CLEMO_NEXT_H                          ;a hack to reuse the character move routines...this is possible as character has already moved
  sta CHARACTER_NEXT_H
  lda CLEMO_NEXT_W
  sta CHARACTER_NEXT_W
  jsr Get_Tile_Number
  jsr Check_For_Wall                        ;check if the move is illegal because there is a wall
  lda NEXT_TILE_STATUS
  bne move_clemo_illegal_move               ;illegal move - return from routine

  ;legal move - so draw the move
  lda CLEMO_CURRENT_H                       ;Move cursor to current position to erase Clemo
  sta TFT_CURSOR_H_ROW
  lda CLEMO_CURRENT_W
  sta TFT_CURSOR_W_COL
  
  lda CHARACTER_CURRENT_H                   ;a hack so we can reuse the character move routines - restored after calling set_background_tile_offset
  sta TEMP_3
  lda CHARACTER_CURRENT_W
  sta TEMP_4
  lda CLEMO_CURRENT_H
  sta CHARACTER_CURRENT_H
  lda CLEMO_CURRENT_W
  sta CHARACTER_CURRENT_W
  jsr Set_Background_Tile_Offset            ;get byte offset to current background tile
  lda TEMP_3                                ;restore character position
  sta CHARACTER_CURRENT_H
  lda TEMP_4
  sta CHARACTER_CURRENT_W               
  lda BG_BYTE_OFFSET
  sta TFT_BYTE_OFFSET
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  
  lda CLEMO_NEXT_H                          ;Move cursor to next position to draw Clemo
  sta TFT_CURSOR_H_ROW
  sta CLEMO_CURRENT_H
  lda CLEMO_NEXT_W
  sta TFT_CURSOR_W_COL
  sta CLEMO_CURRENT_W

  lda #CLEMO_BYTE_OFFSET                    ;set byte offset to Clemo
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character

 move_clemo_illegal_move:  

  rts

Set_Forground_Background_Colour:;Function to set the foreground and background colour for the level tile number stored in TFT_BYTE_OFFSET

  lda TFT_BYTE_OFFSET
  sta TEMP_1                                ;store as temporary variable
  asl TEMP_1                                ;multiply by 2 by shifting left
  ldx TEMP_1                                ;store offset
  lda colour_table,x                        ;load relevant nibble
  sta TFT_PIXEL_COLOUR                      ;store foreground colour
  inx                                       ;move to next nibble  
  lda colour_table,x                        ;load relevant nibble
  sta TFT_PIXEL_COLOUR_BG                   ;store background colour

  rts

Game_Over:;function to display game won message
  
  ;reset to character map not level tile map!
  lda #TFT_CHAR_MAP_LSB                     ;load LSB of character map address 
  sta CURRENT_MAP_LSB
  lda #TFT_CHAR_MAP_MSB                     ;load MSB of character map address 
  sta CURRENT_MAP_MSB
  
  lda #TFT_CURSOR_H_NUM                     ;set cursor start position as specified in variables above
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  ;display the game won message
  lda #$14                                  ;store string length
  sta STRING_LENGTH
  lda #$14                                  ;store memory location of string - instruction string
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen 
  sei                                       ;lock screen - disable interupts

game_over_loop:
  jmp game_over_loop

  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Interupt Handlers - these sort out player movement and game play
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IRQ:

  sei                                       ;disable interupt till we have completed this function
  pha                                       ;store what was in a register to stack
  
  lda GAME_STARTED                          ;see if we need to spawn player/Clemo
  beq spawn_get_location                    ;if zero then we need to spawn players
  jmp check_buttons                         ;we have already spawned players and want to move

spawn_get_location:
  lda #$00                                  ;set MSB - always zero for player
  sta TILE_NUMBER_MSB
  tya                                       ;get the 'random' number from y register
  sta CLEMO_RND   
  txa                                       ;get the 'random' number from x register
  sta PLAYER_RND
  sta TILE_NUMBER_LSB                       ;store as tile number
  sbc #$d1                                  ;make sure we aren't above the maximum number
  bpl spawn_try_again                       ;not negative so we can try to spawn
 
 spawn_reset_to_zero:
  lda #$79                                  ;actually not to zero - by the front door like we just walked in!  
  sta TILE_NUMBER_LSB                       ;number was too high so start from the begining.

spawn_try_again:
  jsr Check_For_Wall                        ;check if the proposed tile is a wall
  lda NEXT_TILE_STATUS
  beq spawn_player                          ;if tile is a not a wall
  inc TILE_NUMBER_LSB                       ;move to next tile
  lda TILE_NUMBER_LSB
  sbc #$d1                                  ;make sure we aren't above the maximum number
  bmi spawn_reset_to_zero                   ;we are so reset to zero
  jmp spawn_try_again                       ;repeat what we have just done...

spawn_player:
  lda #$00                                  ;a hacky way to get player coordinates - move the cursor the tile_number_lsb number of spaces
  sta TFT_CURSOR_W_COL
  lda #$01
  sta TFT_CURSOR_H_ROW                      ;put the cursor to 0,1

spawn_get_player_coords:
  lda TILE_NUMBER_LSB                       ;see if we are ready to draw player
  beq spawn_draw_player
  jsr TFT_Next_Char                         ;move cursor on one
  dec TILE_NUMBER_LSB                       ;decrease counter by one
  jmp spawn_get_player_coords               ;repeat what we have just done!

spawn_draw_player:
  ;set player location
  lda TFT_CURSOR_W_COL
  sta CHARACTER_CURRENT_W
  lda TFT_CURSOR_H_ROW
  sta CHARACTER_CURRENT_H

  lda #PLAYER_BYTE_OFFSET                   ;set byte offset to player character
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character

  lda CLEMO_RND                             ;repeat what we did but for Clemo
  sta TILE_NUMBER_LSB                       ;store as tile number
  sbc #$d1                                  ;make sure we aren't above the maximum number
  bpl spawn_try_again_c                     ;not negative so we can try to spawn
 
 spawn_reset_to_zero_c:
  lda #$ff                                  ;actually not to zero - in the conservatory
  sta TILE_NUMBER_LSB                       ;number was too high so start from the begining.

spawn_try_again_c:
  jsr Check_For_Wall                        ;check if the proposed tile is a wall
  lda NEXT_TILE_STATUS
  beq spawn_clemo                           ;if tile is a not a wall
  inc TILE_NUMBER_LSB                       ;move to next tile
  lda TILE_NUMBER_LSB
  sbc #$d1                                  ;make sure we aren't above the maximum number
  bmi spawn_reset_to_zero_c                 ;we are so reset to zero
  jmp spawn_try_again_c                     ;repeat what we have just done...

spawn_clemo:
  lda #$00                                  ;a hacky way to get clemo coordinates - move the cursor the tile_number_lsb number of spaces
  sta TFT_CURSOR_W_COL
  lda #$01
  sta TFT_CURSOR_H_ROW                      ;put the cursor to 0,1

spawn_get_clemo_coords:
  lda TILE_NUMBER_LSB                       ;see if we are ready to draw player
  beq spawn_draw_clemo
  jsr TFT_Next_Char                         ;move cursor on one
  dec TILE_NUMBER_LSB                       ;decrease counter by one
  jmp spawn_get_clemo_coords                ;repeat what we have just done!

spawn_draw_clemo:

  ;set start location - Clemo
  lda TFT_CURSOR_W_COL
  sta CLEMO_CURRENT_W
  lda TFT_CURSOR_H_ROW
  sta CLEMO_CURRENT_H

  lda #CLEMO_BYTE_OFFSET                    ;set byte offset to Clemo
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character

  ;reset to character map not level tile map!
  lda #TFT_CHAR_MAP_LSB                     ;load LSB of character map address 
  sta CURRENT_MAP_LSB
  lda #TFT_CHAR_MAP_MSB                     ;load MSB of character map address 
  sta CURRENT_MAP_MSB
  
  lda #TFT_CURSOR_H_NUM                     ;set cursor start position as specified in variables above
  sta TFT_CURSOR_H_ROW
  lda #TFT_CURSOR_W_NUM
  sta TFT_CURSOR_W_COL

  lda #$02                                  ;set foreground pixel colour to white
  sta TFT_PIXEL_COLOUR
  lda #0                                    ;set background pixel colour to black
  sta TFT_PIXEL_COLOUR_BG

  ;display the instruction
  lda #$14                                  ;store string length
  sta STRING_LENGTH
  lda #$00                                  ;store memory location of string - instruction string
  sta STRING_LSB
  lda #$a0
  sta STRING_MSB
  jsr TFT_Print_String                      ;print the string to the screen 

  ;reset to level map
  lda #TILE_MAP_LSB                         ;load LSB of tile map address and set to current character map address 
  sta CURRENT_MAP_LSB
  lda #TILE_MAP_MSB                         ;load MSB of tile map address and set to current character map address 
  sta CURRENT_MAP_MSB

  lda #$01                                  ;characters spawned
  sta GAME_STARTED
  jmp irq_return 

 check_buttons:

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
  
  jmp irq_button_A_move                     ;this bit is required as beq only allows a jump of +/- 127 bytes

irq_button_B:

  jmp irq_button_B_move                     ;this bit is required as beq only allows a jump of +/- 127 bytes

irq_button_C:

  jmp irq_button_C_move                     ;this bit is required as beq only allows a jump of +/- 127 bytes

irq_button_D:

  jmp irq_button_D_move                     ;this bit is required as beq only allows a jump of +/- 127 bytes

irq_button_A_move:
  
  ;move player left
  lda CHARACTER_CURRENT_W                   ;move cursor to where character is
  sta TFT_CURSOR_W_COL
  lda CHARACTER_CURRENT_H
  sta TFT_CURSOR_H_ROW

  ;check for legal move or game end
  lda CHARACTER_CURRENT_W                   ;work out the space we are proposing to move to
  sta CHARACTER_NEXT_W
  dec CHARACTER_NEXT_W
  dec CHARACTER_NEXT_W
  lda CHARACTER_CURRENT_H
  sta CHARACTER_NEXT_H
  jsr Get_Tile_Number                       ;set LSB and MSB for the tile we are interested in

  jsr Check_For_Wall                        ;check if the move is illegal because there is a wall
  lda NEXT_TILE_STATUS
  bne illegal_move_A                        ;illegal move - return from routine
  jsr Check_For_Clemo                       ;see if tile is Clemo
  lda NEXT_TILE_STATUS
  bne game_over_A                           ;Game Over - display message
  jmp legal_move_A                          ;legal move 

  ;illegal move
illegal_move_A:
  jmp irq_return

  ;Clemo has been found, game over!
game_over_A:
  jsr Game_Over

legal_move_A:
  ;legal move - so draw the move
  ;lda #BACKGROUND_BYTE_OFFSET               ;set byte offset to background
  jsr Set_Background_Tile_Offset            ;get byte offset to current background tile
  lda BG_BYTE_OFFSET
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  
  dec CHARACTER_CURRENT_W                   ;move cursor to next space - also update character location indicator
  dec CHARACTER_CURRENT_W                   ;move cursor to next space - need to do twice as W columns are even numbers due to words in look up total
  lda CHARACTER_CURRENT_W
  sta TFT_CURSOR_W_COL

  lda #PLAYER_BYTE_OFFSET                   ;set byte offset to player character
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  lda #$00                                  ;store player last move
  sta PLAYER_LAST_MOVE
  jsr Move_Clemo                            ;move Clemo

  jmp irq_return

irq_button_B_move:
  
  ;move player right
  lda CHARACTER_CURRENT_W                   ;move cursor to where character is
  sta TFT_CURSOR_W_COL
  lda CHARACTER_CURRENT_H
  sta TFT_CURSOR_H_ROW
  
  ;check for legal move or game end
  lda CHARACTER_CURRENT_W                   ;work out the space we are proposing to move to
  sta CHARACTER_NEXT_W
  inc CHARACTER_NEXT_W
  inc CHARACTER_NEXT_W
  lda CHARACTER_CURRENT_H
  sta CHARACTER_NEXT_H
  jsr Get_Tile_Number                       ;set LSB and MSB for the tile we are interested in

  jsr Check_For_Wall                        ;check if the move is illegal because there is a wall
  lda NEXT_TILE_STATUS
  bne illegal_move_B                        ;illegal move - return from routine
  jsr Check_For_Clemo                       ;see if tile is Clemo
  lda NEXT_TILE_STATUS
  bne game_over_B                           ;Game Over - display message
  jmp legal_move_B                          ;legal move 

  ;illegal move
illegal_move_B:
  jmp irq_return

  ;Clemo has been found, game over!
game_over_B:
  jsr Game_Over

legal_move_B:
  ;legal move - so draw the move
  ;lda #BACKGROUND_BYTE_OFFSET               ;set byte offset to background
  jsr Set_Background_Tile_Offset            ;get byte offset to current background tile
  lda BG_BYTE_OFFSET
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  

  inc CHARACTER_CURRENT_W                   ;move cursor to next space - also update character location indicator
  inc CHARACTER_CURRENT_W                   ;move cursor to next space - need to do twice as W columns are even numbers due to words in look up total
  lda CHARACTER_CURRENT_W
  sta TFT_CURSOR_W_COL

  lda #PLAYER_BYTE_OFFSET                   ;set byte offset to player character
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  lda #$01                                  ;store player last move
  sta PLAYER_LAST_MOVE
  jsr Move_Clemo                            ;move Clemo

  jmp irq_return

irq_button_C_move:
  
  ;move player up
  lda CHARACTER_CURRENT_W                   ;move cursor to where character is
  sta TFT_CURSOR_W_COL
  lda CHARACTER_CURRENT_H
  sta TFT_CURSOR_H_ROW

  ;check for legal move or game end
  lda CHARACTER_CURRENT_H                   ;work out the space we are proposing to move to
  sta CHARACTER_NEXT_H
  dec CHARACTER_NEXT_H
  lda CHARACTER_CURRENT_W
  sta CHARACTER_NEXT_W
  jsr Get_Tile_Number                       ;set LSB and MSB for the tile we are interested in

  jsr Check_For_Wall                        ;check if the move is illegal because there is a wall
  lda NEXT_TILE_STATUS
  bne illegal_move_C                        ;illegal move - return from routine
  jsr Check_For_Clemo                       ;see if tile is Clemo
  lda NEXT_TILE_STATUS
  bne game_over_C                           ;Game Over - display message
  jmp legal_move_C                          ;legal move 

  ;illegal move
illegal_move_C:
  jmp irq_return

  ;Clemo has been found, game over!
game_over_C:
  jsr Game_Over

legal_move_C:
  ;legal move - so draw the move
  ;lda #BACKGROUND_BYTE_OFFSET               ;set byte offset to background
  jsr Set_Background_Tile_Offset            ;get byte offset to current background tile
  lda BG_BYTE_OFFSET
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  

  dec CHARACTER_CURRENT_H                   ;move cursor to next space - also update character location indicator
  lda CHARACTER_CURRENT_H
  sta TFT_CURSOR_H_ROW

  lda #PLAYER_BYTE_OFFSET                   ;set byte offset to player character
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  lda #$02                                  ;store player last move
  sta PLAYER_LAST_MOVE
  jsr Move_Clemo                            ;move Clemo

  jmp irq_return

irq_button_D_move:
  
  ;move player down
  lda CHARACTER_CURRENT_W                   ;move cursor to where character is
  sta TFT_CURSOR_W_COL
  lda CHARACTER_CURRENT_H
  sta TFT_CURSOR_H_ROW
  
  ;check for legal move or game end
  lda CHARACTER_CURRENT_H                   ;work out the space we are proposing to move to
  sta CHARACTER_NEXT_H
  inc CHARACTER_NEXT_H
  lda CHARACTER_CURRENT_W
  sta CHARACTER_NEXT_W
  jsr Get_Tile_Number                       ;set LSB and MSB for the tile we are interested in

  jsr Check_For_Wall                        ;check if the move is illegal because there is a wall
  lda NEXT_TILE_STATUS
  bne illegal_move_D                        ;illegal move - return from routine
  jsr Check_For_Clemo                       ;see if tile is Clemo
  lda NEXT_TILE_STATUS
  bne game_over_D                           ;Game Over - display message
  jmp legal_move_D                          ;legal move 

  ;illegal move
illegal_move_D:
  jmp irq_return

  ;Clemo has been found, game over!
game_over_D:
  jsr Game_Over

legal_move_D:
  ;legal move - so draw the move
  ;lda #BACKGROUND_BYTE_OFFSET               ;set byte offset to background
  jsr Set_Background_Tile_Offset            ;get byte offset to current background tile
  lda BG_BYTE_OFFSET
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  
  inc CHARACTER_CURRENT_H                   ;move cursor to next space - also update character location indicator
  lda CHARACTER_CURRENT_H
  sta TFT_CURSOR_H_ROW

  lda #PLAYER_BYTE_OFFSET                   ;set byte offset to player character
  sta TFT_BYTE_OFFSET
  jsr Set_Forground_Background_Colour       ;set foreground and background colour
  jsr TFT_Draw_Char                         ;draw character
  lda #$03                                  ;store player last move
  sta PLAYER_LAST_MOVE
  jsr Move_Clemo                            ;move Clemo

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

  ;need to pause 120ms as per datasheet
  ldy #$78              ;run 120 times $78 - results in just over 120ms
delay:
  jsr Delay_ms
  dey
  bne delay
  
  lda #$29              ;display on
  jsr TFT_Write_Com
  lda #$2c              ;memory write
  jsr TFT_Write_Com

  rts

TFT_Clear:;Function to set the screen a specific colour - use TFT_Fill_Data for black as it is faster
  
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
  jsr Get_Cursor_H_Coordinate       ;get h and w coordinates from the column and row addresses
  jsr Get_Cursor_W_Coordinate

  lda TFT_CURSOR_H                  ;set cursor y
  clc                               ;work out top right, clear carry - note assuming left hand side of screen for noW
  adc #TFT_CHAR_H                   ;add height of character - will always be less than 255
  sta TFT_CURSOR_H_END              ;store result

  lda TFT_CURSOR_W                  ;set cursor x
  clc                               ;work out top right, clear carry - note assuming left hand side of screen for noW
  adc #TFT_CHAR_W                   ;add width of character
  bcs second_page                   ;detect when we are drawing column 16 which starts on page 1 and finishes on page 2 of screen! - not the best way of doing this but a fudge for now
  sta TFT_CURSOR_W_END              ;store result
  jmp set_address

second_page:
  sta TFT_CURSOR_W_END              ;this code is necessary to fix a bug with drawing column 16
  lda #01
  sta TFT_CURSOR_W_MSB_END

set_address:
  inc TFT_CURSOR_H                  ;carry on with the rest of the code
  inc TFT_CURSOR_W
  
  lda #$2a                          ;Column address set - note screen turned on its side so x is y and vice versa!
  jsr TFT_Write_Com
  lda #0                            ;write x1
  jsr TFT_Write_Data
  lda TFT_CURSOR_H
  jsr TFT_Write_Data
  lda #0                            ;write x2 MSB first then LSB
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

TFT_Fill_Data:;Function to fill the screen with one specific colour for faster clearing / drawing rectangles

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

  ldx TFT_PIXEL_COLOUR              ;store colour for first pixel
  lda black,x 
  jsr TFT_Write_Data
  inx
  lda black,x
  jsr TFT_Write_Data
  
  ;write the rest of the screen
  lda #$02                          ;set number of halves of screen (2)
  sta TFT_HALF_COUNTER
fill_half_screen:
  ldx #TFT_WIDTH_DIV                ;load dimension of half of screen width into memory
fill_one_w:
  ldy #TFT_HEIGHT                   ;load dimension of height into register
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
  dey                               ;decrement counter
  bne fill_one_h                    ;if not at end of column - loop back and draw another pixel
  dex                               ;decrement counter
  bne fill_one_w                    ;if not at end of width segment - loop back and draw another column
  dec TFT_HALF_COUNTER
  bne fill_half_screen              ;if not drawn second half of screen - loop back and draw another half

  rts

Delay_ms:;Function to delay for 1ms 
  
  ;delay for 1ms
  ldx #$3b                          ;1ms delay $3b - 59 times
delay_ms_loop:
  nop                               ;nops for delay, this isn't the best way, will tidy later
  nop
  nop
  nop
  nop
  nop
  dex                               ;decrement x register - 2 cycles
  bne delay_ms_loop                 ;2 cycles, 3 cycles if looping
  rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Screen Constants and Character Map - $b000-bfff (4k)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  .org $b000
  
char_map:
  ;memory address b000 - note if you move this you need to change the variables at the top of the code, TFT_CHAR_MAP_MSB & TFT_CHAR_MAP_LSB
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