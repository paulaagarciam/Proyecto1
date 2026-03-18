;
; proyecto1.asm
;
; Created: 4/03/2026 16:54:46
; Author : paula
;

.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.equ t1 = 0xC2F7
.equ modes = 5
.def segs = R18
.def mins_unidades = R19
.def mins_decenas = R20
.def hrs_unidades = R21
.def hrs_decenas = R22
.def dia_unidades = R23
.def dia_decenas = R24
.def mes_unidades = R25
.def mes_decenas = R26
.dseg
digito: .byte 1
mode: .byte 1
alarma_mins_decenas: .byte 1
alarma_mins_unidades: .byte 1
alarma_hrs_decenas: .byte 1
alarma_hrs_unidades: .byte 1
alarma_flag: .byte 1
parpadeo_dp: .byte 1
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.cseg
.org 0x0000
RJMP START

.org PCI1addr
JMP ISR_BOTONES

.org OVF1addr
JMP ISR_TIMER1

.org OVF0addr
JMP IRS_TIMER0

 /**************/
// Configuración de la pila

START:
CLI

LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16

/**************/
// Configuracion MCU
SETUP:

; ======================================
; CONFIGURAR OSCILADOR A 1MHZ
; ======================================
LDI R16, (1<<CLKPCE)						; Habilito la posibilidad de cambiar el oscilador
STS CLKPR, R16								; aquí escribo el valor en el registro CLKPR

LDI R16, 0b0000_0100						; Configuro el prescaler a 16 (16MHz/16 = 1MHz)
STS CLKPR, R16								; Escribo ese valor en el registro CLKPR y con eso ya cambié el oscilador.
// 


; ======================================
; USAR PD0 Y PD1
; ======================================
LDI R16, 0x00
STS UCSR0B, R16

; ======================================
; CONFIGURAR PORTB
; ======================================
								 
LDI R16, 0b11111111									; Configuro pullUp y leds apagadas
OUT DDRB, R16
LDI R16, 0b00010000									; Configuro Entradas y salidas
OUT PORTB, R16

; ======================================
; CONFIGURAR PORTC
; ======================================

LDI R16, 0b00011111									; Configuro Entradas y salidas
OUT PORTC, R16								 
LDI R16, 0b00100000								; Configuro pullUp y leds apagadas
OUT DDRC, R16

; ======================================
; CONFIGURAR PORTD
; ======================================
								 
LDI R16, 0xFF								; Configuro pullUp y leds apagadas
OUT DDRD, R16
LDI R16, 0x00									; Configuro Entradas y salidas
OUT PORTD, R16


//interrupciones:

; ======================================
; CONFIGURAR TCNT0
; ======================================
LDI R16, (1<<TOIE0)							; habilito interrupción del overflow
STS TIMSK0, R16

; ======================================
; CONFIGURAR TCNT1
; ======================================
LDI R16, (1<<TOIE1)							; habilito interrupción del overflow para timer 1
STS TIMSK1, R16

; ======================================
; CONFIGURAR PIN CHANGE 
; ======================================
LDI R16,(1<<PCIE1)
STS PCICR,R16

LDI R16,(1<<PCINT9)|(1<<PCINT10)|(1<<PCINT11) |(1<<PCINT12) |(1<<PCINT8)
STS PCMSK1,R16

; ======================================
; CONFIGURAR TIMER0
; ======================================

LDI R16, 0x00
OUT TCCR0A, R16

LDI R16, (1<<CS01)				; prescaler 64
OUT TCCR0B, R16

LDI R16, (1<<TOV0)							; limpiar bandera overflow
OUT TIFR0, R16

; ======================================
; CONFIGURAR TIMER1
; ======================================

LDI R16, 0x00
STS TCCR1A, R16

LDI R16, (1<<CS11)|(1<<CS10)				; prescaler 64
STS TCCR1B, R16

LDI R16, (1<<TOV0)							; limpiar bandera overflow
OUT TIFR0, R16

LDI R16, HIGH(t1)							;asigno valor del TCNT del prescaler 
STS TCNT1H, R16
LDI R16, LOW(t1)
STS TCNT1L, R16

; ======================================
; CONFIGURAR TABLAS DE 7 SEGMENTOS
; ======================================
Table7seg:
	.db 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F

LDI R16, 0
STS mode, R16
STS digito, R16
STS alarma_mins_decenas, R16
STS alarma_mins_unidades, R16
STS alarma_hrs_decenas, R16
STS alarma_hrs_unidades, R16
STS alarma_flag, R16
LDI R16, 1
STS parpadeo_dp, R16
CLR R16
CLR R20									   ;
CLR R21									   ;
CLR R22									   ;
CLR R23									   ;
CLR R24									   ;
CLR R25									   ;
CLR R26									   ;
CLR R17									   ;
CLR R18									   ;									   ;
CLR R19									   ;
CLR R18									   ;
LDI mins_unidades, 9
LDI mins_decenas, 5
LDI hrs_unidades, 3
LDI hrs_decenas, 2
LDI mes_unidades, 2
LDI mes_decenas, 1
LDI dia_unidades, 1
LDI dia_decenas, 3

// INTERRUPCIONES GLOBALES
SEI
/**************/
// Loop Infinito
MAIN_LOOP:
    RJMP    MAIN_LOOP

/**************/
// NON-Interrupt subroutines

/**************/
// Interrupt routines
ISR_BOTONES:
	PUSH R16
	PUSH R17
	PUSH R27
	PUSH R28
	IN R16, SREG
	PUSH R16
	
	SBIC PINC, PINC0			;verifico si boton modo fue presionado
	RJMP BOTONES_INC_O_DEC
	LDS R16, alarma_flag
	CPI R16, 0x01				;si alarma esta prendida la apaga
	BRNE MODO
	CBI PORTC, PORTC5
	LDI R16, 0x00
	STS alarma_flag, R16		;APAGO ALARMA
	RJMP FIN_ISR_BOTONES

	MODO:
	LDS R16, mode
	INC R16						;AUMENTO MODO
	CPI R16, modes				;VERIFICO OVERFLOW MODOS
	BRNE NO_OVERFLOW_MODOS
	CLR R16						;REINICIO MODO
	STS mode, R16	
	RJMP FIN_ISR_BOTONES

	NO_OVERFLOW_MODOS:
	STS mode, R16				;GUARDO NUEVO VALOR DE MODO
	RJMP FIN_ISR_BOTONES
	

	BOTONES_INC_O_DEC:
	LDS R16, mode
	CPI R16, 0				;SI ESTA EN MODO MOSTRAR HORA BOTONES PC1-PC4 NO HACEN NADA
	BRNE NO_MODO_HORA
	SBI PORTB, 4
	CBI PORTB, 5
	RJMP FIN_ISR_BOTONES
	NO_MODO_HORA:
	CPI R16, 2				;SI ESTA EN MODO FECHA HORA BOTONES PC1-PC4 NO HACEN NADA
	BRNE NO_MODO_FECHA
	SBI PORTB, 5
	CBI PORTB, 4
	RJMP FIN_ISR_BOTONES
	NO_MODO_FECHA:
	CPI R16, 1
	BREQ CONFIG_HORA		;MODO CONFIGURAR HORA, REVISA BOTONES
	CPI R16, 3
	BRNE NO_CONFIG_FECHA
	RJMP CONFIG_FECHA
	NO_CONFIG_FECHA:		;MODO CONFIG FECHA, REVISA BOTONES
	RJMP CONFIG_ALARMA		;MODO CONFIG ALARMA, REVISA BOTONES
		
		//CONFIGURACION HORA
		CONFIG_HORA:
		SBIC PINC, PINC1
		RJMP REVISA_INC_HORAS
		; HORAS --
		RJMP DEC_HORAS

		REVISA_INC_HORAS:
		SBIC PINC, PINC2
		RJMP REVISA_DEC_MINS
		; HORAS ++
		RJMP INC_HORAS

		REVISA_DEC_MINS:
		SBIC PINC, PINC3
		RJMP REVISA_INC_MINS
		; MINUTOS --
		RJMP DEC_MINS

		REVISA_INC_MINS:
		SBIC PINC, PINC4
		RJMP FIN_ISR_BOTONES
		; MINUTOS ++
		RJMP INC_MINS
			
			//BOTON DEC IZQUIERDA PD1
			DEC_HORAS:
			CPI hrs_decenas, 0
			BRNE DEC_HORAS_NORMAL
			CPI hrs_unidades, 0
			BRNE DEC_HORAS_NORMAL

			LDI hrs_decenas, 2
			LDI hrs_unidades, 3
			RJMP FIN_ISR_BOTONES

			DEC_HORAS_NORMAL:
			TST hrs_unidades
			BRNE SOLO_DEC_UNIDADES_H
			LDI hrs_unidades, 9
			DEC hrs_decenas
			CPI hrs_decenas, 2
			BREQ SIGUE_1
			RJMP FIN_ISR_BOTONES
			SIGUE_1:
			CPI hrs_unidades, 9
			BREQ SIGUE_2
			RJMP FIN_ISR_BOTONES
			SIGUE_2:
			; evita 29, debe ser 23
			LDI hrs_unidades, 3
			RJMP FIN_ISR_BOTONES

			SOLO_DEC_UNIDADES_H:
			DEC hrs_unidades
			RJMP FIN_ISR_BOTONES

			//BOTON INC IZQUIERDA PD2
			INC_HORAS:
			CPI hrs_decenas, 2
			BRNE INC_HORAS_NORMAL
			CPI hrs_unidades, 3
			BRNE INC_HORAS_NORMAL

			CLR hrs_decenas
			CLR hrs_unidades
			RJMP FIN_ISR_BOTONES

			INC_HORAS_NORMAL:
			INC hrs_unidades
			CPI hrs_unidades, 10
			BRNE AJUSTE_24H

			CLR hrs_unidades
			INC hrs_decenas

			AJUSTE_24H:
			CPI hrs_decenas, 2
			BREQ SIGUE_3
			RJMP FIN_ISR_BOTONES
			SIGUE_3:
			CPI hrs_unidades, 4
			BREQ SIGUE_4
			RJMP FIN_ISR_BOTONES
			SIGUE_4:

			CLR hrs_decenas
			CLR hrs_unidades
			RJMP FIN_ISR_BOTONES

			//BOTON DEC DERECHA PD3
			DEC_MINS:
			CPI mins_decenas, 0
			BRNE DEC_MINS_NORMAL
			CPI mins_unidades, 0
			BRNE DEC_MINS_NORMAL

			LDI mins_decenas, 5
			LDI mins_unidades, 9
			RJMP FIN_ISR_BOTONES

			DEC_MINS_NORMAL:
			TST mins_unidades
			BRNE SOLO_DEC_UNIDADES_M

			LDI mins_unidades, 9
			DEC mins_decenas
			RJMP FIN_ISR_BOTONES

			SOLO_DEC_UNIDADES_M:
			DEC mins_unidades
			RJMP FIN_ISR_BOTONES

			//BOTON INC DERECHA PD4
			INC_MINS:
			CPI mins_decenas, 5
			BRNE INC_MINS_NORMAL
			CPI mins_unidades, 9
			BRNE INC_MINS_NORMAL

			CLR mins_decenas
			CLR mins_unidades
			RJMP FIN_ISR_BOTONES

			INC_MINS_NORMAL:
			INC mins_unidades
			CPI mins_unidades, 10
			BREQ SIGUE_5
			RJMP FIN_ISR_BOTONES
			SIGUE_5:

			CLR mins_unidades
			INC mins_decenas
			RJMP FIN_ISR_BOTONES
		
		//CONFIGURACION FECHA
		CONFIG_FECHA:
		SBIC PINC, PINC1
		RJMP REVISA_INC_DIA
		RJMP DEC_DIA

		REVISA_INC_DIA:
		SBIC PINC, PINC2
		RJMP REVISA_DEC_MES
		RJMP INC_DIA

		REVISA_DEC_MES:
		SBIC PINC, PINC3
		RJMP REVISA_INC_MES
		RJMP DEC_MES

		REVISA_INC_MES:
		SBIC PINC, PINC4
		RJMP FIN_ISR_BOTONES
		RJMP INC_MES

			//BOTON DEC IZQUIERDA PD1
			DEC_DIA:
			CPI dia_decenas, 0
			BRNE DEC_DIA_NORMAL
			CPI dia_unidades, 1
			BRNE DEC_DIA_NORMAL
			RCALL GET_MAX_DIA_MES
			MOV dia_decenas, R27
			MOV dia_unidades, R28
			RJMP FIN_ISR_BOTONES

			DEC_DIA_NORMAL:
			TST dia_unidades
			BRNE SOLO_DEC_DIA_UNIDADES
			LDI dia_unidades, 9
			DEC dia_decenas
			RJMP FIN_ISR_BOTONES

			SOLO_DEC_DIA_UNIDADES:
			DEC dia_unidades
			RJMP FIN_ISR_BOTONES

			//BOTON INC IZQUIERDA PD2
			INC_DIA:
			RCALL GET_MAX_DIA_MES
			; si dia == maximo, volver a 01
			CP dia_decenas, R27
			BRNE INC_DIA_NORMAL
			CP dia_unidades, R28
			BRNE INC_DIA_NORMAL
			CLR dia_decenas
			LDI dia_unidades, 1
			RJMP FIN_ISR_BOTONES

			INC_DIA_NORMAL:
			INC dia_unidades
			CPI dia_unidades, 10
			BREQ SIGUE_6
			RJMP FIN_ISR_BOTONES
			SIGUE_6:
			CLR dia_unidades
			INC dia_decenas
			RJMP FIN_ISR_BOTONES

			//BOTON DEC IZQUIERDA PD3
			DEC_MES:
			CPI mes_decenas, 0
			BRNE DEC_MES_NORMAL
			CPI mes_unidades, 1
			BRNE DEC_MES_NORMAL
			LDI mes_decenas, 1
			LDI mes_unidades, 2
			RJMP AJUSTAR_DIA_ACTUAL

			DEC_MES_NORMAL:
			TST mes_unidades
			BRNE SOLO_DEC_MES_UNIDADES
			LDI mes_unidades, 9
			DEC mes_decenas
			RJMP CORREGIR_MES_INVALIDO

			SOLO_DEC_MES_UNIDADES:
			DEC mes_unidades

			CORREGIR_MES_INVALIDO:
			CPI mes_decenas, 0
			BRNE AJUSTAR_DIA_ACTUAL
			CPI mes_unidades, 0
			BRNE AJUSTAR_DIA_ACTUAL
			LDI mes_unidades, 1

			AJUSTAR_DIA_ACTUAL:
			RJMP VERIFICAR_DIA_MES

			//BOTON INC IZQUIERDA PD4
			INC_MES:
			CPI mes_decenas, 1
			BRNE INC_MES_NORMAL
			CPI mes_unidades, 2
			BRNE INC_MES_NORMAL
			CLR mes_decenas
			LDI mes_unidades, 1
			RJMP AJUSTAR_DIA_SEGUN_MES

			INC_MES_NORMAL:
			INC mes_unidades
			CPI mes_unidades, 10
			BRNE VALIDAR_MES_10_12
			CLR mes_unidades
			INC mes_decenas

			VALIDAR_MES_10_12:
			CPI mes_decenas, 1
			BRNE AJUSTAR_DIA_SEGUN_MES
			CPI mes_unidades, 3
			BRNE AJUSTAR_DIA_SEGUN_MES
			CLR mes_decenas
			LDI mes_unidades, 1

			AJUSTAR_DIA_SEGUN_MES:
			RJMP AJUSTAR_DIA_ACTUAL

				//SUBRUTINAS PARA OVERFLOW DE DÍAS
				GET_MAX_DIA_MES:
				CPI mes_decenas, 0
				BRNE MES_10_12

				; meses 01..09
				CPI mes_unidades, 2
				BREQ MES_FEBRERO
				CPI mes_unidades, 4
				BREQ MES_30
				CPI mes_unidades, 6
				BREQ MES_30
				CPI mes_unidades, 9
				BREQ MES_30
				RJMP MES_31

				MES_10_12:
				CPI mes_unidades, 1
				BREQ MES_30      ; 11
				CPI mes_unidades, 2
				BREQ MES_31      ; 12
				RJMP MES_31      ; 10

				MES_FEBRERO:
				LDI R27, 2
				LDI R28, 8
				RET

				MES_30:
				LDI R27, 3
				LDI R28, 0
				RET

				MES_31:
				LDI R27, 3
				LDI R28, 1
				RET

				//VALIDACIONES DE MES
				VERIFICAR_DIA_MES:
				RCALL GET_MAX_DIA_MES
				CP dia_decenas, R27
				BRSH SEGUIR_9
				RJMP FIN_ISR_BOTONES
				SEGUIR_9:
				BREQ SEGUIR_10
				JMP DIA_INVALIDO
				SEGUIR_10:
				CP dia_unidades, R28
				BRSH SEGUIR_11
				RJMP FIN_ISR_BOTONES
				SEGUIR_11:
				BRNE SEGUIR_12
				JMP DIA_INVALIDO
				SEGUIR_12:

				DIA_INVALIDO:
				MOV dia_decenas, R27
				MOV dia_unidades, R28
				RJMP FIN_ISR_BOTONES

		//CONFIGURACION DE ALARMA
		CONFIG_ALARMA:
		SBIC PINC, PINC1
		RJMP REVISA_INC_HORA_AL
		RJMP DEC_HORA_ALARMA

		REVISA_INC_HORA_AL:
		SBIC PINC, PINC2
		RJMP REVISA_DEC_MIN_AL
		RJMP INC_HORA_ALARMA

		REVISA_DEC_MIN_AL:
		SBIC PINC, PINC3
		RJMP REVISA_INC_MIN_AL
		RJMP DEC_MIN_ALARMA

		REVISA_INC_MIN_AL:
		SBIC PINC, PINC4
		RJMP FIN_ISR_BOTONES
		RJMP INC_MIN_ALARMA

			//BOTON DEC IZQUIERDA PD1
			DEC_HORA_ALARMA:
			LDS R16, alarma_hrs_decenas
			CPI R16, 0
			BRNE DEC_HORA_AL_NORMAL_L
			LDS R16, alarma_hrs_unidades
			CPI R16, 0
			BRNE DEC_HORA_AL_NORMAL_L
			LDI R16, 2
			STS alarma_hrs_decenas, R16
			LDI R16, 3
			STS alarma_hrs_unidades, R16
			RJMP FIN_ISR_BOTONES

			DEC_HORA_AL_NORMAL_L:
			LDS R16, alarma_hrs_unidades
			TST R16
			BRNE SOLO_DEC_UNI_HORA_AL_L
			LDI R16, 9
			STS alarma_hrs_unidades, R16
			LDS R16, alarma_hrs_decenas
			DEC R16
			STS alarma_hrs_decenas, R16
			LDS R16, alarma_hrs_decenas
			CPI R16, 2
			BREQ REVISA_UNIDADES_29_AL
			RJMP FIN_ISR_BOTONES

			REVISA_UNIDADES_29_AL:
			LDS R16, alarma_hrs_unidades
			CPI R16, 9
			BREQ CORRIGE_29_A_23_AL
			RJMP FIN_ISR_BOTONES

			CORRIGE_29_A_23_AL:
			LDI R16, 3
			STS alarma_hrs_unidades, R16
			RJMP FIN_ISR_BOTONES

			SOLO_DEC_UNI_HORA_AL_L:
			DEC R16
			STS alarma_hrs_unidades, R16
			RJMP FIN_ISR_BOTONES

			//BOTON INC IZQUIERDA PD2
			INC_HORA_ALARMA:
			LDS R16, alarma_hrs_decenas
			CPI R16, 2
			BRNE INC_HORA_AL_NORMAL_L
			LDS R16, alarma_hrs_unidades
			CPI R16, 3
			BRNE INC_HORA_AL_NORMAL_L
			LDI R16, 0
			STS alarma_hrs_decenas, R16
			STS alarma_hrs_unidades, R16
			RJMP FIN_ISR_BOTONES

			INC_HORA_AL_NORMAL_L:
			LDS R16, alarma_hrs_unidades
			INC R16
			STS alarma_hrs_unidades, R16
			CPI R16, 10
			BREQ OVERFLOW_UNIDADES_HORA_AL
			RJMP AJUSTE_24H_AL_L

			OVERFLOW_UNIDADES_HORA_AL:
			LDI R16, 0
			STS alarma_hrs_unidades, R16
			LDS R16, alarma_hrs_decenas
			INC R16
			STS alarma_hrs_decenas, R16

			AJUSTE_24H_AL_L:
			LDS R16, alarma_hrs_decenas
			CPI R16, 2
			BREQ REVISA_24H_UNIDADES_AL
			RJMP FIN_ISR_BOTONES

			REVISA_24H_UNIDADES_AL:
			LDS R16, alarma_hrs_unidades
			CPI R16, 4
			BREQ CORRIGE_24_A_00_AL
			RJMP FIN_ISR_BOTONES

			CORRIGE_24_A_00_AL:
			LDI R16, 0
			STS alarma_hrs_decenas, R16
			STS alarma_hrs_unidades, R16
			RJMP FIN_ISR_BOTONES

			//BOTON DEC IZQUIERDA PD3
			DEC_MIN_ALARMA:
			LDS R16, alarma_mins_decenas
			CPI R16, 0
			BRNE DEC_MIN_AL_NORMAL_L
			LDS R16, alarma_mins_unidades
			CPI R16, 0
			BRNE DEC_MIN_AL_NORMAL_L
			LDI R16, 5
			STS alarma_mins_decenas, R16
			LDI R16, 9
			STS alarma_mins_unidades, R16
			RJMP FIN_ISR_BOTONES

			DEC_MIN_AL_NORMAL_L:
			LDS R16, alarma_mins_unidades
			TST R16
			BRNE SOLO_DEC_UNI_MIN_AL_L
			LDI R16, 9
			STS alarma_mins_unidades, R16
			LDS R16, alarma_mins_decenas
			DEC R16
			STS alarma_mins_decenas, R16
			RJMP FIN_ISR_BOTONES

			SOLO_DEC_UNI_MIN_AL_L:
			DEC R16
			STS alarma_mins_unidades, R16
			RJMP FIN_ISR_BOTONES

			//BOTON INC IZQUIERDA PD4
			INC_MIN_ALARMA:
			LDS R16, alarma_mins_decenas
			CPI R16, 5
			BRNE INC_MIN_AL_NORMAL_L
			LDS R16, alarma_mins_unidades
			CPI R16, 9
			BRNE INC_MIN_AL_NORMAL_L
			LDI R16, 0
			STS alarma_mins_decenas, R16
			STS alarma_mins_unidades, R16
			RJMP FIN_ISR_BOTONES

			INC_MIN_AL_NORMAL_L:
			LDS R16, alarma_mins_unidades
			INC R16
			STS alarma_mins_unidades, R16
			CPI R16, 10
			BREQ OVERFLOW_UNIDADES_MIN_AL
			RJMP FIN_ISR_BOTONES

			OVERFLOW_UNIDADES_MIN_AL:
			LDI R16, 0
			STS alarma_mins_unidades, R16
			LDS R16, alarma_mins_decenas
			INC R16
			STS alarma_mins_decenas, R16
			RJMP FIN_ISR_BOTONES

	FIN_ISR_BOTONES:
	POP R16
	OUT SREG, R16
	POP R28 
	POP R27
	POP R17
	POP R16
	RETI 

//Interrupcion timer 1 para la cuenta del tiempo cada segundo
ISR_TIMER1:
	PUSH R16
	PUSH R27
	PUSH R28
	IN R16, SREG
	PUSH R16

	LDS R16, alarma_flag
	CPI R16, 0x01
	BRNE NO_SONANDO_ALARMA
	SBI PINC, PINC5				;PARPADEO DE LED ALARMA SI ALARMA ESTÁ ENCENDIDA
	NO_SONANDO_ALARMA:
	LDS R16, mode
	CPI R16, 1
	BRNE NO_CONFIG_HORA_LED
	SBI PINB, PINB4				;PARPADERO LED HORA SI ESTA EN MODO CONFIG HORA
	NO_CONFIG_HORA_LED:
	CPI R16, 3
	BRNE NO_CONFIG_FECHA_LED
	SBI PINB, PINB5				;PARPADERO LED FECHA SI ESTA EN MODO CONFIG FECHA
	NO_CONFIG_FECHA_LED:
	CPI R16, 4
	BRNE NO_CONFIG_ALARMA_LED
	SBI PINB, PINB4				;PARPADEAN AMBAS LED HORA/FECHA SI ESTA EN MODO CONFIG ALARMA
	SBI PINB, PINB5
	NO_CONFIG_ALARMA_LED:
	LDS R27, parpadeo_dp
	LDI R28, 0x01
	EOR R27, R28
	STS parpadeo_dp, R27
	INC segs					;CUENTA DE SEGUNDOS
	CPI segs, 60
	BREQ CONTINUAR_1
	RJMP fin_isr_timer1
	CONTINUAR_1:
	CLR segs
	INC mins_unidades

	//VERIFICACION DE HORA DE ALARMA
	LDS R16, alarma_mins_decenas
	CP R16, mins_decenas
	BRNE NO_ALARMA
	LDS R16, alarma_mins_unidades
	CP R16, mins_unidades
	BRNE NO_ALARMA
	LDS R16, alarma_hrs_decenas
	CP R16, hrs_decenas
	BRNE NO_ALARMA
	LDS R16, alarma_hrs_unidades
	CP R16, hrs_unidades
	BRNE NO_ALARMA

	ALARMA:
	LDI R16, 0x01
	STS alarma_flag, R16

	NO_ALARMA:
	CPI mins_unidades, 10		;OVERFLOW UNIDADES MINS
	BREQ CONTINUAR_2
	RJMP fin_isr_timer1
	CONTINUAR_2:
	CLR mins_unidades
	INC mins_decenas
	CPI mins_decenas, 6			;OVERFLOW DECENAS MINS
	BREQ CONTINUAR_3
	RJMP fin_isr_timer1
	CONTINUAR_3:
	CLR mins_decenas
	INC hrs_unidades			;INCREMENTO DE UNIDADES DE HORAS
	CPI hrs_decenas, 2			;OVERFLOW DECENAS DE 24 HRS
	BREQ CONTINUAR_4
	RJMP no_overflow_24_hrs
	CONTINUAR_4:
	CPI hrs_unidades, 4			;OVERFLOW 24 HRS
	BREQ CONTINUAR_5
	RJMP fin_isr_timer1
	CONTINUAR_5:
	CLR hrs_unidades
	CLR hrs_decenas
	INC dia_unidades			;INCREMENTO DE DÍA

	CPI mes_decenas, 0			;LEO QUE MES ES
	BRNE NOV_O_DIC
	CPI mes_unidades, 1
	BREQ CHECK_OVERFLOW_31
	CPI mes_unidades, 2
	BREQ CHECK_OVERFLOW_FEB
	CPI mes_unidades, 3
	BREQ CHECK_OVERFLOW_31
	CPI mes_unidades, 4
	BREQ CHECK_OVERFLOW_30
	CPI mes_unidades, 5
	BREQ CHECK_OVERFLOW_31
	CPI mes_unidades, 6
	BREQ CHECK_OVERFLOW_30
	CPI mes_unidades, 7
	BREQ CHECK_OVERFLOW_31
	CPI mes_unidades, 8
	BREQ CHECK_OVERFLOW_31
	CPI mes_unidades, 9
	BREQ CHECK_OVERFLOW_30
	CLR mes_unidades
	INC mes_decenas

	NOV_O_DIC:
	CPI mes_unidades, 0
	BREQ CHECK_OVERFLOW_31
	CPI mes_unidades, 1
	BREQ CHECK_OVERFLOW_30
	CPI mes_unidades, 2
	BREQ CHECK_OVERFLOW_DIC			

	CHECK_OVERFLOW_FEB:
	CPI dia_decenas, 2
	BRNE CHECK_OVERFLOW_UNIDADES
	CPI dia_unidades, 9
	BRNE fin_isr_timer1
	CLR dia_decenas
	CLR dia_unidades
	INC mes_unidades
	RJMP fin_isr_timer1

	CHECK_OVERFLOW_30:
	CPI dia_decenas, 3
	BRNE CHECK_OVERFLOW_UNIDADES
	CPI dia_unidades, 1
	BRNE fin_isr_timer1
	CLR dia_decenas
	CLR dia_unidades
	INC mes_unidades
	RJMP fin_isr_timer1

	CHECK_OVERFLOW_31:
	CPI dia_decenas, 3
	BRNE CHECK_OVERFLOW_UNIDADES
	CPI dia_unidades, 2
	BRNE fin_isr_timer1
	CLR dia_decenas
	CLR dia_unidades
	INC mes_unidades
	RJMP fin_isr_timer1

	CHECK_OVERFLOW_DIC:
	CPI dia_decenas, 3
	BRNE CHECK_OVERFLOW_UNIDADES
	CPI dia_unidades, 2
	BRNE fin_isr_timer1
	CLR dia_decenas
	LDI dia_unidades, 1
	CLR mes_decenas
	LDI mes_unidades, 1
	RJMP fin_isr_timer1

		CHECK_OVERFLOW_UNIDADES:
		CPI dia_unidades, 10
		BRNE fin_isr_timer1
		CLR dia_unidades
		INC dia_decenas


	RJMP fin_isr_timer1

	no_overflow_24_hrs:
	CPI hrs_unidades, 10		;OVERFLOW UNIDADES HORAS
	BRNE fin_isr_timer1
	CLR hrs_unidades
	INC hrs_decenas

	fin_isr_timer1:
	LDI R16, HIGH(t1)							;reinicio valor del tcnt para que no comience desde 0
	STS TCNT1H, R16
	LDI R16, LOW(t1)
	STS TCNT1L, R16

	POP R16
	OUT SREG, R16
	POP R28
	POP R27
	POP R16
	RETI

//interrupcion timer 0 para multiplexado de displays
IRS_TIMER0:
	PUSH R16
	PUSH R17
	PUSH ZH
    PUSH ZL
    IN R16, SREG
    PUSH R16

    CBI PORTB,0
    CBI PORTB,1
    CBI PORTB,2
    CBI PORTB,3

	LDI R16, 0x00
	OUT PORTD, R16

	//leo el modo en el que está para saber si debo mostrar hora o fecha
	LDS R16, mode
	CPI R16, 0
	BREQ MOSTRAR_HORA
	CPI R16, 1
	BREQ MOSTRAR_HORA
	CPI R16, 2
	BREQ MOSTRAR_FECHA
	CPI R16, 3
	BREQ MOSTRAR_FECHA
	CPI R16, 4
	BREQ MOSTRAR_ALARMA
		
		//MOSTRAR HORA EN MODO 0 Y 1
		MOSTRAR_HORA:
		LDS R16, digito
		CPI R16, 0
		BREQ DIGITO_1_H
		CPI R16, 1
		BREQ DIGITO_2_H
		CPI R16, 2
		BREQ DIGITO_3_H
		RJMP DIGITO_4_H

				//DIGITO DECENAS DE HORAS
				DIGITO_1_H:
				MOV R17, hrs_decenas
				SBI PORTB, 0
				RJMP LOAD_SEGMENTO

				//DIGITO UNIDADES DE HORAS
				DIGITO_2_H:
				MOV R17, hrs_unidades
				SBI PORTB, 1
				RJMP LOAD_SEGMENTO

				//DIGITO DECENAS DE MINUTOS
				DIGITO_3_H:
				MOV R17, mins_decenas
				SBI PORTB, 2
				RJMP LOAD_SEGMENTO

				//DIGITO UNIDADES DE MINUTOS
				DIGITO_4_H:
				MOV R17, mins_unidades
				SBI PORTB, 3
				RJMP LOAD_SEGMENTO

		MOSTRAR_FECHA:
		LDS R16, digito
		CPI R16, 0
		BREQ DIGITO_1_F
		CPI R16, 1
		BREQ DIGITO_2_F
		CPI R16, 2
		BREQ DIGITO_3_F
		RJMP DIGITO_4_F

				//DIGITO DECENAS DE DIA
				DIGITO_1_F:
				MOV R17, dia_decenas
				SBI PORTB, 0
				RJMP LOAD_SEGMENTO

				//DIGITO UNIDADES DE DIA
				DIGITO_2_F:
				MOV R17, dia_unidades
				SBI PORTB, 1
				RJMP LOAD_SEGMENTO

				//DIGITO DECENAS DE MES
				DIGITO_3_F:
				MOV R17, mes_decenas
				SBI PORTB, 2
				RJMP LOAD_SEGMENTO

				//DIGITO UNIDADES DE MES
				DIGITO_4_F:
				MOV R17, mes_unidades
				SBI PORTB, 3
				RJMP LOAD_SEGMENTO

			//MOSTRAR ALARMA EN MODO CONFIGURACION DE ALARMA
			MOSTRAR_ALARMA:
			LDS R16, digito
			CPI R16, 0
			BREQ DIGITO_1_A
			CPI R16, 1
			BREQ DIGITO_2_A
			CPI R16, 2
			BREQ DIGITO_3_A
			RJMP DIGITO_4_A

				DIGITO_1_A:
				LDS R17, alarma_hrs_decenas
				SBI PORTB, 0
				RJMP LOAD_SEGMENTO

				DIGITO_2_A:
				LDS R17, alarma_hrs_unidades
				SBI PORTB, 1
				RJMP LOAD_SEGMENTO

				DIGITO_3_A:
				LDS R17, alarma_mins_decenas
				SBI PORTB, 2
				RJMP LOAD_SEGMENTO

				DIGITO_4_A:
				LDS R17, alarma_mins_unidades
				SBI PORTB, 3
				RJMP LOAD_SEGMENTO

					//MUESTRA EL DIGITO CORRESPONDIENTE PARA EL MODO CORRESPONDIENTE
					LOAD_SEGMENTO:
					LDI ZH, HIGH(Table7seg<<1)
					LDI ZL, LOW(Table7seg<<1)
					ADD ZL, R17
					ADC ZH, R1

					LPM R17, Z
					; --- CONTROL DE ":" (PD7) ---
					LDS R16, digito

					CPI R16, 1        ; dígito 2
					BREQ ENCENDER_DP
					CPI R16, 2        ; dígito 3
					BREQ ENCENDER_DP
					RJMP APAGAR_DP

					/*ENCENDER_DP:
					ORI R17, 0x80
					RJMP CONT_DP*/
					
					ENCENDER_DP:
					LDS R27, parpadeo_dp		;DOS PUNTOS PARPADEANDO
					CPI R27, 1
					BRNE APAGAR_DP
					ORI R17, 0x80
					RJMP CONT_DP

					APAGAR_DP:
					ANDI R17, 0x7F    ; apagar ":"

					CONT_DP:
					OUT PORTD, R17
					INC R16
					ANDI R16, 0x03
					STS digito, R16
	
	FIN_ISR_TIMER0:
	POP R16
	OUT SREG, R16
	POP ZL
    POP ZH
	POP R17
	POP R16

	RETI	

/**************/