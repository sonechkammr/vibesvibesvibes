class_name GardenDayCycle
extends RefCounted

static func sample(hour: float) -> Dictionary:
	var h: float = fposmod(hour,24.0)
	var keys: Array[Vector3] = [Vector3(0,0.13,0),Vector3(4.5,0.13,0),Vector3(6,0.66,0.75),Vector3(8,1,0),Vector3(16,1,0),Vector3(18.25,0.48,0.85),Vector3(20,0.13,0),Vector3(24,0.13,0)]
	var light: float = 1
	var warmth: float = 0
	for i in range(keys.size()-1):
		if h>=keys[i].x and h<=keys[i+1].x:
			var weight: float = (h-keys[i].x)/(keys[i+1].x-keys[i].x)
			light = lerpf(keys[i].y,keys[i+1].y,weight)
			warmth = lerpf(keys[i].z,keys[i+1].z,weight)
			break
	var period := "Ночь"
	if h>=4.5 and h<6.5:
		period = "Рассвет"
	elif h>=6.5 and h<10:
		period = "Утро"
	elif h>=10 and h<17:
		period = "День"
	elif h>=17 and h<19.5:
		period = "Закат"
	elif h>=19.5 and h<21:
		period = "Вечер"
	return {"light":light,"warmth":warmth,"period":period,"night":light<0.35,"hour":h}
