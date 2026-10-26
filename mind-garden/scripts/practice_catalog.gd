extends RefCounted

# Editorial adaptations, not quotations or complete translations of the suttas.
const ITEMS: Array[Dictionary] = [
	{
		"id": "breathing",
		"title": "Внимание к дыханию",
		"minutes": 3,
		"instruction": "Сядьте так, чтобы вам было удобно. Замечайте вдох и выдох. Отмечайте, длинное сейчас дыхание или короткое. Если внимание отвлеклось, спокойно вернитесь к следующему вдоху. Можно закончить раньше.",
		"source": "MN 118 · Ānāpānasati Sutta\nАнглийский перевод: Ṭhānissaro Bhikkhu",
		"url": "https://www.dhammatalks.org/suttas/MN/MN118.html"
	},
	{
		"id": "goodwill",
		"title": "Доброжелательность",
		"minutes": 3,
		"instruction": "Устройтесь удобно. Мысленно пожелайте живым существам благополучия и свободы от вражды. Можно начать с тех, о ком вам легко думать тепло, и постепенно расширить это пожелание. Не нужно добиваться особого чувства. Можно закончить раньше.",
		"source": "Sn 1.8 · Karaṇīya Mettā Sutta\nТакже Khuddakapāṭha 9\nАнглийский перевод: Ṭhānissaro Bhikkhu",
		"url": "https://www.dhammatalks.org/suttas/KN/StNp/StNp1_8.html"
	}
]

static func find(practice_id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == practice_id:
			return item.duplicate(true)
	return {}
