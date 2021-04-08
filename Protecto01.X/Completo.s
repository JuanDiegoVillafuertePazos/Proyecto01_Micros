;Archivo:		Completo.S
;Dispositivo:		PIC16F887
;Autor;			Juan Diego Villafuerte Pazos
;Compilador:		pic-as (v2.31) MPLABX V5.40
;
;Programa:		Leds en el puerto A, display 7 segmentos en el puerto C, 
;			multiplexion en el puerto D, botones e indicadores en el
;			puerto B
; 
;Creado:		20 de marzo, 2021
;Ultima modificacion:	6 de marzo, 2021
    
PROCESSOR 16F887
#include <xc.inc>

;CONFIGURATION WORD 1
CONFIG FOSC=INTRC_NOCLKOUT  ;Oscilador interno sin salida
CONFIG WDTE=OFF             ;Reinicio repetitivo del pic
CONFIG PWRTE=ON             ;espera de 72 ms al iniciar el pic
CONFIG MCLRE=OFF            ;El pin MCLR se utiliza como entrada/salida
CONFIG CP=OFF               ;Sin protección de código
CONFIG CPD=OFF              ;Sin protección de datos
    
CONFIG BOREN=OFF            ;Sin reinicio cuando el input voltage inferior a 4V
CONFIG IESO=OFF             ;Reinicio sin cambio de reloj de interno a externo
CONFIG FCMEN=OFF            ;Cambio de reloj externo a interno en caso de fallas
CONFIG LVP=ON               ;Programación en low voltage permitida
    
;CONFIGURATION WORD 2
CONFIG WRT=OFF              ;Proteccion autoescritura por programa desactivada
CONFIG BOR4V=BOR40V         ;Reinicio abajo de 4V 
    
;variables
    
PSECT udata_bank0           ;variable para:
    banderas:	    DS 1      
    banderas2:      DS 1 
        
    aceptarvar:  DS 1
    titilar:	 DS 1
    ressem:	 DS 1
    delay_big:   DS 1
    delay_small: DS 1
    
    botonestados:    DS 1
    estado:    DS 1
    semaforo:    DS 1
    
    numerador:   DS 1       ;division
    decenas: DS 1     
    registro: DS 1
        
    ;numconfig:   DS 1
    dispconfig1: DS 1
    dispconfig2: DS 1
    
    numsem1:    DS 1
    dispsem1_1: DS 1
    dispsem1_2: DS 1
    config1_1:  DS 1
    config1_2:  DS 1
    verde1:     DS 1
    verde1pas:  DS 1
    rojo1:	DS 1
    guardado1: DS 1
    
    numsem2:	DS 1
    dispsem2_1: DS 1
    dispsem2_2: DS 1
    config2_1:  DS 1
    config2_2:  DS 1
    verde2:	DS 1
    verde2pas:  DS 1
    rojo2:	DS 1
    guardado2: DS 1

    numsem3:	DS 1
    dispsem3_1: DS 1
    dispsem3_2: DS 1
    config3_1:	DS 1
    config3_2:	DS 1
    verde3:	DS 1
    verde3pas:  DS 1
    rojo3:	DS 1
    guardado3: DS 1

PSECT udata_shr ;memoria compartida
    w_temp:    DS 1; variable para guardar w temporalmente
    s_temp:    DS 1; variable para guardar status temporalmente
    sevseg:    DS 1; Variable para el 7 seg del contador
    
;instrucciones vector reset
PSECT resVect, class=CODE, abs, delta=2
    
;vector reset
ORG 00h
resetVec:
    PAGESEL main
    goto main
    
;vector de interrupciones
PSECT intVect, class = CODE, abs, delta = 2
ORG 04h
push:
    movwf w_temp    ;guardar w en una variable temporal
    swapf STATUS, w
    movwf s_temp

isr:
    btfsc RBIF      ;chequear la bandera de la interrupcion por cambio
    call  int_ocb   ;llama a la subrutina del boton
    
    btfsc T0IF      ;chequear la bandera de interrupcion del tmr0 
    call  int_tmr0  ;llama a la subrutina del tmr0
    
    btfsc TMR1IF    ;chequear la bandera de interrupcion del tmr1
    call  int_tmr1
    
    btfsc PIR1,1    ;Para revisar la interrupcion de timer2
    call int_tmr2

pop:
    swapf s_temp, w  ;regresar el w temporal a w 
    movwf STATUS     ;y regresar status temporal a status
    swapf w_temp, f
    swapf w_temp, w
    retfie

;configuracion del micro 
PSECT code, delta=2, abs
ORG 100h
 
tabla: 
    clrf    PCLATH
    bsf     PCLATH, 0   
    andlw   0x0F	;se borra la primer mitad para usar solamente la segunda
    addwf   PCL        
    
    retlw   00111111B	;0
    retlw   00000110B	;1
    retlw   01011011B	;2
    retlw   01001111B	;3
    retlw   01100110B	;4
    retlw   01101101B	;5
    retlw   01111101B	;6
    retlw   00000111B	;7
    retlw   01111111B	;8
    retlw   01101111B	;9
    retlw   01110111B	;A
    retlw   01111100B	;b
    retlw   00111001B	;C
    retlw   01011110B	;d
    retlw   01111001B	;E
    retlw   01110001B	;F 

main:
    call    config_reloj ;se configura el reloj
    call    config_io    ;seleccionar in/ou
    call    config_iocb  ;configuracion del interrupt por cambio
    call    config_inten ;se configura el interrupciones
    call    config_tmr0  ;configuracion tmr0
    call    config_tmr1  ;configuracion tmr1
    call    config_tmr2  ;configuracion tmr2
    
    
    bsf     banderas, 0  ;inicializar primer display
    bsf	    banderas2,0	 ;inicializar secuencia de reset semaforo   
    
    movlw   10
    movwf   numsem1
    movwf   numsem2
    movwf   numsem3
    ;movwf   semaforo
    

;loop principal
loop:
    
    bcf STATUS,2
    movlw 0
    subwf semaforo,w
    btfss STATUS,2
    goto $+2
    bsf ressem,0	;inicializar secuencia de reset semaforo
    
    call modos
    
    btfsc   botonestados, 0
    call    selestado
    btfsc   botonestados, 1
    call    subir
    btfsc   botonestados, 2
    call    bajar
    
    call rojos
    call amarillos
    ;call verdes
    
    movf numsem1,w	  ;para cargar los valores del semaforo1
    call division
    movf  decenas, w  ;cargar decenas
    call  tabla           
    movwf dispsem1_1         
    movf  numerador, w    ;cargar unidades
    call  tabla           
    movwf dispsem1_2
    
    movf numsem2,w	  ;para cargar los valores del semaforo2
    call division
    movf  decenas, w  ;cargar decenas
    call  tabla           
    movwf dispsem2_1         
    movf  numerador, w    ;cargar unidades
    call  tabla           
    movwf dispsem2_2
    
    movf numsem3,w	  ;para cargar los valores del semaforo3  
    call division
    movf  decenas, w  ;cargar decenas
    call  tabla           
    movwf dispsem3_1         
    movf  numerador, w    ;cargar unidades
    call  tabla           
    movwf dispsem3_2
    
    goto    loop
    
;subrutinas de interrupcion
 
int_ocb:
    banksel PORTB
    btfss   PORTB, 0
    bsf     botonestados, 0
    btfss   PORTB, 1
    bsf     botonestados, 1
    btfss   PORTB, 2
    bsf     botonestados, 2
    bcf     RBIF
    return
    
int_tmr0:
    banksel PORTA     
    call  rst_tmr0   ;se resetea el tmr0
    clrf  PORTD      ;se limpia el puerto D
    
    btfsc banderas, 0;chequeo de banderas para alternar displays
    goto display0    
    btfsc banderas, 1
    goto display1
    btfsc banderas, 2
    goto display2
    btfsc banderas, 3
    goto display3
    btfsc banderas, 4
    goto display4
    btfsc banderas, 5
    goto display5
    btfsc banderas, 6
    goto display6
    btfsc banderas, 7
    goto display7

display0:
    movf  dispconfig1, w	    ;cargar el valor al display
    movwf PORTC
    bsf   PORTD, 0          ;encender el eneable del display 
    bcf   banderas, 0       ;alternacion entre los displays
    bsf   banderas, 1       
    return
    
display1:
    movf  dispconfig2, w    
    movwf PORTC
    bsf   PORTD, 1         
    bcf   banderas, 1
    bsf   banderas, 2
    return
    
display2:
    movf  dispsem1_1, w        
    movwf PORTC             
    bsf   PORTD, 2
    bcf   banderas, 2       
    bsf   banderas, 3
    return
    
display3:
    movf  dispsem1_2, w        
    movwf PORTC
    bsf   PORTD, 3
    bcf   banderas, 3       
    bsf   banderas, 4
    return

display4:
    movf  dispsem2_1, w        
    movwf PORTC
    bsf   PORTD, 4
    bcf   banderas, 4       
    bsf   banderas, 5
    return

display5:
    movf  dispsem2_2, w        
    movwf PORTC
    bsf   PORTD, 5
    bcf   banderas, 5       
    bsf   banderas, 6
    return

display6:
    movf  dispsem3_1, w        
    movwf PORTC
    bsf   PORTD, 6
    bcf   banderas, 6       
    bsf   banderas, 7
    return

display7:
    movf  dispsem3_2, w        
    movwf PORTC
    bsf   PORTD, 7
    bcf   banderas, 7       
    bsf   banderas, 0
    return

int_tmr1:
    banksel PORTA
    call    rst_tmr1	   ;reseteo del tmr1
    
    decf numsem1

    bcf STATUS,2
    movlw 255
    subwf numsem1,w
    btfss STATUS,2
    goto $+3
   
    movlw 10
    movwf numsem1
    decf numsem2

    bcf STATUS,2
    movlw 255
    subwf numsem2,w
    btfss STATUS,2
    goto $+3
    
    movlw 10
    movwf numsem2
    decf numsem3
    
    bcf STATUS,2
    movlw 255
    subwf numsem3,w
    btfss STATUS,2
    goto $+3
    
    movlw 10
    movwf numsem3
    
    return

int_tmr2:
    bcf PIR1,1
    
    btfss aceptarvar,2
    goto $+7
    incf titilar
    btfss titilar,0
    bsf PORTA,0
    btfsc titilar,0
    bcf PORTA,0
    return
    
    btfss aceptarvar,3
    goto $+7
    incf titilar
    btfss titilar,0
    bsf PORTA,1
    btfsc titilar,0
    bcf PORTA,1
    return
    
    btfss aceptarvar,4
    goto $+7
    incf titilar
    btfss titilar,0
    bsf PORTA,2
    btfsc titilar,0
    bcf PORTA,2
    return
    return
    
;subrutinas

rojos:
    
    movf guardado2,w
    addwf guardado3,w
    movwf rojo1
    
    movf guardado1,w
    addwf guardado3,w
    movwf rojo2
    
    movf guardado1,w
    addwf guardado2,w
    movwf rojo3
    
    return
    
selestado:
    banksel PORTA
    incf    estado
    
    bcf     STATUS, 2
    movlw   5           
    subwf   estado, w
    btfss   STATUS, 2	
    goto    $+3   
    movlw   0   	
    movwf   estado
    bcf     botonestados, 0
    return

subir: 
    banksel PORTA
    incf    semaforo
    bcf     STATUS, 2
    movlw   21             
    subwf   semaforo , w   
    btfss   STATUS, 2	   
    goto    $+3   
    movlw   10   	   
    movwf   semaforo
    bcf     botonestados, 1   
    
    return
 
bajar: 
    banksel PORTA
    decf    semaforo
    bcf     STATUS, 2
    movlw   9              
    subwf   semaforo , w   
    btfss   STATUS, 2	   
    goto    $+3   
    movlw   20   	   
    movwf   semaforo
    bcf     botonestados, 2
   
    return
    
division:   
    clrf    decenas  ;limpiar varibles para division para el tercer sem
    clrf    numerador
    bcf   STATUS, 0       ;limpiar carry
    ;movf  semaforo, w     
    movwf numerador       
    movlw 10              ;chequear decenas
    incf  decenas     
    subwf numerador, f    
    btfsc STATUS, 0       
    goto  $-3             
    decf  decenas     
    addwf numerador       
   
    return

modogeneral:
    call division
    movwf registro
    movf  decenas, w  ;cargar decenas
    call  tabla           
    movwf dispconfig1       
    
    movf  numerador, w    ;cargar unidades
    call  tabla           
    movwf dispconfig2
    
    return
    
modo0:
    clrf dispconfig1
    clrf dispconfig2
    bcf PORTB,5
    bcf PORTB,6
    bcf PORTB,7
    return
    
modo1:
    
    movf guardado1,w
    movwf verde1pas
    
    btfss ressem,0
    goto $+4
    movlw 15
    movwf semaforo
    bcf ressem,0
    bsf ressem,1
    
    bsf PORTB,5
    bcf PORTB,6   
    bcf PORTB,7
    
    movf semaforo,w
    movwf verde1  
    movwf guardado1
    call modogeneral
    
    return
    
modo2:
    
    movf guardado2,w
    movwf verde2pas
    
    btfss ressem,1
    goto $+4
    movlw 15
    movwf semaforo
    bcf ressem,1
    bsf ressem,2
    
    bcf PORTB,5
    bsf PORTB,6   
    bcf PORTB,7 
    
    movf semaforo,w
    movwf verde2
    movwf guardado2
    call modogeneral
    
    return
    
modo3:
    
    movf guardado3,w
    movwf verde3pas
    
    btfss ressem,2
    goto $+4
    movlw 15
    movwf semaforo
    bcf ressem,2
    bsf ressem,0
    
    bcf PORTB,5
    bcf PORTB,6   
    bsf PORTB,7
    
    movf semaforo,w
    movwf verde3
    movwf guardado3
    call modogeneral 
    
    return
    
modo4:
    bsf PORTB,5
    bsf PORTB,6   
    bsf PORTB,7
    
    movlw 1000000B	
    movwf dispconfig1
    movwf dispconfig2
    
    btfsc botonestados,1
    call aceptar
    btfsc botonestados,2
    call cancelar
    
    bcf PORTA,0
    bcf PORTA,1
    bcf PORTA,2
    bcf PORTA,3
    bcf PORTA,4
    bcf PORTA,5
    bcf PORTA,6
    bcf PORTA,7
    bcf PORTB,3
     
    return   

aceptar:
    call resetsem
    
    movf guardado1,w
    movwf numsem1
    movf guardado2,w
    movwf numsem2
    movf guardado3,w
    movwf numsem3
    
    clrf estado
    return
    
cancelar:
    call resetsem
    
    movf verde1pas,w
    movwf numsem1
    movf verde2pas,w
    movwf numsem2
    movf verde3pas,w
    movwf numsem3

    clrf estado
    return

resetsem:
      
    bsf PORTA,6
    bsf PORTA,7
    bsf PORTB,3
    
    movlw 1000000B 
    movwf dispsem1_1
    movwf dispsem1_2
    movwf dispsem2_1
    movwf dispsem2_2
    movwf dispsem3_1
    movwf dispsem3_2
    
    movlw   255
    movwf   delay_big
    call    d_small
    decfsz  delay_big, 1
    goto    $-2
    return
    
d_small:
    movlw   255
    movwf   delay_small
    decfsz  delay_small, 1
    goto    $-1
    return
    
modos:
    banksel PORTA
    bcf     STATUS, 2
    movlw   0
    subwf   estado , w   
    btfsc   STATUS, 2	   
    call modo0   	   
    
    bcf     STATUS, 2
    movlw   1
    subwf   estado , w   
    btfsc   STATUS, 2	   
    call modo1
    
    bcf     STATUS, 2
    movlw   2
    subwf   estado , w   
    btfsc   STATUS, 2	   
    call modo2
    
    bcf     STATUS, 2
    movlw   3
    subwf   estado , w   
    btfsc   STATUS, 2	   
    call modo3
    
    bcf     STATUS, 2
    movlw   4
    subwf   estado , w   
    btfsc   STATUS, 2	   
    call modo4
    
    return

amarillos:
    bcf STATUS,2    ;para el led verde titilante semaforo1
    movlw 7
    subwf numsem1,w
    btfss STATUS,2
    goto $+4
    bsf aceptarvar,2
    bsf PORTA,0
    bcf PORTA,3
    
    bcf STATUS,2    ;para el led amarillo semaforo1
    movlw 3
    subwf numsem1,w
    btfss STATUS,2
    goto $+4
    bcf aceptarvar,2
    bcf PORTA,0
    bsf PORTA,3
    
    bcf STATUS,2    ;para el led verde titilante semaforo2
    movlw 7
    subwf numsem2,w
    btfss STATUS,2
    goto $+4
    bsf aceptarvar,3
    bsf PORTA,1
    bcf PORTA,4
    
    bcf STATUS,2    ;para el led amarillo semaforo2
    movlw 3
    subwf numsem2,w
    btfss STATUS,2
    goto $+4
    bcf aceptarvar,3
    bcf PORTA,1
    bsf PORTA,4
    
    bcf STATUS,2    ;para el led verde titilante semaforo3
    movlw 7
    subwf numsem3,w
    btfss STATUS,2
    goto $+4
    bsf aceptarvar,4
    bsf PORTA,2
    bcf PORTA,5
    
    bcf STATUS,2    ;para el led amarillo semaforo3
    movlw 3
    subwf numsem3,w
    btfss STATUS,2
    goto $+4
    bcf aceptarvar,4
    bcf PORTA,2
    bsf PORTA,5
    return
    
config_reloj:
    banksel OSCCON
    bsf     IRCF2 ; 001, Frecuencia de 1MHz
    bcf     IRCF1
    bcf     IRCF0
    bsf     SCS   ; reloj interno
    return

config_io: 
    banksel ANSELH ;selecciona el banco donde se encuentra la seleccion  
    clrf    ANSELH ;de pines digitales 
    clrf    ANSEL  
    
    banksel TRISB  ;configuracion de entradas 
    clrf TRISB
    bsf TRISB,0
    bsf TRISB,1
    bsf TRISB,2
    
    clrf    TRISA  ;configuracion de salidas 
    clrf    TRISC  
    clrf    TRISD 
    
    bcf     OPTION_REG, 7 ;habilitar los pull ups
    bsf     WPUB, 0 ;habilitar los pullups en RB0 y RB1 como inputs
    bsf     WPUB, 1
    bsf     WPUB, 2
    
    banksel PORTB  
    clrf    PORTA  ;borrar puertos A,B,C y D 
    clrf    PORTB
    clrf    PORTC  
    clrf    PORTD
    return

config_iocb:
    banksel TRISA    
    bsf     IOCB, 0  ;interrupt on change para reaccionar con los pb
    bsf     IOCB, 1
    bsf     IOCB, 2
    banksel PORTA
    movf    PORTB, w 
    bcf     RBIF     ;borrar bandera
    return
    
config_tmr0:
    banksel TRISA 
    bcf     T0CS  ; reloj interno
    bcf     PSA   ; prescaler
    bcf     PS2   ; 001, que es 1:4
    bcf     PS1
    bsf     PS0
    banksel PORTA 
    call    rst_tmr0; se resetea el timer0
    return

config_tmr1:
    banksel T1CON
    bsf     T1CKPS1 ;Prescaler de 1:4
    bcf     T1CKPS0 ;10
    bcf     TMR1CS  ;Reloj interno
    bsf     TMR1ON  ;timer1 habilitado
    call    rst_tmr1
    return    
    
config_tmr2:
    banksel T2CON
    bsf T2CON,1	    ;Para cargar el prescalar de 1:16
    bsf T2CON,2	    ;Para encender el Timer2
    
    bsf T2CON,3	    ;Para cargar el postscaler de 1:16
    bsf T2CON,4
    bsf T2CON,5
    bsf T2CON,6
    
    banksel TRISC
    bsf PIE1,1
    movlw 244	   ;Cargar el valor para el PR2 de 244
    movwf PR2
    
    return
    
rst_tmr0:
    movlw 125     
    movwf TMR0    
    bcf   T0IF    ;borrar bandera del tmr0
    return

rst_tmr1:
    banksel PIR1
    movlw   11011100B
    movwf   TMR1L
    movlw   1011B
    movwf   TMR1H
    bcf     TMR1IF
    return
    
config_inten:
    bsf     GIE    ;enable global de interrupts
    bsf     RBIE   ;interrupt por cambion habilitado
    bcf     RBIF   
    bsf     T0IE   ;habilita interrupt de overflow del tmr0
    bcf     TMR1IF 
    bsf     TMR1IE ;habilita la interrupcion del overflow del tmr1
    bsf     PEIE   
    return
    
END