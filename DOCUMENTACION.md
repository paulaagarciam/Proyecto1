# Reloj digital con fecha y alarma

## 1. Objetivo
Este proyecto implementa un reloj digital en ensamblador para el `ATmega328P` usando `Microchip Studio`.

Funciones incluidas:
- Hora en formato de 24 horas.
- Fecha en formato `dd/mm`.
- Alarma configurable.
- Multiplexado de 4 displays de 7 segmentos.
- Parpadeo de los dos puntos cada 500 ms.
- Configuracion con overflow y underflow.
- Botones por `pin-change interrupt`.
- Anti-rebote por software con accion de `presionar-y-soltar`.

## 2. Suposiciones de hardware
Se asumio la siguiente conexion:

### Displays
- `PD0..PD7`: segmentos `a b c d e f g dp`
- `PB0`: display 1
- `PB1`: display 2
- `PB2`: display 3
- `PB3`: display 4

El codigo esta escrito para displays de 7 segmentos `comun catodo`, con segmentos activos en alto.

### Indicadores
- `PB4`: LED de alarma habilitada
- `PB5`: LED o buzzer de alarma activa

### Botones
- `PC0`: `MODE`
- `PC1`: `SELECT`
- `PC2`: `INC`
- `PC3`: `DEC`
- `PC4`: `ALARM`

Los botones usan `pull-up` interno, por lo que:
- reposo = `1`
- presionado = `0`

## 3. Modos de operacion
El sistema usa 5 modos:

1. `MODE_CLOCK`: muestra hora `hh:mm`
2. `MODE_SET_TIME`: configura hora y minutos
3. `MODE_DATE`: muestra fecha `dd/mm`
4. `MODE_SET_DATE`: configura dia y mes
5. `MODE_SET_ALARM`: configura hora y minutos de la alarma

### Funcion de botones
- `MODE`: cambia al siguiente modo
- `SELECT`: cambia el campo activo dentro del modo de configuracion
- `INC`: incrementa el campo activo
- `DEC`: decrementa el campo activo
- `ALARM`: habilita/deshabilita la alarma, o la apaga si esta sonando

## 4. Indicacion visual de configuracion
Cuando el reloj esta en un modo de configuracion:
- el campo seleccionado parpadea cada 500 ms
- en modos de hora o alarma, tambien parpadean los dos puntos centrales

Esto cumple con el requisito de indicar claramente que el sistema esta en modo de ajuste.

## 5. Configuracion del reloj del microcontrolador
Se usa el oscilador interno de `16 MHz` con prescaler a `16`, por lo que la frecuencia final es:

```text
f_CPU = 16 MHz / 16 = 1 MHz
```

Esto se configura mediante el registro `CLKPR`.

## 6. Calculo del Timer0
Se usa `Timer0` en modo normal con interrupcion por overflow.

### Datos
- `f_CPU = 1 MHz`
- prescaler = `8`
- frecuencia del timer:

```text
f_timer = 1,000,000 / 8 = 125,000 Hz
T_tick = 1 / 125,000 = 8 us
```

Para obtener `1 ms`:

```text
1 ms / 8 us = 125 cuentas
```

Como `Timer0` desborda en `256`, se recarga:

```text
TCNT0 = 256 - 125 = 131
```

Por eso el codigo usa:
- `prescaler = 8`
- `TCNT0 = 131`

Con esto, cada overflow ocurre aproximadamente cada `1 ms`.

## 7. Uso del Timer0
La ISR de `Timer0` realiza cuatro tareas:

1. Recarga `TCNT0`
2. Multiplexa los 4 displays
3. Cuenta milisegundos para generar:
   - parpadeo cada `500 ms`
   - tick de `1 segundo`
4. Ejecuta el anti-rebote de botones

## 8. Uso de interrupciones pin-change
Los botones estan conectados en `PORTC`, por lo que se habilita:

- `PCIE1` en `PCICR`
- `PCINT8..PCINT12` en `PCMSK1`

La ISR de `PCINT1` no ejecuta acciones de usuario directamente. Solo reinicia una ventana de anti-rebote de `20 ms`.

## 9. Anti-rebote
Se usa anti-rebote por software:

1. Una transicion en un boton dispara `PCINT1`
2. La ISR carga `debounce_counter = 20`
3. `Timer0` decrementa ese contador cada `1 ms`
4. Cuando el contador llega a cero, se vuelve a leer `PINC`
5. Solo si el estado es estable se registra el evento

El evento que se toma como valido es la transicion `presionado -> liberado`, es decir, accion de `presionar-y-soltar`.

## 10. Overflow y underflow
La logica cumple con los cambios circulares requeridos:

### Minutos
- `00 -> 59` al decrementar
- `59 -> 00` al incrementar

### Horas
- `00 -> 23` al decrementar
- `23 -> 00` al incrementar

### Dias
Dependen del mes actual:
- febrero: `28`
- abril, junio, septiembre, noviembre: `30`
- resto: `31`

Ejemplos:
- `01/03` al decrementar dia pasa a `31/03` solo si el mes configurado tiene 31 dias
- `01/02` al decrementar dia pasa a `28/02`

### Meses
- `01 -> 12` al decrementar
- `12 -> 01` al incrementar

Si el dia actual queda fuera del nuevo mes, se ajusta al maximo valido.

### Alarma
La alarma usa la misma logica circular para horas y minutos.

## 11. Logica de la alarma
La alarma se compara una vez por segundo.

Condiciones para activarse:
- alarma habilitada
- segundos = `00`
- hora actual = hora de alarma
- minuto actual = minuto de alarma

Cuando coincide:
- se activa `alarm_ringing`
- `PB5` parpadea con el mismo ritmo de 500 ms

El boton `ALARM`:
- apaga la alarma si esta sonando
- o alterna entre habilitada y deshabilitada si no esta sonando

## 12. Estructura del programa
Las rutinas principales son:

- `ISR_TIMER0_OVF`: base de tiempo, multiplexado y debounce
- `ISR_PCINT1`: inicio del proceso de anti-rebote
- `HandleButtonEvents`: procesa eventos ya validados
- `AdvanceClockOneSecond`: incrementa el reloj
- `CheckAlarmMatch`: verifica coincidencia con la alarma
- `UpdateDisplayBuffer`: convierte valores binarios a patrones de 7 segmentos

## 13. Archivo principal
El codigo fuente principal esta en:

- `proyecto1/main.asm`

## 14. Ensamblado
El archivo fue verificado con `avrasm2` del toolchain de Atmel Studio y ensambla con:

- `0 errors`
- `0 warnings`

## 15. Mejoras opcionales
Si quieres llevarlo a una version mas completa, las siguientes extensiones encajan bien:

- agregar ano y manejo de bisiesto
- agregar sonido real con un buzzer usando otro timer
- guardar hora/fecha/alarma en EEPROM
- agregar simulacion en Proteus
