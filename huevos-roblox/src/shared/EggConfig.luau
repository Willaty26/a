-- EggConfig: aquí viven TODOS los precios, tiempos y criaturas del juego.
-- Para cambiar el balance del juego, edita solo este archivo (no la lógica).

local EggConfig = {}

-- Monedas con las que empieza un jugador nuevo
EggConfig.MonedasIniciales = 100

-- Máximo de huevos incubando a la vez por jugador (= cantidad de nidos en la granja)
EggConfig.MaxHuevosIncubando = 5

-- Segundos antes de eclosionar en que el huevo empieza a agitarse y brillar
EggConfig.SegundosAlerta = 4

-- Máximo de criaturas que se dibujan caminando en la granja de cada jugador
EggConfig.MaxCriaturasVisibles = 30

-- Cada cuántos segundos se guarda la partida automáticamente
EggConfig.SegundosAutoguardado = 60

-- Nombre del DataStore (si lo cambias, se pierden los datos guardados antes)
EggConfig.NombreDataStore = "HuevosJugadores_v1"

-- Orden en que se muestran los botones de huevos en la interfaz
-- (de menor a mayor rareza; la posición también define la "forma" de las criaturas)
EggConfig.Orden = { "Comun", "Raro", "Monstruoso" }

-- Definición de cada tipo de huevo:
--   Nombre:       texto que ve el jugador
--   Precio:       monedas que cuesta
--   Incubacion:   segundos hasta que nace la criatura
--   Color:        color del huevo en el nido
--   ColorRareza:  color del nombre de sus criaturas y del botón
--   Criaturas:    lista de posibles criaturas
--       Nombre:   texto que ve el jugador
--       Peso:     probabilidad relativa (más alto = sale más seguido)
--       Ingreso:  monedas por segundo que da (ingreso pasivo)
--       Color:    color del cuerpo del modelo
--       Escala:   tamaño del modelo (1 = tamaño normal)
EggConfig.Huevos = {
	Comun = {
		Nombre = "Huevo Común",
		Precio = 50,
		Incubacion = 10,
		Color = Color3.fromRGB(245, 235, 200),
		ColorRareza = Color3.fromRGB(255, 255, 255),
		Criaturas = {
			{ Nombre = "Cuco", Peso = 70, Ingreso = 1, Color = Color3.fromRGB(255, 170, 0), Escala = 0.8 },
			{ Nombre = "Ciguapa", Peso = 30, Ingreso = 3, Color = Color3.fromRGB(0, 200, 150), Escala = 1.1 },
		},
	},

	-- Huevo raro: cuesta más, tarda más, criaturas más fuertes
	Raro = {
		Nombre = "Huevo Raro",
		Precio = 500,
		Incubacion = 30,
		Color = Color3.fromRGB(80, 160, 255),
		ColorRareza = Color3.fromRGB(90, 190, 255),
		Criaturas = {
			{ Nombre = "Galipote", Peso = 70, Ingreso = 12, Color = Color3.fromRGB(170, 60, 255), Escala = 1.5 },
			{ Nombre = "Lugarú", Peso = 30, Ingreso = 30, Color = Color3.fromRGB(0, 120, 255), Escala = 1.8 },
		},
	},

	-- Huevo monstruoso: el más caro, las criaturas más raras y poderosas
	Monstruoso = {
		Nombre = "Huevo Monstruoso",
		Precio = 5000,
		Incubacion = 60,
		Color = Color3.fromRGB(200, 30, 60),
		ColorRareza = Color3.fromRGB(255, 70, 90),
		Criaturas = {
			{ Nombre = "Bacá", Peso = 80, Ingreso = 120, Color = Color3.fromRGB(230, 20, 40), Escala = 2.4 },
			{ Nombre = "Diablo Cojuelo", Peso = 20, Ingreso = 350, Color = Color3.fromRGB(255, 0, 120), Escala = 3.0 },
		},
	},
}

return EggConfig
