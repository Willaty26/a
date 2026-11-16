# NOTAS

## Estado (2026-11-16)

### Hallazgo importante
CLAUDE.md decía que el primer sistema ya estaba escrito, pero `src/` solo tenía la
plantilla de Rojo y en Studio no existía `EggConfig`. Escribí el sistema desde cero.

### Paso 1: sistema base — PROBADO en Studio, sin errores
- `src/shared/EggConfig.luau`: precios, tiempos y criaturas.
- `src/server/init.server.luau`: monedas, compra validada, incubación, ingreso pasivo, DataStore.
- `src/client/init.client.luau`: interfaz por código, un botón por tipo en `EggConfig.Orden`.
- Playtest: GUI aparece, compra descuenta monedas, entradas inválidas ("Inexistente", número)
  se rechazan, el huevo nace tras 10 s, el ingreso pasivo sube las monedas.

### Error encontrado y corregido
- `DataStoreService:GetDataStore` daba error ("You must publish this place to the web") y
  mataba el script del servidor. Ahora va en pcall: sin DataStore el juego funciona pero NO guarda.
  Para probar el guardado hay que publicar el juego y activar "Enable Studio Access to API Services"
  (el dueño decide cuándo; yo no publico).

### Ruido normal en la consola (no es nuestro código)
- `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type` (Studio).
- Aviso "DataStore no disponible" mientras el lugar no esté publicado (esperado).

### Notas técnicas
- `rojo` no está en el PATH; está en `%USERPROFILE%\.aftman\bin\rojo.exe` (`rojo serve` para sincronizar).
- `huevos-roblox.rbxl` no se sube a git (Rojo reconstruye todo desde `src/`).

### Paso 2: huevos Raro y Monstruoso — PROBADO
- Raro ($500, 30 s): Galipote (+12/s), Lugarú (+30/s). Monstruoso ($5000, 60 s): Bacá (+120/s), Diablo Cojuelo (+350/s).
- Solo se editó `EggConfig.luau` (datos + `Orden`); la interfaz y el servidor no cambiaron.
- Playtest: 3 botones; sin monedas el servidor rechaza Raro/Monstruoso; con 504 monedas el Raro
  se compra, nace Galipote y el ingreso sube a +24/s. Monstruoso: con 5020 monedas se compra, nace Bacá, ingreso +144/s.

### Pase visual (EN CURSO, 2026-11-16)
- Paso 1 (granja, nidos, huevos que se agitan y brillan): código escrito en `src/server/Granja.luau`
  y conectado en `init.server.luau`; `EggConfig` ahora tiene Color/ColorRareza/Escala. FALTA probarlo
  en Studio (Rojo hay que volver a conectarlo con Plugins > Rojo > Connect tras cada reinicio de `rojo serve`).
- `rojo serve` ya se cayó dos veces: una por poca memoria (cierre automático de Claude Code) y otra
  por un fallo propio de Rojo al escribir dos archivos a la vez (change_processor.rs). Se reinicia con
  `%USERPROFILE%\.aftman\bin\rojo.exe serve` y se escriben los archivos de uno en uno.
- Pendiente: paso 2 (criaturas), paso 3 (interfaz), paso 4 (iluminación y sonido).

### Siguiente (ideas, no pedidas)
- Probar el guardado real: publicar el juego y activar acceso a API en Studio (lo decide el dueño).
- Balance: ajustar precios/ingresos en EggConfig según lo que se sienta al jugar.
