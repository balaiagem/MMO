"""Gera o catalogo de magias (rules/spells_catalog.lua) a partir do SRD 2014 + textos PT.
A ORDEM da lista e permanente (o indice vira bit no storage): so acrescente no fim."""
import json, sys

SRD = json.load(open(sys.argv[1], encoding='utf-8'))
by_index = {s['index']: s for s in SRD}
CLS = {'cleric': 3, 'wizard': 4, 'bard': 6, 'druid': 7, 'paladin': 9, 'ranger': 10, 'sorcerer': 11, 'warlock': 12}

# key, srd-index (ou None), PT, descricao curta (PT, sem acento -> escapes feitos no Lua), implementada?
SPELLS = [
    # --- truques ---
    ('acidsplash', 'acid-splash', 'Respingo \\193cido', 'Salvaguarda de DES ou 1d6 de dano \\225cido (escala no n\\237vel 5).', True),
    ('chilltouch', 'chill-touch', 'Toque Arrepiante', 'Ataque m\\225gico \\224 dist\\226ncia: 1d8 necr\\243tico; o alvo n\\227o recupera PV at\\233 seu pr\\243ximo turno.', True),
    ('eldritchblast', 'eldritch-blast', 'Rajada Sobrenatural', 'Raio de for\\231a: ataque m\\225gico, 1d10 (mais raios no n\\237vel 5).', True),
    ('firebolt', 'fire-bolt', 'Raio de Fogo', 'Ataque m\\225gico \\224 dist\\226ncia: 1d10 de fogo.', True),
    ('light', 'light', 'Luz', 'Voc\\234 brilha como uma tocha por 1 hora.', False),
    ('poisonspray', 'poison-spray', 'Rajada de Veneno', 'Alvo a at\\233 2 sqm: salvaguarda de CON ou 1d12 de veneno.', True),
    ('produceflame', 'produce-flame', 'Produzir Chama', 'Ataque m\\225gico: 1d8 de fogo.', True),
    ('rayoffrost', 'ray-of-frost', 'Raio de Gelo', 'Ataque m\\225gico: 1d8 de frio e o alvo perde 2 sqm de deslocamento no pr\\243ximo turno.', True),
    ('resistance', 'resistance', 'Resist\\234ncia', 'Aliado soma 1d4 a uma salvaguarda (concentra\\231\\227o).', False),
    ('sacredflame', 'sacred-flame', 'Chama Sagrada', 'Salvaguarda de DES ou 1d8 radiante.', True),
    ('shillelagh', 'shillelagh', 'Bord\\227o M\\237stico', 'Seu bord\\227o/clava usa SAB e causa 1d8 por 1 minuto (a\\231\\227o b\\244nus).', False),
    ('shockinggrasp', 'shocking-grasp', 'Toque Chocante', 'Ataque m\\225gico corpo a corpo: 1d8 el\\233trico; vantagem contra armadura de metal; o alvo perde a rea\\231\\227o.', True),
    ('sparethedying', 'spare-the-dying', 'Poupar os Moribundos', 'Estabiliza uma criatura com 0 PV.', False),
    ('viciousmockery', 'vicious-mockery', 'Esc\\225rnio Cruel', 'Salvaguarda de SAB ou 1d4 ps\\237quico e desvantagem no pr\\243ximo ataque.', True),
    ('guidance', 'guidance', 'Orienta\\231\\227o', 'Aliado soma 1d4 a um teste de per\\237cia (concentra\\231\\227o).', False),
    ('truestrike', 'true-strike', 'Golpe Certeiro', 'Vantagem no seu pr\\243ximo ataque contra o alvo (concentra\\231\\227o).', False),
    # --- 1o circulo ---
    ('bane', 'bane', 'Perdi\\231\\227o', 'At\\233 3 inimigos: salvaguarda de CAR ou -1d4 em ataques e salvaguardas.', False),
    ('bless', 'bless', 'B\\234n\\231\\227o', 'Voc\\234 e aliados somam 1d4 a ataques e salvaguardas (concentra\\231\\227o).', True),
    ('burninghands', 'burning-hands', 'M\\227os Flamejantes', 'Cone de 3 sqm: salvaguarda de DES, 3d6 de fogo (metade se passar).', True),
    ('charmperson', 'charm-person', 'Enfeiti\\231ar Pessoa', 'Humanoide: salvaguarda de SAB ou fica enfeiti\\231ado e n\\227o te ataca.', False),
    ('colorspray', 'color-spray', 'Leque Crom\\225tico', 'Cega criaturas em ordem de PV (6d10 PV afetados).', False),
    ('command', 'command', 'Comando', 'Salvaguarda de SAB ou obedece uma palavra (Caia, Fuja, Pare).', False),
    ('curewounds', 'cure-wounds', 'Curar Ferimentos', 'Toque: cura 1d8 + modificador.', True),
    ('divinefavor', 'divine-favor', 'Favor Divino', 'Seus ataques com arma causam +1d4 radiante (concentra\\231\\227o).', False),
    ('entangle', 'entangle', 'Constri\\231\\227o', '\\193rea de 4 sqm: salvaguarda de FOR ou fica impedido.', False),
    ('expeditiousretreat', 'expeditious-retreat', 'Recuo Acelerado', 'Disparada como a\\231\\227o b\\244nus em todos os turnos (concentra\\231\\227o).', False),
    ('faeriefire', 'faerie-fire', 'Fogo das Fadas', '\\193rea: salvaguarda de DES ou contorno brilhante; ataques contra t\\234m vantagem.', False),
    ('falselife', 'false-life', 'Vida Falsa', 'Voc\\234 ganha 1d4+4 PV tempor\\225rios (+5 por c\\237rculo acima do 1o).', True),
    ('featherfall', 'feather-fall', 'Queda Suave', 'Rea\\231\\227o: voc\\234 n\\227o sofre dano de queda.', False),
    ('fogcloud', 'fog-cloud', 'N\\233voa Obscurecente', 'Nuvem de 4 sqm que bloqueia a vis\\227o (concentra\\231\\227o).', False),
    ('goodberry', 'goodberry', 'Bom Fruto', 'Cria 10 frutas: cada uma cura 1 PV e alimenta por um dia.', False),
    ('grease', 'grease', '\\193rea Escorregadia', '\\193rea de 2 sqm: salvaguarda de DES ou cai.', False),
    ('guidingbolt', 'guiding-bolt', 'Raio Guiador', 'Ataque m\\225gico: 4d6 radiante; o pr\\243ximo ataque contra o alvo tem vantagem.', True),
    ('healingword', 'healing-word', 'Palavra Curativa', 'A\\231\\227o b\\244nus a dist\\226ncia: cura 1d4 + modificador.', True),
    ('heroism', 'heroism', 'Hero\\237smo', 'Aliado imune a medo e ganha PV tempor\\225rios a cada turno (concentra\\231\\227o).', False),
    ('hideouslaughter', 'hideous-laughter', 'Riso Hist\\233rico', 'Salvaguarda de SAB ou cai rindo, incapacitado (concentra\\231\\227o).', False),
    ('huntersmark', 'hunters-mark', 'Marca do Ca\\231ador', 'A\\231\\227o b\\244nus: +1d6 nos seus ataques contra o alvo marcado (concentra\\231\\227o).', True),
    ('inflictwounds', 'inflict-wounds', 'Infligir Ferimentos', 'Ataque m\\225gico corpo a corpo: 3d10 necr\\243tico.', True),
    ('jump', 'jump', 'Salto', 'Triplica a dist\\226ncia de salto por 1 minuto.', False),
    ('longstrider', 'longstrider', 'Passos Longos', '+2 sqm de deslocamento por 1 hora.', False),
    ('magearmor', 'mage-armor', 'Armadura Arcana', 'Sem armadura: CA base 13 + DES por 8 horas.', True),
    ('magicmissile', 'magic-missile', 'M\\237sseis M\\225gicos', '3 dardos que sempre acertam: 1d4+1 de for\\231a cada (+1 dardo por c\\237rculo acima).', True),
    ('protectionfromevilandgood', 'protection-from-evil-and-good', 'Prote\\231\\227o contra o Bem e o Mal', 'Aberra\\231\\245es, celestiais, corruptores, fadas e mortos-vivos t\\234m desvantagem contra o alvo.', False),
    ('sanctuary', 'sanctuary', 'Santu\\225rio', 'Quem atacar o protegido precisa passar em SAB ou escolhe outro alvo.', False),
    ('shield', 'shield', 'Escudo Arcano', 'Rea\\231\\227o ao ser atingido: +5 CA at\\233 seu pr\\243ximo turno e bloqueia M\\237sseis M\\225gicos.', True),
    ('shieldoffaith', 'shield-of-faith', 'Escudo da F\\233', 'A\\231\\227o b\\244nus: +2 CA em um aliado (concentra\\231\\227o).', True),
    ('sleep', 'sleep', 'Sono', 'Adormece criaturas em ordem de PV (5d8 PV, +2d8 por c\\237rculo).', True),
    ('thunderwave', 'thunderwave', 'Onda Trovejante', 'Em volta de voc\\234: salvaguarda de CON, 2d8 trov\\227o e empurra 2 sqm (metade sem empurr\\227o se passar).', True),
    ('hex', None, 'Rogar Maldi\\231\\227o', 'A\\231\\227o b\\244nus: +1d6 necr\\243tico nos seus ataques contra o alvo (concentra\\231\\227o).', True),
    ('hellishrebuke', 'hellish-rebuke', 'Repreens\\227o Infernal', 'Rea\\231\\227o ao sofrer dano: salvaguarda de DES, 2d10 de fogo.', False),
    # --- 2o circulo ---
    ('acidarrow', 'acid-arrow', 'Flecha \\193cida', 'Ataque m\\225gico: 4d4 \\225cido agora e 2d4 no fim do pr\\243ximo turno.', False),
    ('aid', 'aid', 'Aux\\237lio', 'At\\233 3 aliados ganham +5 PV m\\225ximos e atuais por 8 horas.', False),
    ('barkskin', 'barkskin', 'Pele de \\193rvore', 'CA do alvo nunca fica abaixo de 16 (concentra\\231\\227o).', False),
    ('blindnessdeafness', 'blindness-deafness', 'Cegueira/Surdez', 'Salvaguarda de CON ou fica cego por 1 minuto.', False),
    ('blur', 'blur', 'Nublar', 'Ataques contra voc\\234 t\\234m desvantagem (concentra\\231\\227o).', False),
    ('brandingsmite', 'branding-smite', 'Destrui\\231\\227o Marcante', 'Pr\\243ximo acerto com arma: +2d6 radiante e o alvo brilha.', False),
    ('darkness', 'darkness', 'Escurid\\227o', 'Esfera de escurid\\227o m\\225gica de 3 sqm (concentra\\231\\227o).', True),
    ('darkvision', 'darkvision', 'Vis\\227o no Escuro', 'O alvo enxerga no escuro por 8 horas.', False),
    ('enhanceability', 'enhance-ability', 'Aprimorar Atributo', 'Vantagem em testes de um atributo escolhido (concentra\\231\\227o).', False),
    ('enlargereduce', 'enlarge-reduce', 'Aumentar/Reduzir', 'Aumenta (+1d4 de dano) ou reduz (-1d4) uma criatura (concentra\\231\\227o).', False),
    ('flameblade', 'flame-blade', 'L\\226mina Flamejante', 'Cria uma l\\226mina de fogo: 3d6 por ataque (concentra\\231\\227o).', False),
    ('flamingsphere', 'flaming-sphere', 'Esfera Flamejante', 'Esfera que voc\\234 move: salvaguarda de DES, 2d6 de fogo (concentra\\231\\227o).', False),
    ('holdperson', 'hold-person', 'Imobilizar Pessoa', 'Humanoide: salvaguarda de SAB ou fica paralisado (concentra\\231\\227o).', False),
    ('invisibility', 'invisibility', 'Invisibilidade', 'O alvo fica invis\\237vel at\\233 atacar ou conjurar (concentra\\231\\227o).', False),
    ('lesserrestoration', 'lesser-restoration', 'Restaura\\231\\227o Menor', 'Remove cegueira, surdez, paralisia ou veneno.', False),
    ('magicweapon', 'magic-weapon', 'Arma M\\225gica', 'A\\231\\227o b\\244nus: a arma vira +1 (concentra\\231\\227o).', False),
    ('mirrorimage', 'mirror-image', 'Imagem Espelhada', 'Tr\\234s c\\243pias ilus\\243rias desviam ataques por 1 minuto.', False),
    ('mistystep', 'misty-step', 'Passo Nebuloso', 'A\\231\\227o b\\244nus: teleporta at\\233 6 sqm para um ponto que voc\\234 v\\234.', False),
    ('moonbeam', 'moonbeam', 'Raio Lunar', 'Coluna de luz: salvaguarda de CON, 2d10 radiante por turno (concentra\\231\\227o).', False),
    ('rayofenfeeblement', 'ray-of-enfeeblement', 'Raio do Enfraquecimento', 'Ataque m\\225gico: o alvo causa metade do dano com for\\231a (concentra\\231\\227o).', False),
    ('scorchingray', 'scorching-ray', 'Raio Ardente', 'Tr\\234s raios de 2d6 de fogo, um ataque cada (+1 raio por c\\237rculo acima).', True),
    ('shatter', 'shatter', 'Despeda\\231ar', '\\193rea de 2 sqm: salvaguarda de CON, 3d8 trov\\227o.', False),
    ('silence', 'silence', 'Sil\\234ncio', 'Esfera de 4 sqm sem som: ningu\\233m conjura com voz l\\225 dentro (concentra\\231\\227o).', False),
    ('spikegrowth', 'spike-growth', 'Crescer Espinhos', '\\193rea de 4 sqm: 2d4 perfurante a cada 1 sqm andado (concentra\\231\\227o).', False),
    ('spiritualweapon', 'spiritual-weapon', 'Arma Espiritual', 'A\\231\\227o b\\244nus: arma flutuante ataca 1d8 + modificador.', True),
    ('web', 'web', 'Teia', 'Cubo de teia: salvaguarda de DES ou fica impedido (concentra\\231\\227o).', False),
    ('heatmetal', 'heat-metal', 'Esquentar Metal', 'Metal em brasa: 2d8 de fogo por turno ao portador (concentra\\231\\227o).', False),
    ('prayerofhealing', 'prayer-of-healing', 'Prece de Cura', 'At\\233 6 aliados curam 2d8 + modificador (fora de combate).', False),
    # --- 3o circulo ---
    ('beaconofhope', 'beacon-of-hope', 'Farol de Esperan\\231a', 'Aliados t\\234m vantagem em salvaguardas de SAB/morte e curas m\\225ximas (concentra\\231\\227o).', False),
    ('bestowcurse', 'bestow-curse', 'Rogar Praga', 'Salvaguarda de SAB ou maldi\\231\\227o: desvantagem ou +1d8 necr\\243tico seu (concentra\\231\\227o).', False),
    ('calllightning', 'call-lightning', 'Invocar Rel\\226mpago', 'Raio de 1 sqm: salvaguarda de DES, 3d10 el\\233trico, repete a cada turno (concentra\\231\\227o).', False),
    ('counterspell', 'counterspell', 'Contram\\225gica', 'Rea\\231\\227o: anula uma magia conjurada a at\\233 12 sqm.', True),
    ('dispelmagic', 'dispel-magic', 'Dissipar Magia', 'Encerra magias ativas em um alvo.', False),
    ('fear', 'fear', 'Medo', 'Cone: salvaguarda de SAB ou foge amedrontado (concentra\\231\\227o).', False),
    ('fireball', 'fireball', 'Bola de Fogo', 'Explos\\227o de 4 sqm: salvaguarda de DES, 8d6 de fogo.', True),
    ('fly', 'fly', 'Voo', 'O alvo ganha deslocamento de voo de 12 sqm (concentra\\231\\227o).', False),
    ('haste', 'haste', 'Velocidade', '+2 CA, deslocamento dobrado e uma a\\231\\227o extra (concentra\\231\\227o).', False),
    ('hypnoticpattern', 'hypnotic-pattern', 'Padr\\227o Hipn\\243tico', '\\193rea: salvaguarda de SAB ou fica incapacitado (concentra\\231\\227o).', False),
    ('lightningbolt', 'lightning-bolt', 'Rel\\226mpago', 'Linha de 20 sqm: salvaguarda de DES, 8d6 el\\233trico.', False),
    ('masshealingword', 'mass-healing-word', 'Palavra Curativa em Massa', 'A\\231\\227o b\\244nus: at\\233 6 aliados curam 1d4 + modificador.', True),
    ('protectionfromenergy', 'protection-from-energy', 'Prote\\231\\227o contra Energia', 'Resist\\234ncia a um tipo de dano (concentra\\231\\227o).', False),
    ('revivify', 'revivify', 'Revivificar', 'Traz de volta quem morreu h\\225 menos de 1 minuto (diamante de 300 po).', False),
    ('slow', 'slow', 'Lentid\\227o', 'At\\233 6 alvos: salvaguarda de SAB ou -2 CA, metade do deslocamento, sem rea\\231\\245es (concentra\\231\\227o).', False),
    ('spiritguardians', 'spirit-guardians', 'Guardi\\245es Espirituais', 'Esp\\237ritos em volta de voc\\234: inimigos sofrem 3d8 radiante (concentra\\231\\227o).', False),
    ('stinkingcloud', 'stinking-cloud', 'N\\233voa F\\233tida', 'Nuvem: salvaguarda de CON ou perde a a\\231\\227o (concentra\\231\\227o).', False),
    ('vampirictouch', 'vampiric-touch', 'Toque Vamp\\237rico', 'Ataque m\\225gico corpo a corpo: 3d6 necr\\243tico e cura metade (concentra\\231\\227o).', False),
    ('daylight', 'daylight', 'Luz do Dia', 'Esfera de luz do dia de 12 sqm; dissipa escurid\\227o m\\225gica.', False),
    ('sleetstorm', 'sleet-storm', 'Nevasca', '\\193rea de 8 sqm: terreno dif\\237cil e salvaguarda de DES ou cai (concentra\\231\\227o).', False),
]

EXTRA_CLASSES = {
    'hex': [12],
    # Patrono Corruptor (lista expandida do bruxo)
    'burninghands': [12], 'command': [12], 'blindnessdeafness': [12], 'scorchingray': [12], 'fireball': [12], 'stinkingcloud': [12],
}
EN_NAMES = {'hex': 'Hex'}
LEVELS = {'hex': 1}
CASTS = {'hex': 'bonus'}
RANGE_SQM = {'hex': 18}


def range_sqm(srd):
    r = (srd or {}).get('range', '')
    if r.startswith('Self'): return 0
    if r == 'Touch': return 1
    try:
        feet = int(r.split()[0])
        return max(1, min(30, feet // 5))
    except Exception:
        return 1


def casting(srd):
    t = (srd or {}).get('casting_time', '1 action')
    if 'bonus' in t: return 'bonus'
    if 'reaction' in t: return 'reaction'
    if 'action' in t: return 'action'
    return 'ritual'


lines = ['-- GERADO por tools/gen_spells_catalog.py (SRD 2014 + textos PT). A ordem e permanente:',
         '-- o indice de cada magia vira um bit salvo no personagem. So acrescente no fim.',
         'DndSpellCatalog = {']
for key, idx, pt, desc, impl in SPELLS:
    srd = by_index.get(idx) if idx else None
    if idx and not srd: raise SystemExit('SRD sem ' + idx)
    classes = sorted(set([CLS[c['index']] for c in (srd or {}).get('classes', []) if c['index'] in CLS] + EXTRA_CLASSES.get(key, [])))
    level = srd['level'] if srd else LEVELS[key]
    en = srd['name'] if srd else EN_NAMES[key]
    conc = 'true' if (srd or {}).get('concentration') or key == 'hex' else 'false'
    lines.append("  {key='%s',en='%s',pt='%s',level=%d,classes={%s},cast='%s',range=%d,conc=%s,impl=%s,desc='%s'}," % (
        key, en.replace("'", "\\'"), pt, level, ','.join(str(c) for c in classes), CASTS.get(key, casting(srd)),
        RANGE_SQM.get(key, range_sqm(srd)), conc, 'true' if impl else 'false', desc))
lines.append('}')
lines.append('DndSpellIndex = {}')
lines.append('for i, s in ipairs(DndSpellCatalog) do s.index = i; DndSpellIndex[s.key] = s end')
lines.append('return DndSpellCatalog')
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print(len(SPELLS), 'magias;', sum(1 for s in SPELLS if s[4]), 'implementadas')
